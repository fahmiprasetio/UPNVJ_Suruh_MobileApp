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
/// Penanda pesan belum dibaca, dari lahirnya sampai ditandai dibaca lagi.
///
/// <see cref="OrderResponse.JumlahPesan"/> sudah lama ada, tapi angkanya total, bukan yang
/// belum dibaca -- order lama yang percakapannya sudah dibaca semua tetap menunjukkan angka
/// yang sama dengan order yang baru saja dikirimi pesan. <see cref="OrderResponse.JumlahPesanBelumDibaca"/>
/// menjawab pertanyaan yang berbeda, dan harus tetap menghormati aturan visibilitas Jalur B
/// yang sama dengan <see cref="Data.PesanTerlihat"/>: menandai satu jalur obrolan dibaca
/// tidak boleh ikut menandai jalur obrolan lain yang sama sekali belum dilihat.
/// </summary>
public class PesanDibacaTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
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

    private static Task<HttpResponseMessage> TandaiDibacaAsync(
        HttpClient klien, Guid orderId, Guid? runnerId = null) =>
        klien.PostAsync(
            $"/api/orders/{orderId}/pesan/dibaca" + (runnerId is null ? "" : $"?runnerId={runnerId}"),
            null);

    private static async Task<OrderResponse> OrderAsync(HttpClient klien, Guid orderId) =>
        (await klien.GetFromJsonAsync<OrderResponse>($"/api/orders/{orderId}"))!;

    /// <summary>Order Jalur A yang sudah dibayar dan dipegang satu runner.</summary>
    private async Task<(HttpClient Klien, HttpClient Runner, OrderResponse Order)> OrderDikerjakanAsync()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatOrderAsync(klien);

        await BayarAsync(order.Id, order.Harga!.Value);
        (await runner.PostAsync($"/api/orders/{order.Id}/terima", null)).EnsureSuccessStatusCode();

        return (klien, runner, order);
    }

    [Fact]
    public async Task PesanBaruTerhitungBelumDibacaUntukPenerima()
    {
        var (klien, runner, order) = await OrderDikerjakanAsync();

        await KirimAsync(klien, order.Id, "aku di depan kos ya");

        var dilihatRunner = await OrderAsync(runner, order.Id);
        Assert.Equal(1, dilihatRunner.JumlahPesanBelumDibaca);
    }

    [Fact]
    public async Task PengirimSendiriTidakMenghitungPesannyaSendiriSebagaiBelumDibaca()
    {
        var (klien, _, order) = await OrderDikerjakanAsync();

        await KirimAsync(klien, order.Id, "aku di depan kos ya");

        var dilihatKlien = await OrderAsync(klien, order.Id);
        Assert.Equal(0, dilihatKlien.JumlahPesanBelumDibaca);
    }

    [Fact]
    public async Task MenandaiDibacaMenolkanHitungannya()
    {
        var (klien, runner, order) = await OrderDikerjakanAsync();
        await KirimAsync(klien, order.Id, "satu");
        await KirimAsync(klien, order.Id, "dua");

        (await TandaiDibacaAsync(runner, order.Id)).EnsureSuccessStatusCode();

        var dilihatRunner = await OrderAsync(runner, order.Id);
        Assert.Equal(0, dilihatRunner.JumlahPesanBelumDibaca);
        // Total tetap utuh -- yang berubah cuma yang belum dibaca.
        Assert.Equal(2, dilihatRunner.JumlahPesan);
    }

    [Fact]
    public async Task PesanBaruSesudahDibacaKembaliTerhitung()
    {
        var (klien, runner, order) = await OrderDikerjakanAsync();
        await KirimAsync(klien, order.Id, "satu");
        (await TandaiDibacaAsync(runner, order.Id)).EnsureSuccessStatusCode();

        await KirimAsync(klien, order.Id, "dua");

        var dilihatRunner = await OrderAsync(runner, order.Id);
        Assert.Equal(1, dilihatRunner.JumlahPesanBelumDibaca);
    }

    [Fact]
    public async Task TandaiDibacaBolehDipanggilBerulang()
    {
        // Aplikasi memanggilnya tiap kali layar chat dibuka atau jendelanya diambil ulang,
        // jadi ia harus tahan dipanggil berkali-kali untuk jalur yang sama.
        var (klien, runner, order) = await OrderDikerjakanAsync();
        await KirimAsync(klien, order.Id, "satu");

        (await TandaiDibacaAsync(runner, order.Id)).EnsureSuccessStatusCode();
        (await TandaiDibacaAsync(runner, order.Id)).EnsureSuccessStatusCode();
        var ketiga = await TandaiDibacaAsync(runner, order.Id);

        Assert.Equal(HttpStatusCode.NoContent, ketiga.StatusCode);
    }

    [Fact]
    public async Task OrangYangBukanSiapaSiapaDiOrderIniDitolak()
    {
        var (_, _, order) = await OrderDikerjakanAsync();
        var (orangLain, _) = await AkunAsync(UserRole.Klien);

        var jawaban = await TandaiDibacaAsync(orangLain, order.Id);

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    [Fact]
    public async Task MenandaiJalurPribadiSatuRunnerTidakMempengaruhiRunnerLain()
    {
        // Dua runner menawar bersamaan pada order Jalur B yang sama, masing-masing di jalur
        // obrolan pribadinya sendiri dengan klien. Klien membaca jalur runner pertama; jalur
        // runner kedua yang belum pernah ia buka harus tetap terhitung belum dibaca.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (pertama, idPertama) = await AkunAsync(UserRole.Runner);
        var (kedua, _) = await AkunAsync(UserRole.Runner);

        var dibuat = await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BantuPindahKos),
            Deskripsi = "Pindahan satu kamar kos.",
            JadwalMulai = DateTime.UtcNow.AddDays(1),
            JumlahRunnerDibutuhkan = 1,
            HargaUsulan = 150000m,
        });
        dibuat.EnsureSuccessStatusCode();
        var order = (await dibuat.Content.ReadFromJsonAsync<OrderResponse>())!;

        // Menawar dulu, baru bisa chat: tanpa penawaran, runner belum punya jalur obrolan
        // pribadi apa pun untuk order ini.
        (await pertama.PostAsJsonAsync($"/api/orders/{order.Id}/penawaran", new
        {
            Harga = 140000m,
            EstimasiDurasiMenit = 120,
            JadwalMulai = DateTime.UtcNow.AddDays(1),
        })).EnsureSuccessStatusCode();
        (await kedua.PostAsJsonAsync($"/api/orders/{order.Id}/penawaran", new
        {
            Harga = 130000m,
            EstimasiDurasiMenit = 120,
            JadwalMulai = DateTime.UtcNow.AddDays(1),
        })).EnsureSuccessStatusCode();

        await KirimAsync(pertama, order.Id, "saya bisa lebih cepat");
        await KirimAsync(kedua, order.Id, "saya lebih murah");

        Assert.Equal(2, (await OrderAsync(klien, order.Id)).JumlahPesanBelumDibaca);

        (await TandaiDibacaAsync(klien, order.Id, idPertama)).EnsureSuccessStatusCode();

        // Jalur runner pertama sudah ditandai, jalur runner kedua belum pernah dibuka sama
        // sekali -- pesannya harus tetap terhitung.
        Assert.Equal(1, (await OrderAsync(klien, order.Id)).JumlahPesanBelumDibaca);
    }
}
