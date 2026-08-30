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
/// Berapa uang yang benar-benar masuk, bukan cuma apakah kabarnya bilang berhasil.
///
/// Seluruh aturan harga di sistem ini bertumpu pada satu hal: angka yang mengikat dihitung
/// server, tidak pernah diterima dari klien. Aturan itu tidak menjaga apa-apa kalau di ujung
/// alurnya tidak ada yang membandingkan angka tersebut dengan uang yang sungguhan diterima.
/// Tanpa perbandingan itu, "berhasil" saja sudah cukup untuk melunasi order seharga sebelas
/// ribu dengan kabar seribu rupiah.
/// </summary>
public class PembayaranJumlahTests(DatabaseApiFactory pabrik) : IClassFixture<DatabaseApiFactory>
{
    private static string NomorBaru() => "08" + Random.Shared.NextInt64(100000000, 999999999);

    private async Task<HttpClient> KlienAsync()
    {
        var user = new User
        {
            Name = "Uji " + Guid.NewGuid().ToString("N")[..6],
            Phone = NomorBaru(),
            Roles = [UserRole.Klien],
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

    private Task<HttpResponseMessage> KabarAsync(Guid orderId, decimal jumlah)
    {
        var gateway = pabrik.CreateClient();
        gateway.DefaultRequestHeaders.Add(WebhookOptions.Header, ApiFactory.WebhookSecret);

        return gateway.PostAsJsonAsync("/api/webhooks/pembayaran", new
        {
            OrderId = orderId,
            ReferensiGateway = "trx-" + Guid.NewGuid().ToString("N"),
            Status = nameof(PaymentStatus.Berhasil),
            Jumlah = jumlah,
        });
    }

    private static Task<OrderResponse?> OrderAsync(HttpClient klien, Guid id) =>
        klien.GetFromJsonAsync<OrderResponse>($"/api/orders/{id}");

    [Fact]
    public async Task KabarLunasYangJumlahnyaKurangTidakMelunasiOrder()
    {
        // Inti seluruh berkas ini. Harga yang dihitung server tidak menjaga apa-apa kalau
        // kabar seribu rupiah bisa melunasi order seharga sebelas ribu.
        var klien = await KlienAsync();
        var order = await BuatOrderAsync(klien);

        await KabarAsync(order.Id, 1m);

        var sesudah = await OrderAsync(klien, order.Id);
        Assert.Equal(nameof(OrderStatus.MenungguPembayaran), sesudah!.Status);
        Assert.Null(sesudah.DibayarPada);
    }

    [Fact]
    public async Task KabarLunasYangKurangDicatatSebagaiJumlahTidakCocok()
    {
        // Bukan Gagal, dan bukan dibiarkan menunggu. Gagal berarti tidak ada uang yang
        // berpindah, dan yang dibiarkan menunggu akan hangus sendiri saat batas waktunya
        // lewat; keduanya menghapus uang yang sudah masuk dari pembukuan.
        var klien = await KlienAsync();
        var order = await BuatOrderAsync(klien);

        await KabarAsync(order.Id, 1m);

        var transaksi = await klien.GetFromJsonAsync<TransaksiPembayaranResponse>(
            $"/api/orders/{order.Id}/pembayaran");

        Assert.Equal(nameof(PaymentStatus.JumlahTidakCocok), transaksi!.Status);
    }

    [Fact]
    public async Task KabarLunasYangKurangTetapDijawabDuaRatus()
    {
        // Gateway mengulang kiriman yang dijawab selain 2xx, dan tidak satu pun pengulangan
        // itu akan mengubah jumlahnya. Yang dibutuhkan keadaan ini orang, bukan kiriman ulang.
        var klien = await KlienAsync();
        var order = await BuatOrderAsync(klien);

        var jawaban = await KabarAsync(order.Id, 1m);

        Assert.Equal(HttpStatusCode.OK, jawaban.StatusCode);
    }

    [Fact]
    public async Task TagihanDiambilDariHargaOrderBukanDariKabarnya()
    {
        // Kalau jumlah yang tercatat sebagai tagihan diambil dari kabar yang sama yang sedang
        // diperiksa, pemeriksaannya cuma membandingkan sebuah angka dengan dirinya sendiri dan
        // selalu lolos. Order ini belum punya transaksi tercatat, jadi inilah jalur yang
        // membuat transaksinya susulan.
        var klien = await KlienAsync();
        var order = await BuatOrderAsync(klien);

        await KabarAsync(order.Id, 1m);

        var transaksi = await klien.GetFromJsonAsync<TransaksiPembayaranResponse>(
            $"/api/orders/{order.Id}/pembayaran");

        Assert.Equal(order.Harga, transaksi!.Jumlah);
    }

    [Fact]
    public async Task TransaksiYangSudahDibuatKlienJadiPatokannya()
    {
        // Jalur yang satunya: transaksinya sudah ada sebelum kabar datang, jadi yang
        // dibandingkan adalah jumlah pada transaksi itu.
        var klien = await KlienAsync();
        var order = await BuatOrderAsync(klien);
        (await klien.PostAsync($"/api/orders/{order.Id}/pembayaran", null))
            .EnsureSuccessStatusCode();

        await KabarAsync(order.Id, order.Harga!.Value - 1000m);

        var sesudah = await OrderAsync(klien, order.Id);
        Assert.Equal(nameof(OrderStatus.MenungguPembayaran), sesudah!.Status);
    }

    [Fact]
    public async Task JumlahYangPersisMelunasiSepertiBiasa()
    {
        var klien = await KlienAsync();
        var order = await BuatOrderAsync(klien);

        await KabarAsync(order.Id, order.Harga!.Value);

        var sesudah = await OrderAsync(klien, order.Id);
        Assert.Equal(nameof(OrderStatus.MencariRunner), sesudah!.Status);
        Assert.NotNull(sesudah.DibayarPada);
    }

    [Fact]
    public async Task KelebihanBayarTidakMenahanPekerjaan()
    {
        // Yang membayar sudah menyerahkan lebih dari yang diminta. Menahan ordernya berarti
        // menghukum orang yang justru tidak melakukan kesalahan; selisihnya urusan
        // pengembalian uang, dan itu memang pekerjaan orang.
        var klien = await KlienAsync();
        var order = await BuatOrderAsync(klien);

        await KabarAsync(order.Id, order.Harga!.Value + 5000m);

        var sesudah = await OrderAsync(klien, order.Id);
        Assert.Equal(nameof(OrderStatus.MencariRunner), sesudah!.Status);
    }

    [Fact]
    public async Task KurangBayarTidakMenutupJalanMembayarUlang()
    {
        // Ordernya tetap menunggu pembayaran, jadi klien masih bisa membuat transaksi baru.
        // Kalau tidak, satu kabar yang jumlahnya meleset akan mengunci order selamanya.
        var klien = await KlienAsync();
        var order = await BuatOrderAsync(klien);
        await KabarAsync(order.Id, 1m);

        var lagi = await klien.PostAsync($"/api/orders/{order.Id}/pembayaran", null);

        Assert.Equal(HttpStatusCode.OK, lagi.StatusCode);
    }
}
