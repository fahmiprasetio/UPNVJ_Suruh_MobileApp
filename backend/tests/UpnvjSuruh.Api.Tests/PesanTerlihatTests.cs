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
/// Percakapan mana yang sampai ke mata siapa, dan sebanyak apa sekali ambil.
///
/// Jalur B membuat pertanyaan ini punya jawaban yang tidak seragam. Sebelum ada runner sama
/// sekali, klien dan admin tawar-menawar harga di ruang chat order itu. Runner bergabung jauh
/// sesudahnya, dan sebelum perubahan ini ia membuka chat lalu membaca seluruh tawar-menawar
/// itu dari awal: berapa yang diminta, kenapa dianggap kemahalan, apa alasan klien minta
/// dihitung ulang.
///
/// Bagi klien, tahu bahwa orang yang datang ke kosnya sudah membaca ia menawar setengah harga
/// adalah alasan untuk berhenti menawar sama sekali, dan tawar-menawar itu justru bagian yang
/// membuat Jalur B bekerja.
/// </summary>
public class PesanTerlihatTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
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

    private static async Task<OrderResponse> BuatOrderAsync(HttpClient klien)
    {
        var jawaban = await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
        });
        jawaban.EnsureSuccessStatusCode();
        return (await jawaban.Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;
    }

    private async Task BayarAsync(Guid orderId, decimal jumlah)
    {
        var gateway = pabrik.CreateClient();
        gateway.DefaultRequestHeaders.Add(WebhookOptions.Header, ApiFactory.WebhookSecret);
        (await gateway.PostAsJsonAsync("/api/webhooks/pembayaran", new
        {
            OrderId = orderId,
            ReferensiGateway = "trx-" + Guid.NewGuid().ToString("N"),
            Status = nameof(PaymentStatus.Berhasil),
            Jumlah = jumlah,
        })).EnsureSuccessStatusCode();
    }

    private static async Task KirimAsync(HttpClient dari, Guid orderId, string isi) =>
        (await dari.PostAsJsonAsync($"/api/orders/{orderId}/pesan", new { Isi = isi }))
            .EnsureSuccessStatusCode();

    private static async Task<HalamanResponse<OrderMessageResponse>> PesanAsync(
        HttpClient klien,
        Guid orderId,
        string kueri = "ukuran=100") =>
        (await klien.GetFromJsonAsync<HalamanResponse<OrderMessageResponse>>(
            $"/api/orders/{orderId}/pesan?{kueri}"))!;

    /// <summary>
    /// Order yang sudah punya percakapan sebelum runner-nya bergabung, lalu satu pesan lagi
    /// sesudahnya. Persis bentuk yang jadi alasan aturan ini ada.
    /// </summary>
    private async Task<(HttpClient Klien, HttpClient Runner, HttpClient Admin, OrderResponse Order)>
        PercakapanBersejarahAsync()
    {
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        var admin = await AkunAsync(UserRole.Admin);
        var order = await BuatOrderAsync(klien);

        await KirimAsync(klien, order.Id, "harganya bisa kurang tidak?");
        await KirimAsync(admin, order.Id, "segitu sudah paling murah");

        await BayarAsync(order.Id, order.Harga!.Value);
        (await runner.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();

        await KirimAsync(klien, order.Id, "titip air mineral ya");

        return (klien, runner, admin, order);
    }

    // --- Siapa melihat apa ---

    [Fact]
    public async Task RunnerTidakMelihatPercakapanSebelumIaBergabung()
    {
        // Inti berkas ini.
        var (_, runner, _, order) = await PercakapanBersejarahAsync();

        var pesan = await PesanAsync(runner, order.Id);

        Assert.Equal(["titip air mineral ya"], pesan.Isi.Select(p => p.Isi));
    }

    [Fact]
    public async Task PemesannyaTetapMelihatSeluruhPercakapan()
    {
        // Aturan ini menyempitkan pandangan runner, bukan pandangan semua orang. Klien yang
        // kehilangan riwayat tawar-menawarnya sendiri kehilangan satu-satunya catatan tentang
        // apa yang dulu disepakati.
        var (klien, _, _, order) = await PercakapanBersejarahAsync();

        var pesan = await PesanAsync(klien, order.Id);

        Assert.Equal(3, pesan.Isi.Count);
    }

    [Fact]
    public async Task AdminMelihatSeluruhnya()
    {
        // Admin yang menengahi perselisihan harus bisa membaca apa yang dulu dijanjikan.
        var (_, _, admin, order) = await PercakapanBersejarahAsync();

        var pesan = await PesanAsync(admin, order.Id);

        Assert.Equal(3, pesan.Isi.Count);
    }

    [Fact]
    public async Task JumlahPesanDiDaftarOrderIkutMenyempitUntukRunner()
    {
        // Kalau penanda jumlahnya tidak ikut menyempit, runner melihat "ada 3 pesan" lalu
        // membuka percakapan yang isinya satu. Selain membingungkan, angka itu sendiri sudah
        // memberitahukan bahwa ada percakapan sebelum ia datang.
        var (_, runner, _, order) = await PercakapanBersejarahAsync();

        var daftar = await runner.GetFromJsonAsync<HalamanResponse<OrderResponse>>(
            "/api/orders/runner-saya?ukuran=100");

        Assert.Equal(1, daftar!.Isi.Single(o => o.Id == order.Id).JumlahPesan);
    }

    [Fact]
    public async Task JumlahPesanUntukPemesannyaTetapUtuh()
    {
        var (klien, _, _, order) = await PercakapanBersejarahAsync();

        var daftar = await klien.GetFromJsonAsync<HalamanResponse<OrderResponse>>(
            "/api/orders/saya?ukuran=100");

        Assert.Equal(3, daftar!.Isi.Single(o => o.Id == order.Id).JumlahPesan);
    }

    [Fact]
    public async Task TotalPadaJawabanChatIkutAturanYangSama()
    {
        // Total dipakai layar untuk memutuskan apakah masih ada pesan lama yang bisa dimuat.
        // Kalau ia menghitung pesan yang tidak akan pernah terkirim ke runner, tombol muat
        // lagi jadi tombol yang ditekan tapi tidak menghasilkan apa-apa.
        var (_, runner, _, order) = await PercakapanBersejarahAsync();

        var pesan = await PesanAsync(runner, order.Id);

        Assert.Equal(1, pesan.Total);
    }

    [Fact]
    public async Task RunnerKeduaMelihatSejakIaSendiriBergabung()
    {
        // Pada order yang butuh beberapa runner, pemenang tawaran mengisi satu slot
        // langsung begitu dibayar, dan sisa slotnya tetap disiarkan persis seperti Jalur A.
        // Pembanding visibilitasnya penugasan masing-masing, bukan penugasan yang paling
        // awal.
        var klien = await AkunAsync(UserRole.Klien);
        var pertama = await AkunAsync(UserRole.Runner);
        var kedua = await AkunAsync(UserRole.Runner);

        var dibuat = await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BantuPindahKos),
            Deskripsi = "Pindahan satu kamar kos.",
            JadwalMulai = DateTime.UtcNow.AddDays(1),
            JumlahRunnerDibutuhkan = 2,
            HargaUsulan = 150000m,
        });
        dibuat.EnsureSuccessStatusCode();
        var order = (await dibuat.Content.ReadFromJsonAsync<OrderResponse>())!;
        Assert.Equal(2, order.JumlahRunnerDibutuhkan);

        var ditawar = await pertama.PostAsJsonAsync($"/api/orders/{order.Id}/penawaran", new
        {
            Harga = 150000m,
            EstimasiDurasiMenit = 120,
            JadwalMulai = DateTime.UtcNow.AddDays(1),
        });
        ditawar.EnsureSuccessStatusCode();
        var penawaranId = (await ditawar.Content.ReadFromJsonAsync<OrderResponse>())!
            .Penawaran.Single().Id;

        (await klien.PostAsync($"/api/orders/{order.Id}/penawaran/{penawaranId}/setujui", null))
            .EnsureSuccessStatusCode();
        await BayarAsync(order.Id, 150000m);

        // Pertama sudah otomatis terpasang begitu dibayar, tidak perlu menekan terima.
        await KirimAsync(klien, order.Id, "runner pertama sudah jalan");
        var terimaKedua = await kedua.PostAsync($"/api/orders/{order.Id}/terima", null);
        var hasilKedua = (await terimaKedua.Content.ReadFromJsonAsync<TerimaOrderResponse>())!;
        Assert.True(hasilKedua.Dapat, $"runner kedua gagal: {hasilKedua.Keterangan}");
        await KirimAsync(klien, order.Id, "runner kedua menyusul");

        var dilihatPertama = await PesanAsync(pertama, order.Id);
        var dilihatKedua = await PesanAsync(kedua, order.Id);

        Assert.Equal(2, dilihatPertama.Isi.Count);
        Assert.Equal(["runner kedua menyusul"], dilihatKedua.Isi.Select(p => p.Isi));
    }

    // --- Jendela ---

    [Fact]
    public async Task ChatMengirimYangTerbaruLebihDulu()
    {
        // Orang yang membuka chat ingin melihat yang barusan, bukan yang bulan lalu.
        var klien = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);
        for (var i = 1; i <= 5; i++) await KirimAsync(klien, order.Id, "pesan $i".Replace("$i", $"{i}"));

        var pesan = await PesanAsync(klien, order.Id, "ukuran=2");

        Assert.Equal(["pesan 4", "pesan 5"], pesan.Isi.Select(p => p.Isi));
        Assert.Equal(5, pesan.Total);
    }

    [Fact]
    public async Task TerlamaTetapDiAtasDiDalamJendelanya()
    {
        // Dikirim terbaru dulu, lalu dibalik: percakapan dibaca dari atas ke bawah, dan
        // aplikasi yang harus membalik sendiri adalah aplikasi yang akan lupa membaliknya
        // di salah satu layar.
        var klien = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);
        await KirimAsync(klien, order.Id, "satu");
        await KirimAsync(klien, order.Id, "dua");
        await KirimAsync(klien, order.Id, "tiga");

        var pesan = await PesanAsync(klien, order.Id);

        Assert.Equal(["satu", "dua", "tiga"], pesan.Isi.Select(p => p.Isi));
    }

    [Fact]
    public async Task JendelaYangDiperlebarMembawaYangLebihLama()
    {
        var klien = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);
        for (var i = 1; i <= 5; i++) await KirimAsync(klien, order.Id, $"pesan {i}");

        var lebar = await PesanAsync(klien, order.Id, "ukuran=4");

        Assert.Equal(
            ["pesan 2", "pesan 3", "pesan 4", "pesan 5"],
            lebar.Isi.Select(p => p.Isi));
    }

    [Fact]
    public async Task TanpaParameterTetapBerbatas()
    {
        var klien = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);

        var pesan = await klien.GetFromJsonAsync<HalamanResponse<OrderMessageResponse>>(
            $"/api/orders/{order.Id}/pesan");

        Assert.Equal(BatasHalaman.Bawaan, pesan!.UkuranHalaman);
    }

    [Theory]
    [InlineData("ukuran=0")]
    [InlineData("ukuran=101")]
    [InlineData("halaman=0")]
    public async Task PermintaanJendelaYangTidakMasukAkalDitolak(string kueri)
    {
        var klien = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);

        var jawaban = await klien.GetAsync($"/api/orders/{order.Id}/pesan?{kueri}");

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }
}
