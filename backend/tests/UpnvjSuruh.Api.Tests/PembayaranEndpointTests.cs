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
/// Transaksi pembayaran. Yang paling dijaga di sini bukan alurnya melainkan batasnya: klien
/// boleh minta dibuatkan tagihan dan menanyakan statusnya, dan tidak boleh menyentuh apa pun
/// selain itu.
/// </summary>
public class PembayaranEndpointTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
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

    private static async Task<TransaksiPembayaranResponse> BuatTransaksiAsync(
        HttpClient klien,
        Guid orderId)
    {
        var jawaban = await klien.PostAsync($"/api/orders/{orderId}/pembayaran", null);
        jawaban.EnsureSuccessStatusCode();
        return (await jawaban.Content.ReadFromJsonAsync<TransaksiPembayaranResponse>())!;
    }

    [Fact]
    public async Task JumlahnyaDiambilDariHargaOrderBukanDariPermintaan()
    {
        // Klien yang boleh menyebut jumlah yang ia bayar tinggal membuat transaksi seharga
        // satu rupiah untuk order seharga sebelas ribu.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);

        var jawaban = await klien.PostAsJsonAsync(
            $"/api/orders/{order.Id}/pembayaran",
            new { Jumlah = 1m, Amount = 1m });
        jawaban.EnsureSuccessStatusCode();
        var transaksi = (await jawaban.Content.ReadFromJsonAsync<TransaksiPembayaranResponse>())!;

        Assert.Equal(order.Harga, transaksi.Jumlah);
    }

    [Fact]
    public async Task MembukaUlangLayarBayarTidakMelahirkanQrBaru()
    {
        // Dua QR untuk satu order berarti klien bisa membayar dua kali untuk pekerjaan yang
        // sama, dan yang kedua harus dikembalikan.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);

        var pertama = await BuatTransaksiAsync(klien, order.Id);
        var kedua = await BuatTransaksiAsync(klien, order.Id);

        Assert.Equal(pertama.Id, kedua.Id);

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1, await db.Payments.CountAsync(p => p.OrderId == order.Id));
    }

    [Fact]
    public async Task TransaksiLahirMenungguDenganBatasWaktu()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);

        var transaksi = await BuatTransaksiAsync(klien, order.Id);

        Assert.Equal(nameof(PaymentStatus.Pending), transaksi.Status);
        Assert.Null(transaksi.DibayarPada);
        Assert.True(transaksi.KedaluwarsaPada > transaksi.DibuatPada);
    }

    [Fact]
    public async Task QrnyaDitandaiSimulasiDanTidakMenyerupaiQrisAsli()
    {
        // String yang mirip aslinya tapi palsu akan lolos pandangan sekilas dan menipu
        // penguji. Yang seperti ini gagal dipindai aplikasi bank, dan memang seharusnya.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);

        var transaksi = await BuatTransaksiAsync(klien, order.Id);

        Assert.StartsWith("SIMULASI-QRIS", transaksi.QrisPayload);
        Assert.Contains(order.KodeOrder, transaksi.QrisPayload);
    }

    [Fact]
    public async Task OrangLainTidakBisaMembuatkanTagihanUntukOrderOrangLain()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (orangLain, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);

        var jawaban = await orangLain.PostAsync($"/api/orders/{order.Id}/pembayaran", null);

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    [Fact]
    public async Task OrangLainTidakBisaMengintipStatusPembayaranOrderOrangLain()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (orangLain, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);
        await BuatTransaksiAsync(klien, order.Id);

        var jawaban = await orangLain.GetAsync($"/api/orders/{order.Id}/pembayaran");

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    [Fact]
    public async Task RunnerTidakPunyaAksesKePembayaran()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var (runner, _) = await AkunAsync(UserRole.Runner);
        var order = await BuatOrderAsync(klien);

        var jawaban = await runner.PostAsync($"/api/orders/{order.Id}/pembayaran", null);

        Assert.Equal(HttpStatusCode.Forbidden, jawaban.StatusCode);
    }

    [Fact]
    public async Task PermintaanJalurBYangBelumPunyaHargaBelumBisaDibayar()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var buat = await klien.PostAsJsonAsync("/api/orders/jalur-b", new
        {
            ServiceType = nameof(ServiceType.BersihKos),
            Deskripsi = "Kos dua kamar",
            JadwalMulai = DateTime.UtcNow.AddDays(2),
        });
        var order = (await buat.Content.ReadFromJsonAsync<OrderResponse>())!;

        var jawaban = await klien.PostAsync($"/api/orders/{order.Id}/pembayaran", null);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task MembatalkanTransaksiTidakMembatalkanOrdernya()
    {
        // Yang mengakhiri order adalah endpoint batal ordernya sendiri. Klien yang gagal
        // membayar sekali harus tetap bisa mencoba lagi.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);
        await BuatTransaksiAsync(klien, order.Id);

        var batal = await klien.PostAsync($"/api/orders/{order.Id}/pembayaran/batal", null);
        batal.EnsureSuccessStatusCode();

        var sesudah = await klien.GetFromJsonAsync<OrderResponse>($"/api/orders/{order.Id}");
        Assert.Equal(nameof(OrderStatus.MenungguPembayaran), sesudah!.Status);

        // Dan transaksi baru bisa dibuat lagi.
        var lagi = await BuatTransaksiAsync(klien, order.Id);
        Assert.Equal(nameof(PaymentStatus.Pending), lagi.Status);
    }

    [Fact]
    public async Task KlienTidakPunyaEndpointUntukMenyatakanDirinyaSudahMembayar()
    {
        // Tebakan jalur yang masuk akal kalau seseorang mencarinya. Tidak satu pun boleh ada.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);
        await BuatTransaksiAsync(klien, order.Id);

        foreach (var jalur in new[]
        {
            $"/api/orders/{order.Id}/pembayaran/lunas",
            $"/api/orders/{order.Id}/pembayaran/konfirmasi",
            $"/api/orders/{order.Id}/bayar",
            $"/api/orders/{order.Id}/lunas",
        })
        {
            var jawaban = await klien.PostAsync(jalur, null);
            Assert.True(
                jawaban.StatusCode is HttpStatusCode.NotFound or HttpStatusCode.MethodNotAllowed,
                $"{jalur} menjawab {(int)jawaban.StatusCode}, padahal tidak boleh ada.");
        }

        var sesudah = await klien.GetFromJsonAsync<OrderResponse>($"/api/orders/{order.Id}");
        Assert.Equal(nameof(OrderStatus.MenungguPembayaran), sesudah!.Status);
    }

    [Fact]
    public async Task TiruanGatewayMemajukanOrderSepertiWebhookSungguhan()
    {
        // Tiruannya cuma hidup di Development, dan tes berjalan di Development. Yang diuji di
        // sini: ia benar-benar menempuh jalur yang sama dengan webhook, bukan jalan pintas
        // yang perilakunya berbeda.
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);
        await BuatTransaksiAsync(klien, order.Id);

        var jawaban = await pabrik.CreateClient()
            .PostAsync($"/api/dev/pembayaran/{order.Id}/lunas", null);
        jawaban.EnsureSuccessStatusCode();

        var sesudah = await klien.GetFromJsonAsync<OrderResponse>($"/api/orders/{order.Id}");
        Assert.Equal(nameof(OrderStatus.MencariRunner), sesudah!.Status);
        Assert.NotNull(sesudah.DibayarPada);

        var transaksi = await klien.GetFromJsonAsync<TransaksiPembayaranResponse>(
            $"/api/orders/{order.Id}/pembayaran");
        Assert.Equal(nameof(PaymentStatus.Berhasil), transaksi!.Status);
    }

    [Fact]
    public async Task TiruanGatewayMenolakOrderYangBelumPunyaTransaksi()
    {
        var (klien, _) = await AkunAsync(UserRole.Klien);
        var order = await BuatOrderAsync(klien);

        var jawaban = await pabrik.CreateClient()
            .PostAsync($"/api/dev/pembayaran/{order.Id}/lunas", null);

        Assert.Equal(HttpStatusCode.BadRequest, jawaban.StatusCode);
    }

    [Fact]
    public async Task TanpaTokenPembayaranTertutup()
    {
        var tanpaToken = pabrik.CreateClient();
        var id = Guid.NewGuid();

        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await tanpaToken.PostAsync($"/api/orders/{id}/pembayaran", null)).StatusCode);
        Assert.Equal(
            HttpStatusCode.Unauthorized,
            (await tanpaToken.GetAsync($"/api/orders/{id}/pembayaran")).StatusCode);
    }
}
