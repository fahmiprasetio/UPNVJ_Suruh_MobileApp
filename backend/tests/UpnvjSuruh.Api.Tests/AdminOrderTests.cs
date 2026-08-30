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
/// Daftar order admin, yang menutup alur Jalur B.
///
/// Admin sudah bisa mengirim penawaran sejak lama, tapi belum punya satu pun cara menemukan
/// permintaan yang perlu ditawari: ia cuma bisa membuka order yang id-nya sudah ia ketahui,
/// dan tidak ada yang memberitahunya id itu. Yang diuji di sini karena itu bukan cuma bentuk
/// jawabannya, melainkan bahwa antreannya benar-benar bisa dikerjakan dari ujung ke ujung.
/// </summary>
public class AdminOrderTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
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

    private static async Task<OrderResponse> PermintaanJalurBAsync(HttpClient klien)
    {
        var jawaban = await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BersihKos),
            Deskripsi = "Kos dua kamar, sudah lama tidak disapu.",
            JadwalMulai = DateTime.UtcNow.AddDays(1),
        });
        jawaban.EnsureSuccessStatusCode();
        return (await jawaban.Content.ReadFromJsonAsync<OrderResponse>())!;
    }

    private static Task<HalamanResponse<OrderResponse>?> DaftarAsync(HttpClient admin, string kueri) =>
        admin.GetFromJsonAsync<HalamanResponse<OrderResponse>>($"/api/admin/orders?{kueri}");

    // --- Penjagaan ---

    [Fact]
    public async Task TanpaTokenDitolak()
    {
        var jawaban = await pabrik.CreateClient().GetAsync("/api/admin/orders");

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
    }

    [Theory]
    [InlineData(UserRole.Klien)]
    [InlineData(UserRole.Runner)]
    public async Task YangBukanAdminDitolak(UserRole peran)
    {
        // Daftar ini tidak menyaring berdasarkan kepemilikan sama sekali, jadi satu peran
        // yang meleset di sini membuka seluruh order beserta nama dan alamat pemesannya.
        var bukanAdmin = await AkunAsync(peran);

        var jawaban = await bukanAdmin.GetAsync("/api/admin/orders");

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }

    // --- Antrean penawaran ---

    [Fact]
    public async Task PermintaanJalurBMunculDiAntreanPenawaran()
    {
        var klien = await AkunAsync(UserRole.Klien);
        var admin = await AkunAsync(UserRole.Admin);
        var order = await PermintaanJalurBAsync(klien);

        var halaman = await DaftarAsync(admin, $"status={nameof(OrderStatus.Permintaan)}&ukuran=100");

        Assert.Contains(halaman!.Isi, o => o.Id == order.Id);
    }

    [Fact]
    public async Task AdminBisaMenawarOrderYangDitemukannyaDiDaftar()
    {
        // Inti berkas ini: alurnya utuh tanpa ada yang perlu tahu id order dari tempat lain.
        // Admin membuka antreannya, mengambil id dari sana, lalu menawar.
        var klien = await AkunAsync(UserRole.Klien);
        var admin = await AkunAsync(UserRole.Admin);
        var order = await PermintaanJalurBAsync(klien);

        var halaman = await DaftarAsync(admin, $"status={nameof(OrderStatus.Permintaan)}&ukuran=100");
        var dariAntrean = halaman!.Isi.Single(o => o.Id == order.Id);

        var ditawar = await admin.PostAsJsonAsync($"/api/orders/{dariAntrean.Id}/penawaran", new
        {
            Harga = 150000m,
            EstimasiDurasiMenit = 120,
            JadwalMulai = DateTime.UtcNow.AddDays(1),
        });

        Assert.Equal(HttpStatusCode.OK, ditawar.StatusCode);
    }

    [Fact]
    public async Task OrderYangSudahDitawariKeluarDariAntrean()
    {
        // Kalau tidak, antreannya tumbuh terus dan admin menawar order yang sama dua kali.
        var klien = await AkunAsync(UserRole.Klien);
        var admin = await AkunAsync(UserRole.Admin);
        var order = await PermintaanJalurBAsync(klien);

        (await admin.PostAsJsonAsync($"/api/orders/{order.Id}/penawaran", new
        {
            Harga = 150000m,
            EstimasiDurasiMenit = 120,
            JadwalMulai = DateTime.UtcNow.AddDays(1),
        })).EnsureSuccessStatusCode();

        var halaman = await DaftarAsync(admin, $"status={nameof(OrderStatus.Permintaan)}&ukuran=100");

        Assert.DoesNotContain(halaman!.Isi, o => o.Id == order.Id);
    }

    [Fact]
    public async Task PenyaringStatusMenyaringSungguhan()
    {
        var klien = await AkunAsync(UserRole.Klien);
        var admin = await AkunAsync(UserRole.Admin);
        await PermintaanJalurBAsync(klien);

        var halaman = await DaftarAsync(admin, $"status={nameof(OrderStatus.Permintaan)}&ukuran=100");

        Assert.All(halaman!.Isi, o => Assert.Equal(nameof(OrderStatus.Permintaan), o.Status));
    }

    [Fact]
    public async Task TanpaPenyaringStatusSeluruhOrderIkut()
    {
        // Admin memakai daftar yang sama untuk menelusuri keluhan, dan yang dikeluhkan
        // biasanya order yang sudah lewat antrean penawaran.
        var klien = await AkunAsync(UserRole.Klien);
        var admin = await AkunAsync(UserRole.Admin);
        var permintaan = await PermintaanJalurBAsync(klien);

        var dibuat = await klien.PostAsJsonAsync("/api/orders/jalur-a", new
        {
            ServiceType = nameof(ServiceType.AnterJemput),
            JarakKm = 3.0,
        });
        dibuat.EnsureSuccessStatusCode();
        var jalurA = (await dibuat.Content.ReadFromJsonAsync<BuatOrderResponse>())!.Order;

        var halaman = await DaftarAsync(admin, "ukuran=100");

        Assert.Contains(halaman!.Isi, o => o.Id == permintaan.Id);
        Assert.Contains(halaman.Isi, o => o.Id == jalurA.Id);
    }

    [Fact]
    public async Task BarisnyaSelengkapDaftarOrderLain()
    {
        // Bentuknya sengaja OrderResponse yang sama, bukan ringkasan tersendiri. Dashboard
        // yang menampilkan antrean butuh nama pemesan dan deskripsinya untuk memutuskan
        // harga, dan bentuk kedua yang khusus admin adalah tempat kedua yang bisa ketinggalan
        // saat ada field baru.
        var klien = await AkunAsync(UserRole.Klien);
        var admin = await AkunAsync(UserRole.Admin);
        var order = await PermintaanJalurBAsync(klien);

        var halaman = await DaftarAsync(admin, $"status={nameof(OrderStatus.Permintaan)}&ukuran=100");
        var baris = halaman!.Isi.Single(o => o.Id == order.Id);

        Assert.False(string.IsNullOrWhiteSpace(baris.NamaKlien));
        Assert.Equal("Kos dua kamar, sudah lama tidak disapu.", baris.Deskripsi);
        Assert.Equal(nameof(OrderTrack.JalurB), baris.Track);
    }

    // --- Halaman ---

    [Fact]
    public async Task UkuranHalamanMembatasiBarisYangTerkirim()
    {
        var klien = await AkunAsync(UserRole.Klien);
        var admin = await AkunAsync(UserRole.Admin);
        for (var i = 0; i < 3; i++) await PermintaanJalurBAsync(klien);

        var halaman = await DaftarAsync(admin, $"status={nameof(OrderStatus.Permintaan)}&ukuran=2");

        Assert.Equal(2, halaman!.Isi.Count);
        Assert.Equal(2, halaman.UkuranHalaman);
        Assert.Equal(1, halaman.Halaman);
    }

    [Fact]
    public async Task TotalMenyebutSeluruhnyaBukanCumaYangTerkirim()
    {
        // Angka inilah alasan jawabannya dibungkus, bukan dikirim sebagai larik telanjang.
        // Tanpanya, "menunggu penawaran: 2" yang ternyata cuma isi satu halaman terbaca
        // sebagai kabar baik justru saat antreannya sedang menumpuk.
        var klien = await AkunAsync(UserRole.Klien);
        var admin = await AkunAsync(UserRole.Admin);
        var sebelum = (await DaftarAsync(admin, $"status={nameof(OrderStatus.Permintaan)}&ukuran=1"))!.Total;
        for (var i = 0; i < 3; i++) await PermintaanJalurBAsync(klien);

        var halaman = await DaftarAsync(admin, $"status={nameof(OrderStatus.Permintaan)}&ukuran=1");

        Assert.Single(halaman!.Isi);
        Assert.Equal(sebelum + 3, halaman.Total);
    }

    [Fact]
    public async Task HalamanKeduaBerisiBarisYangBerbeda()
    {
        var klien = await AkunAsync(UserRole.Klien);
        var admin = await AkunAsync(UserRole.Admin);
        for (var i = 0; i < 4; i++) await PermintaanJalurBAsync(klien);

        var kueri = $"status={nameof(OrderStatus.Permintaan)}&ukuran=2";
        var pertama = await DaftarAsync(admin, $"{kueri}&halaman=1");
        var kedua = await DaftarAsync(admin, $"{kueri}&halaman=2");

        Assert.Empty(pertama!.Isi.Select(o => o.Id).Intersect(kedua!.Isi.Select(o => o.Id)));
    }

    [Fact]
    public async Task TotalHalamanDihitungDenganPembulatanKeAtas()
    {
        var admin = await AkunAsync(UserRole.Admin);

        var halaman = await DaftarAsync(admin, "ukuran=3");

        Assert.Equal((int)Math.Ceiling(halaman!.Total / 3.0), halaman.TotalHalaman);
    }

    [Theory]
    [InlineData("ukuran=0")]
    [InlineData("ukuran=101")]
    [InlineData("halaman=0")]
    [InlineData("halaman=-1")]
    public async Task PermintaanHalamanYangTidakMasukAkalDitolak(string kueri)
    {
        // Ditolak, bukan dijepit diam-diam. Pemanggil yang meminta seribu baris lalu menerima
        // seratus akan mengira ia sudah menerima semuanya.
        var admin = await AkunAsync(UserRole.Admin);

        var jawaban = await admin.GetAsync($"/api/admin/orders?{kueri}");

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task TanpaUkuranMemakaiBawaan()
    {
        var admin = await AkunAsync(UserRole.Admin);

        var halaman = await DaftarAsync(admin, string.Empty);

        Assert.Equal(BatasHalaman.Bawaan, halaman!.UkuranHalaman);
        Assert.True(halaman.Isi.Count <= BatasHalaman.Bawaan);
    }
}
