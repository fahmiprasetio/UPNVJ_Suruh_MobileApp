using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Controllers;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Chat per order, menutup order, dan membatalkannya.
///
/// Chat adalah tempat orang saling percaya pada apa yang tertulis, jadi yang paling dijaga
/// di sini bukan isinya melainkan namanya: siapa yang tercatat menulis, dan sebagai apa.
/// </summary>
public class ChatDanPenutupanTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
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

    private static async Task<OrderResponse> BuatOrderAsync(HttpClient klien)
    {
        var jawaban = await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
            AlamatJemput = "Kos Melati",
            AlamatTujuan = "Kampus",
        });
        jawaban.EnsureSuccessStatusCode();
        return (await jawaban.Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;
    }

    /// <summary>
    /// Empat byte pertama sebuah JPEG. Server mengenali jenis berkas dari isinya, bukan dari
    /// nama atau Content-Type kiriman, jadi inilah berkas terkecil yang ia terima sebagai
    /// gambar. Gambar sungguhan cuma akan membuat tes ini lebih besar tanpa menguji apa pun
    /// yang belum diuji.
    /// </summary>
    private static readonly byte[] JpegTerkecil = [0xFF, 0xD8, 0xFF, 0xE0];

    /// <summary>Mengunggah satu foto bukti untuk order ini, mengembalikan URL-nya.</summary>
    private static async Task<string> UnggahFotoAsync(HttpClient runner, Guid orderId)
    {
        using var isi = new MultipartFormDataContent();
        var berkas = new ByteArrayContent(JpegTerkecil);
        berkas.Headers.ContentType = new MediaTypeHeaderValue("image/jpeg");
        isi.Add(berkas, "berkas", "bukti.jpg");

        var jawaban = await runner.PostAsync($"/api/orders/{orderId}/foto-bukti", isi);
        jawaban.EnsureSuccessStatusCode();
        return (await jawaban.Content.ReadFromJsonAsync<FotoBuktiResponse>())!.Url;
    }

    private async Task BayarAsync(Guid orderId, decimal jumlah)
    {
        var webhook = pabrik.CreateClient();
        webhook.DefaultRequestHeaders.Add(WebhookOptions.Header, ApiFactory.WebhookSecret);
        (await webhook.PostAsJsonAsync("/api/webhooks/pembayaran", new
        {
            OrderId = orderId,
            ReferensiGateway = "trx-" + Guid.NewGuid().ToString("N"),
            Status = nameof(PaymentStatus.Berhasil),
            Jumlah = jumlah,
        })).EnsureSuccessStatusCode();
    }

    /// <summary>Order yang sudah dibayar dan dipegang satu runner.</summary>
    private async Task<(HttpClient Klien, HttpClient Runner, OrderResponse Order)> DikerjakanAsync()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatOrderAsync(klien);
        await BayarAsync(order.Id, order.Harga!.Value);
        (await runner.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();
        return (klien, runner, order);
    }

    // --- Chat ---

    [Fact]
    public async Task PesanTercatatAtasNamaPengirimnyaDenganPeranYangDiturunkanServer()
    {
        var (klien, runner, order) = await DikerjakanAsync();

        var dariKlien = await klien.PostAsJsonAsync(
            $"/api/orders/{order.Id}/pesan",
            new { Isi = "Tolong titip air mineral juga ya." });
        dariKlien.EnsureSuccessStatusCode();
        var pesanKlien = (await dariKlien.Content.ReadFromJsonAsync<OrderMessageResponse>())!;

        var dariRunner = await runner.PostAsJsonAsync(
            $"/api/orders/{order.Id}/pesan",
            new { Isi = "Siap, sedang jalan." });
        dariRunner.EnsureSuccessStatusCode();
        var pesanRunner = (await dariRunner.Content.ReadFromJsonAsync<OrderMessageResponse>())!;

        Assert.Equal(nameof(UserRole.Klien), pesanKlien.PeranPengirim);
        Assert.Equal(nameof(UserRole.Runner), pesanRunner.PeranPengirim);
    }

    [Fact]
    public async Task PeranPengirimYangDikirimDiBadanPermintaanDiabaikan()
    {
        // Kalau peran penulis bisa disebutkan pemanggil, siapa pun bisa menulis atas nama
        // admin, dan pesan yang tampak dari admin adalah pesan yang dipercaya orang.
        var (klien, _, order) = await DikerjakanAsync();

        var jawaban = await klien.PostAsJsonAsync($"/api/orders/{order.Id}/pesan", new
        {
            Isi = "Halo",
            PeranPengirim = nameof(UserRole.Admin),
            SenderRole = nameof(UserRole.Admin),
            Pengirim = nameof(UserRole.Admin),
        });
        jawaban.EnsureSuccessStatusCode();
        var pesan = (await jawaban.Content.ReadFromJsonAsync<OrderMessageResponse>())!;

        Assert.Equal(nameof(UserRole.Klien), pesan.PeranPengirim);
    }

    [Fact]
    public async Task PesanKosongDitolak()
    {
        var (klien, _, order) = await DikerjakanAsync();

        var jawaban = await klien.PostAsJsonAsync($"/api/orders/{order.Id}/pesan", new { Isi = "   " });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task PesanYangTerlaluPanjangDitolak()
    {
        var (klien, _, order) = await DikerjakanAsync();

        var jawaban = await klien.PostAsJsonAsync(
            $"/api/orders/{order.Id}/pesan",
            new { Isi = new string('a', BatasMasukan.PesanChat + 1) });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task OrangLuarTidakBisaMembacaMaupunMenulisDiChatOrderOrangLain()
    {
        var (_, _, order) = await DikerjakanAsync();
        var (orangLain, _) = await AkunAsync(UserRole.Klien);

        var baca = await orangLain.GetAsync($"/api/orders/{order.Id}/pesan");
        var tulis = await orangLain.PostAsJsonAsync(
            $"/api/orders/{order.Id}/pesan",
            new { Isi = "Numpang lewat" });

        Assert.Equal(HttpStatusCode.NotFound, baca.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, tulis.StatusCode);
    }

    [Fact]
    public async Task RunnerLainYangTidakMemegangOrderTidakBisaMasukKeChatnya()
    {
        // Ia melihat order ini di daftar siaran, tapi yang tampil di sana cuma secukupnya
        // untuk memutuskan mau ambil atau tidak. Percakapannya baru terbuka setelah ia
        // benar-benar memegang ordernya.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runnerAsing, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatOrderAsync(klien);
        await BayarAsync(order.Id, order.Harga!.Value);

        var baca = await runnerAsing.GetAsync($"/api/orders/{order.Id}/pesan");

        Assert.Equal(HttpStatusCode.NotFound, baca.StatusCode);
    }

    [Fact]
    public async Task AdminBisaMasukKeChatOrderManaPun()
    {
        var (_, _, order) = await DikerjakanAsync();
        var (admin, _) = await AkunAsync(UserRole.Admin);

        var jawaban = await admin.PostAsJsonAsync(
            $"/api/orders/{order.Id}/pesan",
            new { Isi = "Halo, ada yang bisa dibantu?" });
        jawaban.EnsureSuccessStatusCode();
        var pesan = (await jawaban.Content.ReadFromJsonAsync<OrderMessageResponse>())!;

        Assert.Equal(nameof(UserRole.Admin), pesan.PeranPengirim);
    }

    [Fact]
    public async Task FounderYangMengambilOrderTercatatSebagaiRunnerBukanAdmin()
    {
        // Ia memegang dua peran, tapi di order ini ia sedang bekerja sebagai runner.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (founder, _) = await AkunAsync(UserRole.Admin, UserRole.Runner);
        var order = await BuatOrderAsync(klien);
        await BayarAsync(order.Id, order.Harga!.Value);
        (await founder.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();

        var jawaban = await founder.PostAsJsonAsync(
            $"/api/orders/{order.Id}/pesan",
            new { Isi = "Sudah otw." });
        jawaban.EnsureSuccessStatusCode();
        var pesan = (await jawaban.Content.ReadFromJsonAsync<OrderMessageResponse>())!;

        Assert.Equal(nameof(UserRole.Runner), pesan.PeranPengirim);
    }

    [Fact]
    public async Task DaftarPesanTerurutDariYangTerlama()
    {
        var (klien, runner, order) = await DikerjakanAsync();
        await klien.PostAsJsonAsync($"/api/orders/{order.Id}/pesan", new { Isi = "satu" });
        await runner.PostAsJsonAsync($"/api/orders/{order.Id}/pesan", new { Isi = "dua" });
        await klien.PostAsJsonAsync($"/api/orders/{order.Id}/pesan", new { Isi = "tiga" });

        var pesan = (await klien.GetFromJsonAsync<HalamanResponse<OrderMessageResponse>>(
            $"/api/orders/{order.Id}/pesan"))!.Isi;

        Assert.Equal(["satu", "dua", "tiga"], pesan!.Select(p => p.Isi));
    }

    [Fact]
    public async Task ChatOrderYangSudahSelesaiIkutDitutup()
    {
        var (klien, runner, order) = await DikerjakanAsync();
        (await runner.PostAsJsonAsync($"/api/orders/{order.Id}/selesai", new
        {
            FotoBuktiUrl = await UnggahFotoAsync(runner, order.Id),
        })).EnsureSuccessStatusCode();

        var jawaban = await klien.PostAsJsonAsync(
            $"/api/orders/{order.Id}/pesan",
            new { Isi = "Masih ada yang mau ditanya" });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task ChatYangSudahDitutupMasihBisaDibaca()
    {
        // Menutup percakapan bukan menghapusnya. Isinya tetap jadi catatan kalau nanti ada
        // yang dipertanyakan.
        var (klien, runner, order) = await DikerjakanAsync();
        await klien.PostAsJsonAsync($"/api/orders/{order.Id}/pesan", new { Isi = "titip air ya" });
        (await runner.PostAsJsonAsync($"/api/orders/{order.Id}/selesai", new
        {
            FotoBuktiUrl = await UnggahFotoAsync(runner, order.Id),
        })).EnsureSuccessStatusCode();

        var pesan = (await klien.GetFromJsonAsync<HalamanResponse<OrderMessageResponse>>(
            $"/api/orders/{order.Id}/pesan"))!.Isi;

        Assert.Single(pesan!);
    }

    // --- Menyelesaikan order ---

    [Fact]
    public async Task RunnerYangMemegangOrderBisaMenutupnyaDenganFotoBukti()
    {
        var (_, runner, order) = await DikerjakanAsync();

        var jawaban = await runner.PostAsJsonAsync($"/api/orders/{order.Id}/selesai", new
        {
            FotoBuktiUrl = await UnggahFotoAsync(runner, order.Id),
            CatatanSerahTerima = "Dititipkan ke satpam kos.",
        });
        jawaban.EnsureSuccessStatusCode();
        var sesudah = (await jawaban.Content.ReadFromJsonAsync<OrderResponse>())!;

        Assert.Equal(nameof(OrderStatus.Selesai), sesudah.Status);
        Assert.NotNull(sesudah.SelesaiPada);
    }

    [Fact]
    public async Task TanpaFotoBuktiDitolak()
    {
        // Itu yang membedakan pekerjaan selesai dari pengakuan selesai.
        var (_, runner, order) = await DikerjakanAsync();

        var jawaban = await runner.PostAsJsonAsync(
            $"/api/orders/{order.Id}/selesai",
            new { FotoBuktiUrl = "" });

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task RunnerLainTidakBisaMenutupOrderYangBukanDipegangnya()
    {
        var (_, _, order) = await DikerjakanAsync();
        var (runnerAsing, _) = await AkunAsync(UserRole.Runner);

        var jawaban = await runnerAsing.PostAsJsonAsync($"/api/orders/{order.Id}/selesai", new
        {
            FotoBuktiUrl = "https://contoh/bukti.jpg",
        });

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    [Fact]
    public async Task KlienTidakBisaMenutupOrdernyaSendiri()
    {
        var (klien, _, order) = await DikerjakanAsync();

        var jawaban = await klien.PostAsJsonAsync($"/api/orders/{order.Id}/selesai", new
        {
            FotoBuktiUrl = "https://contoh/bukti.jpg",
        });

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }

    [Fact]
    public async Task OrderYangBelumDikerjakanTidakBisaDiselesaikan()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatOrderAsync(klien);
        await BayarAsync(order.Id, order.Harga!.Value);

        // Belum ada yang menerimanya, jadi runner ini belum memegangnya.
        var jawaban = await runner.PostAsJsonAsync($"/api/orders/{order.Id}/selesai", new
        {
            FotoBuktiUrl = "https://contoh/bukti.jpg",
        });

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    [Fact]
    public async Task OrderYangSudahSelesaiTidakBisaDiselesaikanLagi()
    {
        var (_, runner, order) = await DikerjakanAsync();
        var foto = await UnggahFotoAsync(runner, order.Id);
        (await runner.PostAsJsonAsync($"/api/orders/{order.Id}/selesai", new
        {
            FotoBuktiUrl = foto,
        })).EnsureSuccessStatusCode();

        var lagi = await runner.PostAsJsonAsync($"/api/orders/{order.Id}/selesai", new
        {
            FotoBuktiUrl = await UnggahFotoAsync(runner, order.Id),
        });

        Assert.Equal(HttpStatusCode.BadRequest, lagi.StatusCode);
    }

    // --- Membatalkan order ---

    [Fact]
    public async Task PemesanBisaMembatalkanOrderYangBelumDibayar()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);

        var jawaban = await klien.PostAsync($"/api/orders/{order.Id}/batal", null);
        jawaban.EnsureSuccessStatusCode();
        var sesudah = (await jawaban.Content.ReadFromJsonAsync<OrderResponse>())!;

        Assert.Equal(nameof(OrderStatus.Batal), sesudah.Status);
    }

    [Fact]
    public async Task OrangLainTidakBisaMembatalkanOrderYangBukanMiliknya()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (orangLain, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);

        var jawaban = await orangLain.PostAsync($"/api/orders/{order.Id}/batal", null);

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    [Fact]
    public async Task RunnerYangMemegangOrderTidakBisaMembatalkannya()
    {
        // Runner yang tidak jadi mengerjakan adalah urusan yang perlu diketahui admin, bukan
        // tombol yang menghapus pekerjaan orang lain.
        var (_, runner, order) = await DikerjakanAsync();

        var jawaban = await runner.PostAsync($"/api/orders/{order.Id}/batal", null);

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    [Fact]
    public async Task OrderYangSudahDibayarTidakBisaDibatalkanLewatAplikasi()
    {
        // Membatalkannya berarti ada uang yang harus kembali, dan pengembalian uang bukan
        // sesuatu yang boleh terjadi sebagai efek samping satu tombol.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);
        await BayarAsync(order.Id, order.Harga!.Value);

        var jawaban = await klien.PostAsync($"/api/orders/{order.Id}/batal", null);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task MembatalkanOrderIkutMematikanTagihanYangMasihMenunggu()
    {
        // Belum dibayar tidak berarti belum ditagihkan. Begitu klien membuka layar bayar,
        // sebuah transaksi berikut QR-nya sudah dibuat dan berlaku sampai batas waktunya.
        // Kalau ia dibiarkan hidup sesudah ordernya dicabut, QR untuk order yang sudah tidak
        // ada masih bisa dipindai, dan uang yang masuk lewat sana berhenti sebagai baris
        // peringatan di log yang harus ada orang menemukannya.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);
        (await klien.PostAsync($"/api/orders/{order.Id}/pembayaran", null))
            .EnsureSuccessStatusCode();

        (await klien.PostAsync($"/api/orders/{order.Id}/batal", null))
            .EnsureSuccessStatusCode();

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var pembayaran = db.Payments.Where(p => p.OrderId == order.Id).ToList();

        Assert.NotEmpty(pembayaran);
        Assert.All(pembayaran, p => Assert.Equal(PaymentStatus.Gagal, p.Status));
    }

    [Fact]
    public async Task AdminBisaMembatalkanOrderYangBelumDibayar()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (admin, _) = await AkunAsync(UserRole.Admin);
        var order = await BuatOrderAsync(klien);

        var jawaban = await admin.PostAsync($"/api/orders/{order.Id}/batal", null);

        jawaban.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task TanpaTokenChatDanPenutupanTertutup()
    {
        var tanpaToken = pabrik.CreateClient();
        var id = Guid.NewGuid();

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await tanpaToken.GetAsync($"/api/orders/{id}/pesan")).StatusCode);
        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await tanpaToken.PostAsJsonAsync($"/api/orders/{id}/pesan", new { Isi = "x" })).StatusCode);
        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await tanpaToken.PostAsJsonAsync($"/api/orders/{id}/selesai", new { })).StatusCode);
        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await tanpaToken.PostAsync($"/api/orders/{id}/batal", null)).StatusCode);
    }
}
