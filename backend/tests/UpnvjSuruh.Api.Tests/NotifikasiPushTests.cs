using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Notifikasi push, dari pendaftaran perangkatnya sampai kabar yang benar-benar berangkat.
///
/// Yang diuji di sini bukan Firebase-nya (penyedianya diganti pencatat, lihat
/// <see cref="PengirimNotifikasiPencatat"/>), melainkan seluruh keputusan sebelum Firebase:
/// perangkat mana yang tercatat milik siapa, siapa yang dikirimi kabar apa saat status order
/// berpindah, dan perangkat mana yang berhenti dikirimi. Itu bagian yang bisa salah tanpa
/// terlihat -- notifikasi yang salah alamat baru ketahuan lewat keluhan orang, dan notifikasi
/// yang tidak pernah dikirim tidak ketahuan sama sekali.
/// </summary>
public class NotifikasiPushTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private static string NomorBaru() => "08" + Random.Shared.NextInt64(100000000, 999999999);

    private async Task<(HttpClient Klien, Guid Id)> AkunAsync(params UserRole[] roles)
    {
        var user = new User
        {
            Name = "Uji " + Guid.NewGuid().ToString("N")[..6],
            Phone = NomorBaru(),
            Roles = [.. roles],
        };

        using (var lingkup = pabrik.Services.CreateScope())
        {
            var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Users.Add(user);
            await db.SaveChangesAsync();
        }

        var (token, _) = new TokenService(Options.Create(new JwtOptions
        {
            Issuer = ApiFactory.Issuer,
            Audience = ApiFactory.Audience,
            SigningKey = ApiFactory.SigningKey,
            MasaBerlakuMenit = 60,
        })).Terbitkan(user);

        var klien = pabrik.CreateClient();
        klien.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return (klien, user.Id);
    }

    private static async Task<string> DaftarkanAsync(HttpClient klien)
    {
        var token = "fcm-" + Guid.NewGuid().ToString("N");
        (await klien.PostAsJsonAsync("/api/perangkat", new { Token = token })).EnsureSuccessStatusCode();
        return token;
    }

    private async Task<OrderResponse> OrderDibayarAsync(HttpClient klien)
    {
        var order = (await (await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
        })).Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;

        var gateway = pabrik.CreateClient();
        gateway.DefaultRequestHeaders.Add(WebhookOptions.Header, ApiFactory.WebhookSecret);
        (await gateway.PostAsJsonAsync("/api/webhooks/pembayaran", new
        {
            OrderId = order.Id,
            ReferensiGateway = "trx-" + Guid.NewGuid().ToString("N"),
            Status = nameof(PaymentStatus.Berhasil),
            Jumlah = order.Harga!.Value,
        })).EnsureSuccessStatusCode();

        return order;
    }

    /// <summary>Seluruh token yang dikirimi kabar berjudul <paramref name="judul"/>.</summary>
    private IReadOnlyList<string> TokenPenerima(string judul) =>
    [
        .. pabrik.Notifikasi.Terkirim
            .Where(k => k.Pesan.Judul == judul)
            .SelectMany(k => k.Token),
    ];

    // --- Pendaftaran perangkat ---

    [Fact]
    public async Task PerangkatTercatatUntukAkunYangMendaftarkannya()
    {
        var (klien, idKlien) = await AkunAsync(UserRole.Klien);

        var token = await DaftarkanAsync(klien);

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var perangkat = await db.PerangkatNotifikasi.SingleAsync(p => p.Token == token);
        Assert.Equal(idKlien, perangkat.UserId);
    }

    /// <summary>
    /// Satu HP yang dipakai bergantian dua orang. Tokennya milik pemasangan aplikasinya, jadi
    /// pendaftaran kedua memindahkannya alih-alih menambah baris; kalau tidak, kabar milik
    /// akun yang sudah keluar tetap muncul di layar orang yang sekarang memakainya.
    /// </summary>
    [Fact]
    public async Task TokenYangDidaftarkanUlangBerpindahKeAkunTerakhir()
    {
        var (pertama, _) = await AkunAsync(UserRole.Klien);
        var (kedua, idKedua) = await AkunAsync(UserRole.Runner);

        var token = await DaftarkanAsync(pertama);
        (await kedua.PostAsJsonAsync("/api/perangkat", new { Token = token })).EnsureSuccessStatusCode();

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var perangkat = await db.PerangkatNotifikasi.SingleAsync(p => p.Token == token);
        Assert.Equal(idKedua, perangkat.UserId);
    }

    [Fact]
    public async Task PendaftaranTanpaTokenSesiDitolak()
    {
        var tamu = pabrik.CreateClient();

        var jawaban = await tamu.PostAsJsonAsync("/api/perangkat", new { Token = "fcm-tamu" });

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    // --- Kabar yang berangkat ---

    [Fact]
    public async Task PembayaranMengabariKlienDanMenyiarkanKeSeluruhRunner()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);

        var tokenKlien = await DaftarkanAsync(klien);
        var tokenRunner = await DaftarkanAsync(runner);

        pabrik.Notifikasi.Bersihkan();
        await OrderDibayarAsync(klien);

        Assert.Equal(tokenKlien, Assert.Single(TokenPenerima("Pembayaran diterima")));
        Assert.Contains(tokenRunner, TokenPenerima("Order baru: Anter Jemput"));
    }

    /// <summary>
    /// Pemesannya sendiri tidak ikut disiari, sekalipun ia kebetulan juga runner. Menawarkan
    /// order sendiri untuk diambil sendiri adalah kabar yang cuma membuat orang berhenti
    /// mempercayai kabar berikutnya.
    /// </summary>
    [Fact]
    public async Task PemesanYangJugaRunnerTidakIkutDisiariOrdernyaSendiri()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien, UserRole.Runner);
        var tokenKlien = await DaftarkanAsync(klien);

        pabrik.Notifikasi.Bersihkan();
        await OrderDibayarAsync(klien);

        Assert.DoesNotContain(tokenKlien, TokenPenerima("Order baru: Anter Jemput"));
    }

    [Fact]
    public async Task RunnerYangMenerimaMengabariKlienDanBukanDirinyaSendiri()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);

        var tokenKlien = await DaftarkanAsync(klien);
        var tokenRunner = await DaftarkanAsync(runner);

        var order = await OrderDibayarAsync(klien);

        pabrik.Notifikasi.Bersihkan();
        (await runner.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();

        Assert.Equal(tokenKlien, Assert.Single(TokenPenerima("Runner sudah menerima")));
        Assert.DoesNotContain(tokenRunner, pabrik.Notifikasi.Terkirim.SelectMany(k => k.Token));
    }

    [Fact]
    public async Task RunnerYangMelepasTidakDisiariOrderYangBaruSajaIaLepas()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (pelepas, _) = await AkunAsync(UserRole.Runner);
        var (lainnya, _) = await AkunAsync(UserRole.Runner);

        await DaftarkanAsync(klien);
        var tokenPelepas = await DaftarkanAsync(pelepas);
        var tokenLainnya = await DaftarkanAsync(lainnya);

        var order = await OrderDibayarAsync(klien);
        (await pelepas.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();

        pabrik.Notifikasi.Bersihkan();
        (await pelepas.PostAsJsonAsync(
            $"/api/orders/{order.Id}/lepas", new { Alasan = "Motor mogok di jalan." }))
            .EnsureSuccessStatusCode();

        var siaran = TokenPenerima("Order baru: Anter Jemput");
        Assert.Contains(tokenLainnya, siaran);
        Assert.DoesNotContain(tokenPelepas, siaran);
    }

    [Fact]
    public async Task RunnerYangDitangguhkanTidakIkutDisiari()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, idRunner) = await AkunAsync(UserRole.Runner);

        await DaftarkanAsync(klien);
        var tokenRunner = await DaftarkanAsync(runner);

        using (var lingkup = pabrik.Services.CreateScope())
        {
            var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
            var akun = await db.Users.SingleAsync(u => u.Id == idRunner);
            akun.SuspendedAt = DateTime.UtcNow;
            akun.SuspendedReason = "Uji";
            await db.SaveChangesAsync();
        }

        pabrik.Notifikasi.Bersihkan();
        await OrderDibayarAsync(klien);

        Assert.DoesNotContain(tokenRunner, TokenPenerima("Order baru: Anter Jemput"));
    }

    [Fact]
    public async Task PerangkatYangSudahDilepasBerhentiDikirimi()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var token = await DaftarkanAsync(klien);

        (await klien.PostAsJsonAsync("/api/perangkat/lepas", new { Token = token }))
            .EnsureSuccessStatusCode();

        pabrik.Notifikasi.Bersihkan();
        await OrderDibayarAsync(klien);

        Assert.DoesNotContain(token, pabrik.Notifikasi.Terkirim.SelectMany(k => k.Token));
    }

    /// <summary>
    /// Token yang dijawab penyedia "sudah tidak terdaftar" dibuang barisnya. Tanpa ini,
    /// perangkat yang aplikasinya sudah dicopot menumpuk selamanya, dan setiap siaran
    /// berikutnya membayar ongkos kirim ke perangkat yang tidak ada.
    /// </summary>
    [Fact]
    public async Task TokenYangDitolakPenyediaDibuangDariBasisData()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var token = await DaftarkanAsync(klien);

        pabrik.Notifikasi.Bersihkan();
        pabrik.Notifikasi.TokenMati.Add(token);

        await OrderDibayarAsync(klien);

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.False(await db.PerangkatNotifikasi.AnyAsync(p => p.Token == token));
    }
}
