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
/// Perilaku halaman pada tiga daftar order yang dibaca aplikasi.
///
/// Ketiganya dulu mengirim seluruh barisnya. Yang paling cepat membengkak bukan yang paling
/// ramai melainkan yang paling lama: riwayat pemesanan dan riwayat pekerjaan cuma bertambah,
/// tidak pernah menyusut, dan aplikasi mengambilnya ulang setiap lima belas detik selama
/// layarnya terbuka. Endpoint tanpa batas di sana berarti biayanya tumbuh terus sepanjang
/// aplikasinya dipakai, yaitu justru ke arah yang tidak bisa diperbaiki dengan menunggu.
/// </summary>
public class HalamanDaftarOrderTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
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

    private static Task<HalamanResponse<OrderResponse>?> HalamanAsync(HttpClient klien, string jalur) =>
        klien.GetFromJsonAsync<HalamanResponse<OrderResponse>>(jalur);

    // --- Daftar order klien ---

    [Fact]
    public async Task DaftarKlienTerpotongSesuaiUkuranYangDiminta()
    {
        var klien = await AkunAsync(UserRole.Klien);
        for (var i = 0; i < 3; i++) await BuatOrderAsync(klien);

        var halaman = await HalamanAsync(klien, "/api/orders/saya?ukuran=2");

        Assert.Equal(2, halaman!.Isi.Count);
        Assert.Equal(3, halaman.Total);
    }

    [Fact]
    public async Task TotalMenyebutSeluruhRiwayatBukanCumaHalamanIni()
    {
        // Angka inilah alasan jawabannya dibungkus. Layar yang menampilkan dua puluh order
        // padahal ada enam puluh tidak terlihat seperti bug; ia terlihat seperti riwayat
        // yang memang segitu.
        var klien = await AkunAsync(UserRole.Klien);
        for (var i = 0; i < 5; i++) await BuatOrderAsync(klien);

        var halaman = await HalamanAsync(klien, "/api/orders/saya?ukuran=1");

        Assert.Single(halaman!.Isi);
        Assert.Equal(5, halaman.Total);
        Assert.Equal(5, halaman.TotalHalaman);
    }

    [Fact]
    public async Task HalamanBerurutanTidakMelewatkanDanTidakMengulang()
    {
        // Yang dijaga di sini pemecah serinya. Order yang dibuat beruntun bisa punya
        // CreatedAt yang sama sampai milidetik, dan tanpa pemecah seri Postgres boleh
        // mengurutkannya berbeda di setiap kueri: satu baris hilang dari halaman pertama
        // lalu muncul dua kali di halaman kedua, tanpa ada yang salah di kodenya.
        var klien = await AkunAsync(UserRole.Klien);
        var dibuat = new List<Guid>();
        for (var i = 0; i < 6; i++) dibuat.Add((await BuatOrderAsync(klien)).Id);

        var terkumpul = new List<Guid>();
        for (var h = 1; h <= 3; h++)
        {
            var halaman = await HalamanAsync(klien, $"/api/orders/saya?ukuran=2&halaman={h}");
            terkumpul.AddRange(halaman!.Isi.Select(o => o.Id));
        }

        Assert.Equal(6, terkumpul.Count);
        Assert.Equal(6, terkumpul.Distinct().Count());
        Assert.Equal([.. dibuat.OrderBy(x => x)], [.. terkumpul.OrderBy(x => x)]);
    }

    [Fact]
    public async Task TerbaruTetapDiAtas()
    {
        var klien = await AkunAsync(UserRole.Klien);
        await BuatOrderAsync(klien);
        var terakhir = await BuatOrderAsync(klien);

        var halaman = await HalamanAsync(klien, "/api/orders/saya?ukuran=1");

        Assert.Equal(terakhir.Id, halaman!.Isi.Single().Id);
    }

    [Fact]
    public async Task HalamanDiLuarJangkauanKosong()
    {
        // Kosong, bukan galat. Aplikasi yang meminta halaman berikutnya tepat saat baris
        // terakhir terpakai habis tidak sedang melakukan kesalahan.
        var klien = await AkunAsync(UserRole.Klien);
        await BuatOrderAsync(klien);

        var halaman = await HalamanAsync(klien, "/api/orders/saya?halaman=99");

        Assert.Empty(halaman!.Isi);
        Assert.Equal(1, halaman.Total);
    }

    // --- Order yang dipegang runner ---

    [Fact]
    public async Task DaftarRunnerIkutBerhalaman()
    {
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        for (var i = 0; i < 3; i++)
        {
            var order = await BuatOrderAsync(klien);
            await BayarAsync(order.Id, order.Harga!.Value);
            (await runner.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();
        }

        var halaman = await HalamanAsync(runner, "/api/orders/runner-saya?ukuran=2");

        Assert.Equal(2, halaman!.Isi.Count);
        Assert.Equal(3, halaman.Total);
    }

    // --- Siaran ---

    [Fact]
    public async Task SiaranIkutBerhalaman()
    {
        var klien = await AkunAsync(UserRole.Klien);
        var runner = await AkunAsync(UserRole.Runner);
        for (var i = 0; i < 3; i++)
        {
            var order = await BuatOrderAsync(klien);
            await BayarAsync(order.Id, order.Harga!.Value);
        }

        var halaman = await HalamanAsync(runner, "/api/orders/tersiar?ukuran=2");

        Assert.Equal(2, halaman!.Isi.Count);
        Assert.True(halaman.Total >= 3);
    }

    // --- Bawaan dan batas ---

    [Theory]
    [InlineData("/api/orders/saya")]
    [InlineData("/api/orders/runner-saya")]
    [InlineData("/api/orders/tersiar")]
    public async Task TanpaParameterTetapBerbatas(string jalur)
    {
        // Bagian yang paling menentukan. Endpoint yang baru berbatas kalau diminta akan tetap
        // tidak berbatas bagi setiap pemanggil yang lupa memintanya, dan pemanggil yang lupa
        // itu biasanya kode yang ditulis paling belakangan.
        var pemanggil = jalur == "/api/orders/saya"
            ? await AkunAsync(UserRole.Klien)
            : await AkunAsync(UserRole.Runner);

        var halaman = await HalamanAsync(pemanggil, jalur);

        Assert.Equal(BatasHalaman.Bawaan, halaman!.UkuranHalaman);
        Assert.Equal(1, halaman.Halaman);
        Assert.True(halaman.Isi.Count <= BatasHalaman.Bawaan);
    }

    [Theory]
    [InlineData("ukuran=0")]
    [InlineData("ukuran=101")]
    [InlineData("halaman=0")]
    public async Task PermintaanHalamanYangTidakMasukAkalDitolak(string kueri)
    {
        var klien = await AkunAsync(UserRole.Klien);

        var jawaban = await klien.GetAsync($"/api/orders/saya?{kueri}");

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task JumlahPesanTetapIkutDiSetiapBaris()
    {
        // Penghitungan pesan dikerjakan sekali untuk seluruh baris di halaman, bukan satu
        // kueri per order. Kalau pemotongannya sampai memutus hubungan itu, angkanya jadi
        // nol untuk semua orang tanpa ada yang gagal.
        var klien = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);
        (await klien.PostAsJsonAsync($"/api/orders/{order.Id}/pesan", new { Isi = "halo" }))
            .EnsureSuccessStatusCode();

        var halaman = await HalamanAsync(klien, "/api/orders/saya?ukuran=100");

        Assert.Equal(1, halaman!.Isi.Single(o => o.Id == order.Id).JumlahPesan);
    }
}
