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
/// Jalur B adalah tawar-menawar, dan tawar-menawar punya dua sisi yang tidak boleh
/// tertukar: yang menyebut harga adalah admin, yang menjawabnya adalah pemesan. Sebagian
/// besar tes di sini menjaga pemisahan itu.
/// </summary>
public class JalurBEndpointTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
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

    private static async Task<OrderResponse> BuatPermintaanAsync(HttpClient klien)
    {
        var jawaban = await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BersihKos),
            Deskripsi = "Kos dua kamar, sudah lama tidak dibersihkan.",
            JadwalMulai = DateTime.UtcNow.AddDays(2),
            JumlahRunnerDibutuhkan = 2,
        });
        jawaban.EnsureSuccessStatusCode();
        return (await jawaban.Content.ReadFromJsonAsync<OrderResponse>())!;
    }

    private static Task<HttpResponseMessage> TawarkanAsync(
        HttpClient admin,
        Guid orderId,
        decimal harga = 150000) =>
        admin.PostAsJsonAsync($"/api/orders/{orderId}/penawaran", new
        {
            Harga = harga,
            EstimasiDurasiMenit = 180,
            JadwalMulai = DateTime.UtcNow.AddDays(2),
            Catatan = "Dikerjakan dua orang.",
        });

    // --- Membuat permintaan ---

    [Fact]
    public async Task PermintaanLahirTanpaHarga()
    {
        // Itu yang membedakan Jalur B dari Jalur A. Menampilkan angka apa pun di sini akan
        // menjanjikan sesuatu yang belum tentu disetujui admin.
        var (klien, _) = await AkunAsync(UserRole.Klien);

        var order = await BuatPermintaanAsync(klien);

        Assert.Null(order.Harga);
        Assert.Equal(nameof(OrderStatus.Permintaan), order.Status);
        Assert.Equal(nameof(OrderTrack.JalurB), order.Track);
        Assert.Empty(order.Penawaran);
    }

    [Fact]
    public async Task LayananJalurATidakBisaDikirimSebagaiPermintaan()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);

        var jawaban = await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            Deskripsi = "Antar ke kampus",
            JadwalMulai = DateTime.UtcNow.AddDays(1),
        });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task DeskripsiKosongDitolak()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);

        var jawaban = await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BersihKos),
            Deskripsi = "",
            JadwalMulai = DateTime.UtcNow.AddDays(1),
        });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task RunnerTidakBisaMengirimPermintaan()
    {
        var (runner, _) = await AkunAsync(UserRole.Runner);

        var jawaban = await runner.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BersihKos),
            Deskripsi = "Titip bersih-bersih",
            JadwalMulai = DateTime.UtcNow.AddDays(1),
        });

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }

    // --- Penawaran admin ---

    [Fact]
    public async Task AdminMenawarDanOrderMenungguPersetujuanKlien()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (admin, adminId) = await AkunAsync(UserRole.Admin);
        var order = await BuatPermintaanAsync(klien);

        var jawaban = await TawarkanAsync(admin, order.Id);
        jawaban.EnsureSuccessStatusCode();
        var sesudah = (await jawaban.Content.ReadFromJsonAsync<OrderResponse>())!;

        Assert.Equal(nameof(OrderStatus.MenungguPersetujuanKlien), sesudah.Status);
        Assert.Single(sesudah.Penawaran);
        Assert.Equal(150000m, sesudah.Penawaran[0].Harga);

        // Harga penawaran belum jadi harga order. Order yang memajang harga yang belum
        // disepakati akan terbaca sebagai tagihan.
        Assert.Null(sesudah.Harga);

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var tersimpan = await db.OrderOffers.SingleAsync(f => f.OrderId == order.Id);
        Assert.Equal(adminId, tersimpan.CreatedByAdminId);
    }

    [Fact]
    public async Task KlienTidakBisaMenawarOrdernyaSendiri()
    {
        // Kalau bisa, klien tinggal menawar dirinya sendiri seharga satu rupiah lalu
        // menyetujuinya.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatPermintaanAsync(klien);

        var jawaban = await TawarkanAsync(klien, order.Id, harga: 1);

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }

    [Fact]
    public async Task RunnerTidakBisaMenawar()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatPermintaanAsync(klien);

        var jawaban = await TawarkanAsync(runner, order.Id);

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }

    [Fact]
    public async Task PenawaranKeduaDitolakSelamaYangPertamaMasihMenunggu()
    {
        // Tanpa ini, penawaran kedua diam-diam menimpa yang sedang dibaca klien, dan klien
        // menekan setuju untuk harga yang berbeda dari yang tampil di layarnya.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (admin, _) = await AkunAsync(UserRole.Admin);
        var order = await BuatPermintaanAsync(klien);

        (await TawarkanAsync(admin, order.Id)).EnsureSuccessStatusCode();
        var kedua = await TawarkanAsync(admin, order.Id, harga: 90000);

        Assert.Equal(HttpStatusCode.BadRequest, kedua.StatusCode);
    }

    [Fact]
    public async Task HargaNolAtauNegatifDitolak()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (admin, _) = await AkunAsync(UserRole.Admin);
        var order = await BuatPermintaanAsync(klien);

        Assert.Equal(HttpStatusCode.BadRequest, (await TawarkanAsync(admin, order.Id, 0)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await TawarkanAsync(admin, order.Id, -5000)).StatusCode);
    }

    [Fact]
    public async Task OrderJalurATidakBisaDitawari()
    {
        // Harganya sudah tertulis di layar klien sejak awal. Mengizinkan penawaran di sana
        // berarti membuka jalan mengubahnya.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (admin, _) = await AkunAsync(UserRole.Admin);

        var buat = await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
        });
        var jalurA = (await buat.Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;

        var jawaban = await TawarkanAsync(admin, jalurA.Id);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    // --- Jawaban klien ---

    private async Task<(HttpClient Klien, HttpClient Admin, OrderResponse Order)> SiapDitawariAsync()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (admin, _) = await AkunAsync(UserRole.Admin);
        var order = await BuatPermintaanAsync(klien);
        (await TawarkanAsync(admin, order.Id)).EnsureSuccessStatusCode();
        return (klien, admin, order);
    }

    [Fact]
    public async Task MenyetujuiMemindahkanHargaPenawaranKeOrder()
    {
        var (klien, _, order) = await SiapDitawariAsync();

        var jawaban = await klien.PostAsync($"/api/orders/{order.Id}/penawaran/setujui", null);
        jawaban.EnsureSuccessStatusCode();
        var sesudah = (await jawaban.Content.ReadFromJsonAsync<OrderResponse>())!;

        Assert.Equal(150000m, sesudah.Harga);
        Assert.Equal(180, sesudah.EstimasiDurasiMenit);
        Assert.Equal(nameof(OrderStatus.MenungguPembayaran), sesudah.Status);
        Assert.Equal(nameof(OfferStatus.Disetujui), sesudah.Penawaran[0].Status);
    }

    [Fact]
    public async Task KlienLainTidakBisaMenyetujuiPenawaranOrangLain()
    {
        // Peran klien saja tidak cukup. Tanpa pemeriksaan pemilik, klien mana pun bisa
        // menyetujui penawaran di order orang lain cukup dengan menebak idnya.
        var (_, _, order) = await SiapDitawariAsync();
        var (orangLain, _) = await AkunAsync(UserRole.Klien);

        var jawaban = await orangLain.PostAsync($"/api/orders/{order.Id}/penawaran/setujui", null);

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    [Fact]
    public async Task KlienLainTidakBisaMenolakPenawaranOrangLain()
    {
        var (_, _, order) = await SiapDitawariAsync();
        var (orangLain, _) = await AkunAsync(UserRole.Klien);

        var jawaban = await orangLain.PostAsync($"/api/orders/{order.Id}/penawaran/tolak", null);

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    [Fact]
    public async Task MenolakMengakhiriOrder()
    {
        // Bukan mengembalikannya ke antrean admin. Yang masih berminat dengan harga lain
        // memakai nego; yang menekan tolak memang sudah tidak berminat.
        var (klien, _, order) = await SiapDitawariAsync();

        var jawaban = await klien.PostAsync($"/api/orders/{order.Id}/penawaran/tolak", null);
        jawaban.EnsureSuccessStatusCode();
        var sesudah = (await jawaban.Content.ReadFromJsonAsync<OrderResponse>())!;

        Assert.Equal(nameof(OrderStatus.Batal), sesudah.Status);
        Assert.Equal(nameof(OfferStatus.Ditolak), sesudah.Penawaran[0].Status);
        Assert.Null(sesudah.Harga);
    }

    [Fact]
    public async Task NegoMengembalikanOrderKeAntreanAdminDanMenulisAlasannyaDiChat()
    {
        var (klien, _, order) = await SiapDitawariAsync();

        var jawaban = await klien.PostAsJsonAsync(
            $"/api/orders/{order.Id}/penawaran/nego",
            new { Alasan = "Bisa kurang sedikit? Kamarnya kecil." });
        jawaban.EnsureSuccessStatusCode();
        var sesudah = (await jawaban.Content.ReadFromJsonAsync<OrderResponse>())!;

        Assert.Equal(nameof(OrderStatus.Permintaan), sesudah.Status);
        Assert.Equal(nameof(OfferStatus.DinegoUlang), sesudah.Penawaran[0].Status);

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var pesan = await db.OrderMessages.SingleAsync(m => m.OrderId == order.Id);
        Assert.Equal("Bisa kurang sedikit? Kamarnya kecil.", pesan.Text);
        Assert.Equal(sesudah.KlienId, pesan.SenderId);
    }

    [Fact]
    public async Task NegoTanpaAlasanDitolak()
    {
        // Admin tidak punya bahan untuk menghitung ulang.
        var (klien, _, order) = await SiapDitawariAsync();

        var jawaban = await klien.PostAsJsonAsync(
            $"/api/orders/{order.Id}/penawaran/nego",
            new { Alasan = "" });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task SesudahNegoAdminBisaMenawarLagi()
    {
        var (klien, admin, order) = await SiapDitawariAsync();
        await klien.PostAsJsonAsync(
            $"/api/orders/{order.Id}/penawaran/nego",
            new { Alasan = "Bisa kurang?" });

        var kedua = await TawarkanAsync(admin, order.Id, harga: 120000);
        kedua.EnsureSuccessStatusCode();
        var sesudah = (await kedua.Content.ReadFromJsonAsync<OrderResponse>())!;

        Assert.Equal(2, sesudah.Penawaran.Count);
        Assert.Equal(nameof(OrderStatus.MenungguPersetujuanKlien), sesudah.Status);
    }

    [Fact]
    public async Task PenawaranYangSudahDijawabTidakBisaDijawabLagi()
    {
        var (klien, _, order) = await SiapDitawariAsync();
        (await klien.PostAsync($"/api/orders/{order.Id}/penawaran/setujui", null))
            .EnsureSuccessStatusCode();

        var lagi = await klien.PostAsync($"/api/orders/{order.Id}/penawaran/setujui", null);

        Assert.Equal(HttpStatusCode.BadRequest, lagi.StatusCode);
    }

    [Fact]
    public async Task MenjawabOrderYangBelumPernahDitawariDitolak()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatPermintaanAsync(klien);

        var jawaban = await klien.PostAsync($"/api/orders/{order.Id}/penawaran/setujui", null);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task TanpaTokenSemuaLangkahJalurBTertutup()
    {
        var tanpaToken = pabrik.CreateClient();
        var id = Guid.NewGuid();

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await tanpaToken.PostAsJsonAsync("/api/orders/jalur-b", new { })).StatusCode);
        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await tanpaToken.PostAsJsonAsync($"/api/orders/{id}/penawaran", new { })).StatusCode);
        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await tanpaToken.PostAsync($"/api/orders/{id}/penawaran/setujui", null)).StatusCode);
    }
}
