using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Perawatan;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Order yang sudah terlalu lama menganggur di keadaan yang seharusnya cepat berlalu.
///
/// Aturannya dulu tinggal di dashboard sebagai perhitungan di layar, jadi order yang macet
/// secara harfiah tidak ada bagi siapa pun yang tidak sedang membuka halaman tabelnya. Server
/// tidak bisa menyaringnya, tidak pernah menyebutkannya, dan tidak ada apa pun yang
/// memperhatikan ketika tidak ada seorang pun menatap dashboard.
///
/// Yang paling penting dijaga di sini bukan salah satu bentuknya, melainkan bahwa kedua
/// bentuk aturannya sepakat: ekspresi yang diterjemahkan jadi WHERE, dan fungsi C# biasa yang
/// mengisi bendera di setiap jawaban. Aturan yang ditulis dua kali akan berbeda begitu salah
/// satunya diperbaiki, dan yang terjadi dashboard yang menyaring beda dari yang ia tandai.
/// </summary>
public class OrderMacetTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
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

        var (token, _) = new TokenService(Microsoft.Extensions.Options.Options.Create(new JwtOptions
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

    /// <summary>
    /// Menaruh satu order langsung di basis data dengan waktu yang sudah lewat.
    ///
    /// Ditulis langsung, bukan lewat endpoint lalu menunggu sepuluh menit, karena yang diuji
    /// aturannya dan bukan jalannya waktu.
    /// </summary>
    private async Task<Guid> OrderAsync(
        Guid klienId,
        OrderStatus status,
        DateTime dibuatPada,
        DateTime? dibayarPada)
    {
        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();

        var order = new Order
        {
            ClientId = klienId,
            ServiceType = ServiceType.AnterJemput,
            Status = status,
            Price = 11000m,
            CreatedAt = dibuatPada,
            PaidAt = dibayarPada,
        };

        db.Orders.Add(order);
        await db.SaveChangesAsync();
        return order.Id;
    }

    private static DateTime MenitLalu(int menit) => DateTime.UtcNow.AddMinutes(-menit);

    private static int AmbangMenit => (int)OrderMacet.Ambang.TotalMinutes;

    // --- Aturannya sendiri ---

    /// <summary>
    /// Keadaan terburuk yang bisa dialami sistem ini: uangnya sudah masuk, pekerjaannya
    /// belum dimulai, kliennya menunggu.
    /// </summary>
    [Fact]
    public void OrderBerbayarYangLamaTidakDiambilTerhitungMacet()
    {
        var order = new Order
        {
            ClientId = Guid.NewGuid(),
            Status = OrderStatus.MencariRunner,
            CreatedAt = MenitLalu(AmbangMenit * 3),
            PaidAt = MenitLalu(AmbangMenit + 1),
        };

        Assert.True(OrderMacet.Sedang(order, DateTime.UtcNow));
    }

    /// <summary>
    /// Koreksi terhadap perhitungan lama di dashboard, yang menghitung dari waktu pembuatan
    /// order. Order yang lama menunggu klien membayar lalu akhirnya dibayar akan langsung
    /// terhitung macet begitu masuk MencariRunner, padahal pencariannya baru saja dimulai —
    /// dan yang menunggu sebelum itu memang klien sendiri, bukan organisasi.
    /// </summary>
    [Fact]
    public void OrderYangBaruSajaDibayarBelumMacetWalauDibuatBerjamJamLalu()
    {
        var order = new Order
        {
            ClientId = Guid.NewGuid(),
            Status = OrderStatus.MencariRunner,
            CreatedAt = MenitLalu(600),
            PaidAt = MenitLalu(1),
        };

        Assert.False(OrderMacet.Sedang(order, DateTime.UtcNow));
    }

    [Fact]
    public void PermintaanJalurBYangBelumDitawarSiapaPunTerhitungMacet()
    {
        var order = new Order
        {
            ClientId = Guid.NewGuid(),
            Status = OrderStatus.Permintaan,
            CreatedAt = MenitLalu(AmbangMenit + 1),
        };

        Assert.True(OrderMacet.Sedang(order, DateTime.UtcNow));
    }

    /// <summary>
    /// Yang ditunggu di sana klien, bukan organisasi. Menandainya macet berarti menyuruh
    /// admin mengejar sesuatu yang memang bukan urusannya.
    /// </summary>
    [Fact]
    public void OrderYangMenungguKlienMembayarTidakPernahMacet()
    {
        var order = new Order
        {
            ClientId = Guid.NewGuid(),
            Status = OrderStatus.MenungguPembayaran,
            CreatedAt = MenitLalu(600),
        };

        Assert.False(OrderMacet.Sedang(order, DateTime.UtcNow));
    }

    [Theory]
    [InlineData(nameof(OrderStatus.Dikerjakan))]
    [InlineData(nameof(OrderStatus.Selesai))]
    [InlineData(nameof(OrderStatus.Batal))]
    public void OrderYangSudahBergerakAtauBerakhirTidakMacet(string statusMentah)
    {
        var order = new Order
        {
            ClientId = Guid.NewGuid(),
            Status = Enum.Parse<OrderStatus>(statusMentah),
            CreatedAt = MenitLalu(600),
            PaidAt = MenitLalu(600),
        };

        Assert.False(OrderMacet.Sedang(order, DateTime.UtcNow));
    }

    // --- Kedua bentuk aturannya wajib sepakat ---

    /// <summary>
    /// Inti berkas ini. Ekspresi yang diterjemahkan jadi WHERE dan fungsi C# yang mengisi
    /// bendera di setiap jawaban adalah dua tulisan untuk satu aturan; kalau salah satunya
    /// diperbaiki tanpa yang lain, dashboard akan menyaring beda dari yang ia tandai, dan
    /// tidak ada yang meledak untuk memberi tahu.
    /// </summary>
    [Fact]
    public async Task PenyaringBasisDataSepakatDenganPerhitunganDiKode()
    {
        var (_, klienId) = await AkunAsync(UserRole.Klien);

        var kandidat = new List<Guid>
        {
            await OrderAsync(klienId, OrderStatus.MencariRunner, MenitLalu(600), MenitLalu(AmbangMenit + 5)),
            await OrderAsync(klienId, OrderStatus.MencariRunner, MenitLalu(600), MenitLalu(1)),
            await OrderAsync(klienId, OrderStatus.Permintaan, MenitLalu(AmbangMenit + 5), null),
            await OrderAsync(klienId, OrderStatus.Permintaan, MenitLalu(1), null),
            await OrderAsync(klienId, OrderStatus.MenungguPembayaran, MenitLalu(600), null),
            await OrderAsync(klienId, OrderStatus.Dikerjakan, MenitLalu(600), MenitLalu(600)),
            await OrderAsync(klienId, OrderStatus.Selesai, MenitLalu(600), MenitLalu(600)),
        };

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var sekarang = DateTime.UtcNow;

        var menurutBasisData = await Task.FromResult(
            db.Orders.Where(OrderMacet.Ekspresi(sekarang))
                .Where(o => kandidat.Contains(o.Id))
                .Select(o => o.Id)
                .ToHashSet());

        var semua = db.Orders.Where(o => kandidat.Contains(o.Id)).ToList();
        var menurutKode = semua
            .Where(o => OrderMacet.Sedang(o, sekarang))
            .Select(o => o.Id)
            .ToHashSet();

        Assert.Equal(menurutKode, menurutBasisData);
        // Kalau keduanya kebetulan sama-sama kosong, kesepakatannya tidak membuktikan apa pun.
        Assert.NotEmpty(menurutKode);
    }

    // --- Yang sekarang bisa dilakukan server ---

    [Fact]
    public async Task JawabanOrderMembawaBenderaMacetnya()
    {
        var (klien, klienId) = await AkunAsync(UserRole.Klien);
        var macet = await OrderAsync(
            klienId, OrderStatus.MencariRunner, MenitLalu(600), MenitLalu(AmbangMenit + 5));
        var baru = await OrderAsync(
            klienId, OrderStatus.MencariRunner, MenitLalu(600), MenitLalu(1));

        Assert.True((await klien.GetFromJsonAsync<OrderResponse>($"/api/orders/{macet}"))!.Macet);
        Assert.False((await klien.GetFromJsonAsync<OrderResponse>($"/api/orders/{baru}"))!.Macet);
    }

    /// <summary>
    /// Disaring di basis data, bukan sesudah halamannya terpotong: menyaring belakangan
    /// berarti order macet yang kebetulan berada di halaman kedua tidak pernah ditemukan.
    /// </summary>
    [Fact]
    public async Task AdminBisaMenyaringOrderYangMacet()
    {
        var (_, klienId) = await AkunAsync(UserRole.Klien);
        var (admin, _) = await AkunAsync(UserRole.Admin);

        var macet = await OrderAsync(
            klienId, OrderStatus.MencariRunner, MenitLalu(600), MenitLalu(AmbangMenit + 5));
        var baru = await OrderAsync(
            klienId, OrderStatus.MencariRunner, MenitLalu(600), MenitLalu(1));

        var halaman = await admin.GetFromJsonAsync<HalamanResponse<OrderResponse>>(
            $"/api/admin/orders?macet=true&ukuran={BatasHalaman.Maksimal}");

        Assert.Contains(halaman!.Isi, o => o.Id == macet);
        Assert.DoesNotContain(halaman.Isi, o => o.Id == baru);
    }

    /// <summary>
    /// Yang membuat "macet" berhenti jadi sekadar warna baris: ada yang menghitungnya juga
    /// ketika tidak ada seorang pun sedang membuka dashboard.
    /// </summary>
    [Fact]
    public async Task PenyapuMenghitungOrderYangMacet()
    {
        var (_, klienId) = await AkunAsync(UserRole.Klien);
        await OrderAsync(
            klienId, OrderStatus.MencariRunner, MenitLalu(600), MenitLalu(AmbangMenit + 5));

        using var lingkup = pabrik.Services.CreateScope();
        var penyapu = lingkup.ServiceProvider.GetRequiredService<Penyapu>();

        var hasil = await penyapu.SapuAsync();

        Assert.True(hasil.OrderMacet > 0);
    }

    /// <summary>
    /// Dan tidak mengubah apa pun. Order yang macet berisi uang klien yang sudah masuk;
    /// membatalkannya sendiri berarti mengembalikan uang tanpa ada yang memutuskan.
    /// </summary>
    [Fact]
    public async Task PenyapuTidakMenyentuhOrderYangMacet()
    {
        var (klien, klienId) = await AkunAsync(UserRole.Klien);
        var macet = await OrderAsync(
            klienId, OrderStatus.MencariRunner, MenitLalu(600), MenitLalu(AmbangMenit + 5));

        using (var lingkup = pabrik.Services.CreateScope())
        {
            await lingkup.ServiceProvider.GetRequiredService<Penyapu>().SapuAsync();
        }

        var sesudah = (await klien.GetFromJsonAsync<OrderResponse>($"/api/orders/{macet}"))!;
        Assert.Equal(nameof(OrderStatus.MencariRunner), sesudah.Status);
    }
}
