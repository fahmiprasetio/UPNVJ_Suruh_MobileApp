using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Tarif Jalur A lewat dashboard admin.
///
/// Yang paling penting diuji di sini bukan cuma bahwa PUT-nya berhasil, melainkan bahwa
/// perubahannya sungguh dipakai KalkulatorTarif saat order berikutnya dibuat — kalau
/// endpoint ini cuma menulis baris yang tidak pernah dibaca lagi, admin akan mengira
/// tarifnya berubah padahal tidak.
/// </summary>
public class TarifEndpointTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private static string NomorBaru() => "08" + Random.Shared.NextInt64(100000000, 999999999);

    private async Task<HttpClient> AkunAsync(params UserRole[] roles)
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
        return klien;
    }

    private static PerbaruiTarifRequest TarifValid() => new()
    {
        AnjemTarifDasar = 5000m,
        AnjemTarifPerKm = 2000m,
        AnjemJarakMinimalKm = 0.5,
        AnjemJarakMaksimalKm = 15,
        JastipMakananFee = 8000m,
        JastipBarangFee = 10000m,
        JastipBarangTarifPerKm = 2000m,
    };

    /// <summary>
    /// Baris tarifnya cuma satu untuk seluruh basis data tes ini (satu per kelas, dipakai
    /// bersama semua metode tes di kelas ini), dan xUnit tidak menjamin urutan jalannya
    /// metode tes dalam satu kelas. Tanpa mengembalikannya ke keadaan yang diketahui di
    /// awal setiap tes yang membaca angkanya, tes mana pun bisa lolos atau gagal tergantung
    /// tes lain mana yang kebetulan jalan lebih dulu.
    /// </summary>
    private async Task<HttpClient> ResetTarifAsync()
    {
        var admin = await AkunAsync(UserRole.Admin);
        (await admin.PutAsJsonAsync("/api/tarif", TarifValid())).EnsureSuccessStatusCode();
        return admin;
    }

    // --- Membaca ---

    [Fact]
    public async Task TanpaTokenDitolak()
    {
        var jawaban = await pabrik.CreateClient().GetAsync("/api/tarif");

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    [Theory]
    [InlineData(UserRole.Klien)]
    [InlineData(UserRole.Runner)]
    public async Task PeranApaPunYangSudahMasukBolehMembaca(UserRole peran)
    {
        var akun = await AkunAsync(peran);

        var jawaban = await akun.GetAsync("/api/tarif");

        Assert.Equal(HttpStatusCode.OK, jawaban.StatusCode);
    }

    [Fact]
    public async Task NilaiAwalnyaSesuaiTarifConfig()
    {
        await ResetTarifAsync();
        var akun = await AkunAsync(UserRole.Klien);

        var tarif = await akun.GetFromJsonAsync<TarifResponse>("/api/tarif");

        Assert.Equal(5000m, tarif!.AnjemTarifDasar);
        Assert.Equal(2000m, tarif.AnjemTarifPerKm);
        Assert.Equal(8000m, tarif.JastipMakananFee);
    }

    // --- Mengubah ---

    [Theory]
    [InlineData(UserRole.Klien)]
    [InlineData(UserRole.Runner)]
    public async Task YangBukanAdminTidakBolehMengubah(UserRole peran)
    {
        var bukanAdmin = await AkunAsync(peran);

        var jawaban = await bukanAdmin.PutAsJsonAsync("/api/tarif", TarifValid());

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }

    [Fact]
    public async Task AdminBisaMengubahDanMembacanyaKembali()
    {
        var admin = await ResetTarifAsync();

        var diubah = TarifValid() with { AnjemTarifDasar = 7000m };
        (await admin.PutAsJsonAsync("/api/tarif", diubah)).EnsureSuccessStatusCode();

        var sesudah = await admin.GetFromJsonAsync<TarifResponse>("/api/tarif");
        Assert.Equal(7000m, sesudah!.AnjemTarifDasar);
        Assert.NotNull(sesudah.DiubahPada);
    }

    [Fact]
    public async Task JarakMinimalTidakBolehMelebihiJarakMaksimal()
    {
        var admin = await AkunAsync(UserRole.Admin);

        var salah = TarifValid() with { AnjemJarakMinimalKm = 20, AnjemJarakMaksimalKm = 15 };
        var jawaban = await admin.PutAsJsonAsync("/api/tarif", salah);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1000)]
    public async Task TarifDasarNolAtauNegatifDitolak(decimal nilai)
    {
        var admin = await AkunAsync(UserRole.Admin);

        var salah = TarifValid() with { AnjemTarifDasar = nilai };
        var jawaban = await admin.PutAsJsonAsync("/api/tarif", salah);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    // --- Sampai ke order sungguhan ---

    [Fact]
    public async Task OrderBaruMemakaiTarifYangSudahDiubah()
    {
        var admin = await ResetTarifAsync();
        (await admin.PutAsJsonAsync("/api/tarif", TarifValid() with { AnjemTarifDasar = 12345m }))
            .EnsureSuccessStatusCode();

        var klien = await AkunAsync(UserRole.Klien);
        var dibuat = await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 0.0, // dijepit ke jarak minimal tarif, jadi ongkos jaraknya konstan
        });
        dibuat.EnsureSuccessStatusCode();

        var order = (await dibuat.Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;

        Assert.Equal(12345m + 1000m, order.Harga);

        // Baris tarifnya cuma satu; kembalikan ke nilai bawaan supaya tes lain di kelas ini
        // (dan TarifSelarasDenganMobileTests, yang membaca TarifConfig, bukan basis data
        // tes ini, jadi sebenarnya tidak tersentuh) tidak mewarisi angka 12345 ini.
        (await admin.PutAsJsonAsync("/api/tarif", TarifValid())).EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task OrderLamaTidakIkutBerubahSetelahTarifDiubah()
    {
        var admin = await ResetTarifAsync();
        var klien = await AkunAsync(UserRole.Klien);

        var dibuat = await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
        });
        dibuat.EnsureSuccessStatusCode();
        var order = (await dibuat.Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;
        var hargaSebelum = order.Harga;

        (await admin.PutAsJsonAsync("/api/tarif", TarifValid() with { AnjemTarifDasar = 999_000m }))
            .EnsureSuccessStatusCode();

        var sesudah = await klien.GetFromJsonAsync<OrderResponse>($"/api/orders/{order.Id}");

        Assert.Equal(hargaSebelum, sesudah!.Harga);

        (await admin.PutAsJsonAsync("/api/tarif", TarifValid())).EnsureSuccessStatusCode();
    }
}
