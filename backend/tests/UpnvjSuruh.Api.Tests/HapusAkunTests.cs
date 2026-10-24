using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Controllers;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Pengguna menghapus akunnya sendiri: apa yang hilang, apa yang tinggal, dan kapan ditolak.
///
/// Yang diuji di sini bukan sekadar "barisnya berubah", melainkan tiga janji yang ditulis
/// juga di halaman kebijakan privasi: data pribadi benar-benar hilang, akses benar-benar
/// putus (termasuk token yang masih berlaku), dan catatan uang tidak ikut hilang. Janji yang
/// tidak diuji adalah janji yang baru ketahuan salahnya saat ada yang menagih.
/// </summary>
public class HapusAkunTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private static string NomorBaru() => "08" + Random.Shared.NextInt64(100000000, 999999999);

    private async Task<(HttpClient Klien, User Akun)> AkunAsync(
        UserRole[]? peran = null, bool denganData = true)
    {
        var user = new User
        {
            Name = "Uji " + Guid.NewGuid().ToString("N")[..6],
            Phone = NomorBaru(),
            Address = denganData ? "Jl. Contoh No. 1, Pondok Labu" : null,
            PasswordHash = denganData ? "sidik-uji" : null,
            Roles = [.. peran ?? [UserRole.Klien]],
        };

        using (var lingkup = pabrik.Services.CreateScope())
        {
            var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Users.Add(user);
            await db.SaveChangesAsync();
        }

        var (token, _) = new TokenService(Microsoft.Extensions.Options.Options.Create(new JwtOptions
        {
            Issuer = ApiFactory.Issuer,
            Audience = ApiFactory.Audience,
            SigningKey = ApiFactory.SigningKey,
            MasaBerlakuMenit = 60,
        })).Terbitkan(user);

        var klien = pabrik.CreateClient();
        klien.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return (klien, user);
    }

    private async Task<T> DenganDbAsync<T>(Func<AppDbContext, Task<T>> kerja)
    {
        using var lingkup = pabrik.Services.CreateScope();
        return await kerja(lingkup.ServiceProvider.GetRequiredService<AppDbContext>());
    }

    private async Task<User> BacaUserAsync(Guid id) =>
        await DenganDbAsync(db => db.Users.AsNoTracking().SingleAsync(u => u.Id == id));

    /// <summary>Meminta kode lewat endpoint publik yang sama dengan alur masuk, lalu menghapus.</summary>
    private async Task<HttpResponseMessage> HapusAsync(string noHp, string? kode = null)
    {
        var tamu = pabrik.CreateClient();
        if (kode is null)
        {
            (await tamu.PostAsJsonAsync("/api/auth/minta-kode", new { NoHp = noHp })).EnsureSuccessStatusCode();
            kode = pabrik.Otp.KodeUntuk(noHp)!;
        }

        return await tamu.PostAsJsonAsync("/api/akun/hapus", new { NoHp = noHp, Kode = kode });
    }

    private Task<Order> BuatOrderAsync(Guid klienId, OrderStatus status) =>
        DenganDbAsync(async db =>
        {
            var order = new Order
            {
                ClientId = klienId,
                ServiceType = ServiceType.AnterJemput,
                Status = status,
                Price = 11000m,
                Description = "Titip beli es teh",
                PickupAddress = "Kos Melati, Jl. Pondok Labu 12",
                DestinationAddress = "Gedung FIK UPNVJ",
                PhotoUrl = "/media/bukti/foto-order.jpg",
                HandoverNote = "Dititip ke satpam",
                CreatedAt = DateTime.UtcNow.AddHours(-3),
            };
            db.Orders.Add(order);
            await db.SaveChangesAsync();
            return order;
        });

    // --- Jalur yang mulus ---

    [Fact]
    public async Task PemilikMenghapusAkunDanDataPribadinyaHilang()
    {
        var (_, akun) = await AkunAsync();
        await DenganDbAsync(async db =>
        {
            db.PerangkatNotifikasi.Add(new PerangkatNotifikasi { UserId = akun.Id, Token = "token-fcm-uji" });
            await db.SaveChangesAsync();
            return 0;
        });

        var jawaban = await HapusAsync(akun.Phone);

        Assert.Equal(HttpStatusCode.NoContent, jawaban.StatusCode);

        var sesudah = await BacaUserAsync(akun.Id);
        Assert.Equal(AkunController.NamaAkunDihapus, sesudah.Name);
        Assert.NotEqual(akun.Phone, sesudah.Phone);
        Assert.StartsWith("hapus-", sesudah.Phone);
        Assert.Null(sesudah.Address);
        Assert.Null(sesudah.PasswordHash);
        Assert.NotNull(sesudah.DeletedAt);
        Assert.True(sesudah.Dihapus);

        var perangkat = await DenganDbAsync(db =>
            db.PerangkatNotifikasi.CountAsync(p => p.UserId == akun.Id));
        Assert.Equal(0, perangkat);
    }

    /// <summary>
    /// Token berlaku enam puluh menit. Penghapusan yang cuma menghentikan penerbitan token
    /// berikutnya membiarkan akun yang baru dihapus tetap dipakai sampai sisa jam itu habis.
    /// </summary>
    [Fact]
    public async Task TokenLamaLangsungMatiSesudahAkunDihapus()
    {
        var (klien, akun) = await AkunAsync();
        Assert.Equal(HttpStatusCode.OK, (await klien.GetAsync("/api/auth/saya")).StatusCode);

        (await HapusAsync(akun.Phone)).EnsureSuccessStatusCode();

        Assert.Equal(HttpStatusCode.Unauthorized, (await klien.GetAsync("/api/auth/saya")).StatusCode);
    }

    [Fact]
    public async Task NomorLamaBisaDidaftarkanSebagaiAkunBaruDanAkunLamaTetapTertutup()
    {
        var (_, akun) = await AkunAsync();
        (await HapusAsync(akun.Phone)).EnsureSuccessStatusCode();

        // Nomornya bebas lagi: orang yang sama bisa mendaftar baru, dan itu akun yang berbeda.
        // Akun lama tidak ikut hidup kembali, karena nomornya sudah diganti nomor pengganti.
        var tamu = pabrik.CreateClient();
        (await tamu.PostAsJsonAsync(
            "/api/auth/daftar",
            new { Nama = "Pendaftar Baru", NoHp = akun.Phone, Password = "sandiAman123" }))
            .EnsureSuccessStatusCode();

        var baru = await DenganDbAsync(db => db.Users.AsNoTracking().SingleAsync(u => u.Phone == akun.Phone));
        Assert.NotEqual(akun.Id, baru.Id);
        Assert.Equal("Pendaftar Baru", baru.Name);
        Assert.False(baru.Dihapus);

        var lama = await BacaUserAsync(akun.Id);
        Assert.True(lama.Dihapus);
        Assert.NotEqual(akun.Phone, lama.Phone);
    }

    // --- Catatan uang dan jejak tidak ikut hilang ---

    [Fact]
    public async Task OrderSelesaiTetapAdaTapiIsiPribadinyaDibersihkan()
    {
        var (_, akun) = await AkunAsync();
        var order = await BuatOrderAsync(akun.Id, OrderStatus.Selesai);

        (await HapusAsync(akun.Phone)).EnsureSuccessStatusCode();

        var sesudah = await DenganDbAsync(db => db.Orders.AsNoTracking().SingleAsync(o => o.Id == order.Id));

        // Catatan transaksinya utuh.
        Assert.Equal(OrderStatus.Selesai, sesudah.Status);
        Assert.Equal(11000m, sesudah.Price);
        Assert.Equal(akun.Id, sesudah.ClientId);

        // Isi yang bisa mengenali orangnya hilang.
        Assert.Null(sesudah.Description);
        Assert.Null(sesudah.PickupAddress);
        Assert.Null(sesudah.DestinationAddress);
        Assert.Null(sesudah.PhotoUrl);
        Assert.Null(sesudah.HandoverNote);
    }

    [Fact]
    public async Task IsiPesanYangDikirimAkunDibersihkanTapiBarisnyaTetap()
    {
        var (_, klien) = await AkunAsync();
        var (_, runner) = await AkunAsync([UserRole.Runner]);
        var order = await BuatOrderAsync(klien.Id, OrderStatus.Selesai);

        var (pesanKlienId, pesanRunnerId) = await DenganDbAsync(async db =>
        {
            var dariKlien = new OrderMessage
            {
                OrderId = order.Id, SenderId = klien.Id, SenderRole = UserRole.Klien, Text = "Alamat saya di kos Melati",
            };
            var dariRunner = new OrderMessage
            {
                OrderId = order.Id, SenderId = runner.Id, SenderRole = UserRole.Runner, Text = "Siap, meluncur",
            };
            db.OrderMessages.AddRange(dariKlien, dariRunner);
            await db.SaveChangesAsync();
            return (dariKlien.Id, dariRunner.Id);
        });

        (await HapusAsync(klien.Phone)).EnsureSuccessStatusCode();

        var (dariKlienSesudah, dariRunnerSesudah) = await DenganDbAsync(async db =>
            (await db.OrderMessages.AsNoTracking().SingleAsync(m => m.Id == pesanKlienId),
             await db.OrderMessages.AsNoTracking().SingleAsync(m => m.Id == pesanRunnerId)));

        Assert.Null(dariKlienSesudah.Text);
        // Pesan pihak lain di order yang sama bukan milik akun yang dihapus.
        Assert.Equal("Siap, meluncur", dariRunnerSesudah.Text);
    }

    [Fact]
    public async Task RunnerYangDihapusTidakLagiMenerimaSiaranDanPenawarannyaDitarik()
    {
        var (_, klien) = await AkunAsync();
        var (_, runner) = await AkunAsync([UserRole.Klien, UserRole.Runner]);
        var order = await BuatOrderAsync(klien.Id, OrderStatus.Permintaan);

        var penawaranId = await DenganDbAsync(async db =>
        {
            var penawaran = new OrderOffer
            {
                OrderId = order.Id,
                CreatedByRunnerId = runner.Id,
                Price = 50000m,
                EstimatedDuration = TimeSpan.FromHours(2),
                ScheduledStart = DateTime.UtcNow.AddHours(4),
                Note = "Saya bawa troli sendiri",
            };
            db.OrderOffers.Add(penawaran);
            await db.SaveChangesAsync();
            return penawaran.Id;
        });

        (await HapusAsync(runner.Phone)).EnsureSuccessStatusCode();

        var sesudah = await BacaUserAsync(runner.Id);
        Assert.Equal([UserRole.Klien], sesudah.Roles);
        Assert.False(sesudah.IsRunner);

        var penawaran = await DenganDbAsync(db => db.OrderOffers.AsNoTracking().SingleAsync(o => o.Id == penawaranId));
        Assert.Equal(OfferStatus.Dicabut, penawaran.Status);
        Assert.Null(penawaran.Note);
    }

    // --- Penolakan ---

    [Fact]
    public async Task KodeSalahDitolakDanAkunTidakBerubah()
    {
        var (_, akun) = await AkunAsync();
        var tamu = pabrik.CreateClient();
        (await tamu.PostAsJsonAsync("/api/auth/minta-kode", new { NoHp = akun.Phone })).EnsureSuccessStatusCode();
        var benar = pabrik.Otp.KodeUntuk(akun.Phone)!;
        var salah = benar == "000000" ? "111111" : "000000";

        var jawaban = await HapusAsync(akun.Phone, salah);

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
        Assert.False((await BacaUserAsync(akun.Id)).Dihapus);
    }

    /// <summary>
    /// Aplikasi mengeluarkan penggunanya pada setiap 401 yang membawa token. Kode yang salah
    /// ketik dari pemanggil bertoken harus 400, bukan 401, dan sesinya tetap berlaku.
    /// </summary>
    [Fact]
    public async Task KodeSalahDariPemanggilBertokenDijawab400BukanTidakBerwenang()
    {
        var (klien, akun) = await AkunAsync();
        (await klien.PostAsJsonAsync("/api/auth/minta-kode", new { NoHp = akun.Phone })).EnsureSuccessStatusCode();
        var benar = pabrik.Otp.KodeUntuk(akun.Phone)!;
        var salah = benar == "000000" ? "111111" : "000000";

        var jawaban = await klien.PostAsJsonAsync("/api/akun/hapus", new { NoHp = akun.Phone, Kode = salah });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await klien.GetAsync("/api/auth/saya")).StatusCode);
        Assert.False((await BacaUserAsync(akun.Id)).Dihapus);
    }

    [Fact]
    public async Task NomorYangTidakTerdaftarDijawabSamaDenganKodeSalah()
    {
        var jawaban = await HapusAsync(NomorBaru(), "123456");

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    [Fact]
    public async Task PesananAktifMenahanPenghapusanDenganAlasanYangJelas()
    {
        var (klien, akun) = await AkunAsync();
        await BuatOrderAsync(akun.Id, OrderStatus.MencariRunner);

        // Pemeriksaan awal yang dipakai aplikasi sebelum meminta kode.
        var awal = await klien.GetFromJsonAsync<JsonElement>("/api/akun/penghapusan");
        Assert.False(awal.GetProperty("bisaDihapus").GetBoolean());
        Assert.Contains("pesanan", awal.GetProperty("penghalang")[0].GetString());

        var jawaban = await HapusAsync(akun.Phone);

        Assert.Equal(HttpStatusCode.Conflict, jawaban.StatusCode);
        var badan = await jawaban.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Contains("pesanan", badan.GetProperty("detail").GetString());
        Assert.False((await BacaUserAsync(akun.Id)).Dihapus);
    }

    [Fact]
    public async Task AkunTanpaPenghalangDinyatakanBisaDihapus()
    {
        var (klien, _) = await AkunAsync();

        var awal = await klien.GetFromJsonAsync<JsonElement>("/api/akun/penghapusan");

        Assert.True(awal.GetProperty("bisaDihapus").GetBoolean());
        Assert.Equal(0, awal.GetProperty("penghalang").GetArrayLength());
    }

    [Fact]
    public async Task BayaranRunnerYangBelumDicairkanMenahanPenghapusan()
    {
        var (_, klien) = await AkunAsync();
        var (_, runner) = await AkunAsync([UserRole.Klien, UserRole.Runner]);
        var order = await BuatOrderAsync(klien.Id, OrderStatus.Selesai);

        await DenganDbAsync(async db =>
        {
            db.OrderRunnerAssignments.Add(new OrderRunnerAssignment
            {
                OrderId = order.Id,
                RunnerId = runner.Id,
                PayoutAmount = 9000m,
            });
            await db.SaveChangesAsync();
            return 0;
        });

        var jawaban = await HapusAsync(runner.Phone);

        Assert.Equal(HttpStatusCode.Conflict, jawaban.StatusCode);
        Assert.Contains("bayaran", (await jawaban.Content.ReadFromJsonAsync<JsonElement>())
            .GetProperty("detail").GetString());
    }

    [Fact]
    public async Task RunnerYangMasihMengerjakanOrderTidakBisaMenghapusAkun()
    {
        var (_, klien) = await AkunAsync();
        var (_, runner) = await AkunAsync([UserRole.Klien, UserRole.Runner]);
        var order = await BuatOrderAsync(klien.Id, OrderStatus.Dikerjakan);

        await DenganDbAsync(async db =>
        {
            db.OrderRunnerAssignments.Add(new OrderRunnerAssignment { OrderId = order.Id, RunnerId = runner.Id });
            await db.SaveChangesAsync();
            return 0;
        });

        Assert.Equal(HttpStatusCode.Conflict, (await HapusAsync(runner.Phone)).StatusCode);
    }

    [Fact]
    public async Task PengembalianDanaYangBelumDicatatMenahanPenghapusan()
    {
        var (_, akun) = await AkunAsync();
        var order = await BuatOrderAsync(akun.Id, OrderStatus.Batal);

        await DenganDbAsync(async db =>
        {
            db.Payments.Add(new Payment
            {
                OrderId = order.Id,
                Amount = 11000m,
                GatewayReference = "ref-uji-" + Guid.NewGuid().ToString("N")[..8],
                Status = PaymentStatus.Berhasil,
                ExpiresAt = DateTime.UtcNow.AddHours(1),
            });
            await db.SaveChangesAsync();
            return 0;
        });

        var jawaban = await HapusAsync(akun.Phone);

        Assert.Equal(HttpStatusCode.Conflict, jawaban.StatusCode);
        Assert.Contains("Pengembalian dana", (await jawaban.Content.ReadFromJsonAsync<JsonElement>())
            .GetProperty("detail").GetString());
    }

    [Fact]
    public async Task AkunAdminTidakBisaDihapusLewatJalurIni()
    {
        var (_, admin) = await AkunAsync([UserRole.Admin]);

        var jawaban = await HapusAsync(admin.Phone);

        Assert.Equal(HttpStatusCode.Conflict, jawaban.StatusCode);
        Assert.False((await BacaUserAsync(admin.Id)).Dihapus);
    }

    [Fact]
    public async Task AkunYangDitangguhkanTidakBisaMenghapusDiriUntukMengelakDariPenangguhan()
    {
        var (_, akun) = await AkunAsync();
        await DenganDbAsync(async db =>
        {
            var user = await db.Users.SingleAsync(u => u.Id == akun.Id);
            user.SuspendedAt = DateTime.UtcNow;
            user.SuspendedReason = "Uji";
            await db.SaveChangesAsync();
            return 0;
        });

        var jawaban = await HapusAsync(akun.Phone);

        Assert.Equal(HttpStatusCode.Conflict, jawaban.StatusCode);
    }

    /// <summary>
    /// Kode terpakai walaupun penghapusannya ditolak, supaya jawaban "belum bisa" tidak
    /// bisa dipakai ulang untuk mengintip penghalang akun orang lain dengan satu kode curian.
    /// </summary>
    [Fact]
    public async Task KodeTidakBisaDipakaiUlangSesudahPenghapusanDitolak()
    {
        var (_, akun) = await AkunAsync();
        await BuatOrderAsync(akun.Id, OrderStatus.MencariRunner);

        var tamu = pabrik.CreateClient();
        (await tamu.PostAsJsonAsync("/api/auth/minta-kode", new { NoHp = akun.Phone })).EnsureSuccessStatusCode();
        var kode = pabrik.Otp.KodeUntuk(akun.Phone)!;

        Assert.Equal(HttpStatusCode.Conflict, (await HapusAsync(akun.Phone, kode)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await HapusAsync(akun.Phone, kode)).StatusCode);
    }
}
