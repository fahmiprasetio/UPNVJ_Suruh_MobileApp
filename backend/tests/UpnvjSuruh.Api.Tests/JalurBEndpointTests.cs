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
/// Jalur B adalah tawar-menawar ala aplikasi ojek daring: klien mengusulkan harga, banyak
/// runner boleh menawar sekaligus untuk order yang sama, dan klien memilih satu di antaranya.
/// Sebagian besar tes di sini menjaga bahwa runner yang tidak terpilih tidak pernah bisa
/// merebut apa yang sudah dipilih klien untuk runner lain, dan bahwa Admin tidak lagi
/// terlibat sama sekali dalam urusan harga.
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

    private static async Task<OrderResponse> BuatPermintaanAsync(
        HttpClient klien, decimal hargaUsulan = 150000) =>
        (await (await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BersihKos),
            Deskripsi = "Kos dua kamar, sudah lama tidak dibersihkan.",
            JadwalMulai = DateTime.UtcNow.AddDays(2),
            JumlahRunnerDibutuhkan = 1,
            HargaUsulan = hargaUsulan,
        })).EnsureSuccessStatusCode().Content.ReadFromJsonAsync<OrderResponse>())!;

    private static Task<HttpResponseMessage> TawarAsync(
        HttpClient runner,
        Guid orderId,
        decimal harga = 150000) =>
        runner.PostAsJsonAsync($"/api/orders/{orderId}/penawaran", new
        {
            Harga = harga,
            EstimasiDurasiMenit = 180,
            JadwalMulai = DateTime.UtcNow.AddDays(2),
            Catatan = "Dikerjakan sendirian.",
        });

    // --- Membuat permintaan ---

    [Fact]
    public async Task PermintaanLahirTanpaHargaOrderTapiPunyaHargaUsulan()
    {
        // Harga order belum ada karena belum ada satu pun tawaran yang disepakati. Harga
        // usulan sudah ada, karena itu titik awal tawar-menawarnya, bukan harga final.
        var (klien, _) = await AkunAsync(UserRole.Klien);

        var order = await BuatPermintaanAsync(klien, hargaUsulan: 150000);

        Assert.Null(order.Harga);
        Assert.Equal(150000m, order.HargaUsulan);
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
            HargaUsulan = 20000m,
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
            HargaUsulan = 100000m,
        });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task HargaUsulanNolAtauNegatifDitolak()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);

        var jawaban = await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BersihKos),
            Deskripsi = "Kos dua kamar.",
            JadwalMulai = DateTime.UtcNow.AddDays(1),
            HargaUsulan = 0m,
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
            HargaUsulan = 100000m,
        });

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }

    // --- Penawaran runner ---

    [Fact]
    public async Task RunnerMenawarDanOrderTetapPermintaan()
    {
        // Beda dari alur admin yang lama: status ordernya tidak berubah begitu ada satu
        // tawaran masuk, karena runner lain masih boleh menawar juga.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, runnerId) = await AkunAsync(UserRole.Runner);
        var order = await BuatPermintaanAsync(klien);

        var jawaban = await TawarAsync(runner, order.Id);
        jawaban.EnsureSuccessStatusCode();
        var sesudah = (await jawaban.Content.ReadFromJsonAsync<OrderResponse>())!;

        Assert.Equal(nameof(OrderStatus.Permintaan), sesudah.Status);
        Assert.Single(sesudah.Penawaran);
        Assert.Equal(150000m, sesudah.Penawaran[0].Harga);
        Assert.Equal(runnerId, sesudah.Penawaran[0].RunnerId);

        // Harga penawaran belum jadi harga order. Order yang memajang harga yang belum
        // disepakati akan terbaca sebagai tagihan.
        Assert.Null(sesudah.Harga);
    }

    [Fact]
    public async Task KlienYangJugaRunnerTidakBisaMenawarOrdernyaSendiri()
    {
        // Kalau bisa, satu akun tinggal menawar pesanannya sendiri seharga satu rupiah lalu
        // menyetujuinya sendiri.
        var (klien, _) = await AkunAsync(UserRole.Klien, UserRole.Runner);
        var order = await BuatPermintaanAsync(klien);

        var jawaban = await TawarAsync(klien, order.Id, harga: 1);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task KlienTanpaPeranRunnerTidakBisaMenawar()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatPermintaanAsync(klien);

        var jawaban = await TawarAsync(klien, order.Id);

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }

    [Fact]
    public async Task DuaRunnerBerbedaBolehMenawarBersamaanUntukOrderYangSama()
    {
        // Inti dari desain tawar-menawar ini. Dua orang berbeda menawar order yang sama pada
        // saat yang sama bukan tabrakan, itu memang tawar-menawar.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runnerSatu, idSatu) = await AkunAsync(UserRole.Runner);
        var (runnerDua, idDua) = await AkunAsync(UserRole.Runner);
        var order = await BuatPermintaanAsync(klien);

        var jawabanSatu = await TawarAsync(runnerSatu, order.Id, harga: 150000);
        var jawabanDua = await TawarAsync(runnerDua, order.Id, harga: 120000);

        jawabanSatu.EnsureSuccessStatusCode();
        jawabanDua.EnsureSuccessStatusCode();
        var sesudah = (await jawabanDua.Content.ReadFromJsonAsync<OrderResponse>())!;

        Assert.Equal(2, sesudah.Penawaran.Count);
        Assert.Contains(sesudah.Penawaran, p => p.RunnerId == idSatu && p.Harga == 150000m);
        Assert.Contains(sesudah.Penawaran, p => p.RunnerId == idDua && p.Harga == 120000m);
    }

    [Fact]
    public async Task RunnerYangSamaTidakBisaMenawarDuaKaliSementaraYangPertamaMenunggu()
    {
        // Beda dari dua runner berbeda menawar bersamaan (itu sah). Ini satu runner mencoba
        // menawar dua kali untuk order yang sama, dan itu yang ditahan index unik.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatPermintaanAsync(klien);

        (await TawarAsync(runner, order.Id)).EnsureSuccessStatusCode();
        var kedua = await TawarAsync(runner, order.Id, harga: 90000);

        Assert.Equal(HttpStatusCode.Conflict, kedua.StatusCode);
    }

    [Fact]
    public async Task HargaNolAtauNegatifDitolak()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatPermintaanAsync(klien);

        Assert.Equal(HttpStatusCode.BadRequest, (await TawarAsync(runner, order.Id, 0)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await TawarAsync(runner, order.Id, -5000)).StatusCode);
    }

    [Fact]
    public async Task OrderJalurATidakBisaDitawari()
    {
        // Harganya sudah tertulis di layar klien sejak awal. Mengizinkan penawaran di sana
        // berarti membuka jalan mengubahnya.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);

        var buat = await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
        });
        var jalurA = (await buat.Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;

        var jawaban = await TawarAsync(runner, jalurA.Id);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task RunnerTidakBisaMenawarOrderYangSudahDisetujui()
    {
        // Begitu klien memilih satu runner, tawar-menawarnya selesai. Runner lain yang
        // terlambat tidak boleh menyusul menawar order yang sama.
        var (klien, _, _, _, order, penawaranId) = await SiapDitawariAsync();
        await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaranId}/setujui", null);

        var (terlambat, _) = await AkunAsync(UserRole.Runner);
        var jawaban = await TawarAsync(terlambat, order.Id);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    // --- Jawaban klien ---

    private async Task<(HttpClient Klien, Guid RunnerId, HttpClient Runner, Guid KlienId, OrderResponse Order, Guid PenawaranId)>
        SiapDitawariAsync()
    {
        var (klien, klienId) = await AkunAsync(UserRole.Klien);
        var (runner, runnerId) = await AkunAsync(UserRole.Runner);
        var order = await BuatPermintaanAsync(klien);
        var ditawar = await TawarAsync(runner, order.Id);
        ditawar.EnsureSuccessStatusCode();
        var penawaranId = (await ditawar.Content.ReadFromJsonAsync<OrderResponse>())!
            .Penawaran.Single().Id;
        return (klien, runnerId, runner, klienId, order, penawaranId);
    }

    [Fact]
    public async Task MenyetujuiMemindahkanHargaPenawaranKeOrder()
    {
        var (klien, _, _, _, order, penawaranId) = await SiapDitawariAsync();

        var jawaban = await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaranId}/setujui", null);
        jawaban.EnsureSuccessStatusCode();
        var sesudah = (await jawaban.Content.ReadFromJsonAsync<OrderResponse>())!;

        Assert.Equal(150000m, sesudah.Harga);
        Assert.Equal(180, sesudah.EstimasiDurasiMenit);
        Assert.Equal(nameof(OrderStatus.MenungguPembayaran), sesudah.Status);
        Assert.Equal(nameof(OfferStatus.Disetujui), sesudah.Penawaran.Single(p => p.Id == penawaranId).Status);
    }

    [Fact]
    public async Task MenyetujuiMenutupPenawaranRunnerLainOtomatis()
    {
        // Runner yang tidak terpilih tidak menggantung tanpa kabar.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runnerSatu, _) = await AkunAsync(UserRole.Runner);
        var (runnerDua, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatPermintaanAsync(klien);

        var ditawarSatu = await TawarAsync(runnerSatu, order.Id, harga: 150000);
        ditawarSatu.EnsureSuccessStatusCode();
        var penawaranSatu = (await ditawarSatu.Content.ReadFromJsonAsync<OrderResponse>())!
            .Penawaran.Single(p => p.Harga == 150000m).Id;
        await TawarAsync(runnerDua, order.Id, harga: 120000);

        var jawaban = await klien.PostAsync(
            $"/api/orders/{order.Id}/penawaran/{penawaranSatu}/setujui", null);
        jawaban.EnsureSuccessStatusCode();
        var sesudah = (await jawaban.Content.ReadFromJsonAsync<OrderResponse>())!;

        Assert.Equal(nameof(OfferStatus.Disetujui), sesudah.Penawaran.Single(p => p.Id == penawaranSatu).Status);
        Assert.Equal(
            nameof(OfferStatus.Ditutup),
            sesudah.Penawaran.Single(p => p.Id != penawaranSatu).Status);
    }

    [Fact]
    public async Task KlienLainTidakBisaMenyetujuiPenawaranOrangLain()
    {
        // Peran klien saja tidak cukup. Tanpa pemeriksaan pemilik, klien mana pun bisa
        // menyetujui penawaran di order orang lain cukup dengan menebak idnya.
        var (_, _, _, _, order, penawaranId) = await SiapDitawariAsync();
        var (orangLain, _) = await AkunAsync(UserRole.Klien);

        var jawaban = await orangLain.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaranId}/setujui", null);

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    [Fact]
    public async Task KlienLainTidakBisaMenolakPenawaranOrangLain()
    {
        var (_, _, _, _, order, penawaranId) = await SiapDitawariAsync();
        var (orangLain, _) = await AkunAsync(UserRole.Klien);

        var jawaban = await orangLain.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaranId}/tolak", null);

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    [Fact]
    public async Task MenolakHanyaMenutupPenawaranItuSendiriBukanSeluruhOrder()
    {
        // Beda dari alur admin yang lama: menolak satu tawaran tidak lagi membatalkan
        // ordernya. Klien yang masih berminat cukup menunggu tawaran lain, atau nego.
        var (klien, _, _, _, order, penawaranId) = await SiapDitawariAsync();

        var jawaban = await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaranId}/tolak", null);
        jawaban.EnsureSuccessStatusCode();
        var sesudah = (await jawaban.Content.ReadFromJsonAsync<OrderResponse>())!;

        Assert.Equal(nameof(OrderStatus.Permintaan), sesudah.Status);
        Assert.Equal(nameof(OfferStatus.Ditolak), sesudah.Penawaran.Single().Status);
        Assert.Null(sesudah.Harga);
    }

    [Fact]
    public async Task SetelahDitolakRunnerLainMasihBisaMenawarOrderItu()
    {
        var (klien, _, _, _, order, penawaranId) = await SiapDitawariAsync();
        await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaranId}/tolak", null);

        var (runnerLain, _) = await AkunAsync(UserRole.Runner);
        var jawaban = await TawarAsync(runnerLain, order.Id, harga: 130000);

        jawaban.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task NegoMenulisAlasannyaDiJalurObrolanPribadiRunnerItu()
    {
        var (klien, klienId, runnerId, _, order, penawaranId) = await SiapDitawariNamaLengkapAsync();

        var jawaban = await klien.PostAsJsonAsync(
            $"/api/orders/{order.Id}/penawaran/{penawaranId}/nego",
            new { Alasan = "Bisa kurang sedikit? Kamarnya kecil." });
        jawaban.EnsureSuccessStatusCode();
        var sesudah = (await jawaban.Content.ReadFromJsonAsync<OrderResponse>())!;

        Assert.Equal(nameof(OrderStatus.Permintaan), sesudah.Status);
        Assert.Equal(nameof(OfferStatus.DinegoUlang), sesudah.Penawaran.Single().Status);

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var pesan = await db.OrderMessages.SingleAsync(m => m.OrderId == order.Id);
        Assert.Equal("Bisa kurang sedikit? Kamarnya kecil.", pesan.Text);
        Assert.Equal(klienId, pesan.SenderId);
        Assert.Equal(runnerId, pesan.RunnerPenawarId);
    }

    /// <summary>Sama seperti <see cref="SiapDitawariAsync"/>, tapi mengembalikan id klien juga.</summary>
    private async Task<(HttpClient Klien, Guid KlienId, Guid RunnerId, HttpClient Runner, OrderResponse Order, Guid PenawaranId)>
        SiapDitawariNamaLengkapAsync()
    {
        var (klien, runnerId, runner, klienId, order, penawaranId) = await SiapDitawariAsync();
        return (klien, klienId, runnerId, runner, order, penawaranId);
    }

    [Fact]
    public async Task NegoTanpaAlasanDitolak()
    {
        // Runner tidak punya bahan untuk menghitung ulang.
        var (klien, _, _, _, order, penawaranId) = await SiapDitawariAsync();

        var jawaban = await klien.PostAsJsonAsync(
            $"/api/orders/{order.Id}/penawaran/{penawaranId}/nego",
            new { Alasan = "" });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task SesudahNegoRunnerYangSamaBisaMenawarLagi()
    {
        var (klien, _, runner, _, order, penawaranId) = await SiapDitawariAsync();
        await klien.PostAsJsonAsync(
            $"/api/orders/{order.Id}/penawaran/{penawaranId}/nego",
            new { Alasan = "Bisa kurang?" });

        var kedua = await TawarAsync(runner, order.Id, harga: 120000);
        kedua.EnsureSuccessStatusCode();
        var sesudah = (await kedua.Content.ReadFromJsonAsync<OrderResponse>())!;

        Assert.Equal(2, sesudah.Penawaran.Count);
        Assert.Equal(nameof(OrderStatus.Permintaan), sesudah.Status);
    }

    [Fact]
    public async Task PenawaranYangSudahDijawabTidakBisaDijawabLagi()
    {
        var (klien, _, _, _, order, penawaranId) = await SiapDitawariAsync();
        (await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaranId}/setujui", null))
            .EnsureSuccessStatusCode();

        var lagi = await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaranId}/setujui", null);

        Assert.Equal(HttpStatusCode.BadRequest, lagi.StatusCode);
    }

    [Fact]
    public async Task MenjawabPenawaranYangTidakPernahAdaDitolak()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatPermintaanAsync(klien);

        var jawaban = await klien.PostAsync(
            $"/api/orders/{order.Id}/penawaran/{Guid.NewGuid()}/setujui", null);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task TanpaTokenSemuaLangkahJalurBTertutup()
    {
        var tanpaToken = pabrik.CreateClient();
        var id = Guid.NewGuid();
        var offerId = Guid.NewGuid();

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await tanpaToken.PostAsJsonAsync("/api/orders/jalur-b", new { })).StatusCode);
        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await tanpaToken.PostAsJsonAsync($"/api/orders/{id}/penawaran", new { })).StatusCode);
        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await tanpaToken.PostAsync($"/api/orders/{id}/penawaran/{offerId}/setujui", null)).StatusCode);
    }
}
