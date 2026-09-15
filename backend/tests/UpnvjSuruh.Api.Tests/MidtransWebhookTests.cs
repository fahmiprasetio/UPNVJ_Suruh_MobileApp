using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Payments;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Endpoint webhook Midtrans sungguhan, terpisah dari <c>PembayaranEndpointTests</c> yang
/// menguji jalur tiruan. Payment di sini disuntik langsung ke basis data, bukan lewat
/// <c>POST /api/orders/{id}/pembayaran</c>: pabrik tesnya mendaftarkan
/// <see cref="MidtransPembayaranGateway"/> yang sungguhan (karena <c>Midtrans:ServerKey</c>
/// terisi, sama seperti mesin produksi), dan itu akan mencoba memanggil sandbox Midtrans
/// sungguhan lewat jaringan kalau dipanggil -- yang tidak diinginkan di CI.
/// </summary>
public class MidtransWebhookTests(MidtransWebhookTests.MidtransApiFactory pabrik)
    : IClassFixture<MidtransWebhookTests.MidtransApiFactory>
{
    private async Task<(Order Order, Payment Payment)> SeedAsync(decimal harga)
    {
        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();

        var user = new User
        {
            Name = "Uji Midtrans",
            Phone = "08" + Random.Shared.NextInt64(100000000, 999999999),
        };
        db.Users.Add(user);

        var order = new Order
        {
            ClientId = user.Id,
            OrderCode = "SRH-" + Random.Shared.Next(1000, 9999),
            ServiceType = ServiceType.AnterJemput,
            Status = OrderStatus.MenungguPembayaran,
            Price = harga,
        };
        db.Orders.Add(order);

        var payment = new Payment
        {
            OrderId = order.Id,
            Amount = harga,
            GatewayReference = "belum-tersambung",
            QrPayload = "qr-mentah",
            ExpiresAt = DateTime.UtcNow.AddMinutes(30),
        };
        db.Payments.Add(payment);

        await db.SaveChangesAsync();
        return (order, payment);
    }

    /// <summary>
    /// Tanda tangan sah untuk kunci uji <see cref="MidtransApiFactory.ServerKey"/>, dihitung
    /// sendiri di sini -- <see cref="MidtransOptions"/> cuma tahu cara MEMVERIFIKASI, bukan
    /// menghitung, jadi ini menempuh rumus yang sama persis dengan
    /// <see cref="MidtransOptions.SignatureValid"/> tapi ditulis independen darinya.
    /// </summary>
    private static string TandaTangan(string orderId, string statusCode, string grossAmount)
    {
        var bahan = System.Text.Encoding.UTF8.GetBytes(
            $"{orderId}{statusCode}{grossAmount}{MidtransApiFactory.ServerKey}");
        return Convert.ToHexStringLower(System.Security.Cryptography.SHA512.HashData(bahan));
    }

    private static object Notifikasi(
        string orderId, string statusCode, string grossAmount, string transactionStatus, string? tandaTangan = null) => new
    {
        order_id = orderId,
        status_code = statusCode,
        gross_amount = grossAmount,
        transaction_status = transactionStatus,
        signature_key = tandaTangan ?? TandaTangan(orderId, statusCode, grossAmount),
    };

    [Fact]
    public async Task SettlementDenganTandaTanganSahMelunasiOrder()
    {
        var (order, payment) = await SeedAsync(15000m);
        var orderIdMidtrans = payment.Id.ToString("N");

        var jawaban = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/webhooks/midtrans",
            Notifikasi(orderIdMidtrans, "200", "15000.00", "settlement"));

        jawaban.EnsureSuccessStatusCode();

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var orderSesudah = await db.Orders.SingleAsync(o => o.Id == order.Id);
        Assert.Equal(OrderStatus.MencariRunner, orderSesudah.Status);
        Assert.NotNull(orderSesudah.PaidAt);
    }

    [Fact]
    public async Task TandaTanganYangSalahDitolakDanOrderTidakBergerak()
    {
        var (order, payment) = await SeedAsync(15000m);
        var orderIdMidtrans = payment.Id.ToString("N");

        var jawaban = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/webhooks/midtrans",
            Notifikasi(orderIdMidtrans, "200", "15000.00", "settlement", tandaTangan: "tanda-tangan-palsu"));

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var orderSesudah = await db.Orders.SingleAsync(o => o.Id == order.Id);
        Assert.Equal(OrderStatus.MenungguPembayaran, orderSesudah.Status);
    }

    [Fact]
    public async Task KabarKeduaUntukTransaksiYangSamaTidakMenyiarkanUlang()
    {
        var (_, payment) = await SeedAsync(15000m);
        var orderIdMidtrans = payment.Id.ToString("N");
        var klien = pabrik.CreateClient();

        var pertama = await klien.PostAsJsonAsync(
            "/api/webhooks/midtrans", Notifikasi(orderIdMidtrans, "200", "15000.00", "settlement"));
        pertama.EnsureSuccessStatusCode();

        var kedua = await klien.PostAsJsonAsync(
            "/api/webhooks/midtrans", Notifikasi(orderIdMidtrans, "200", "15000.00", "settlement"));
        kedua.EnsureSuccessStatusCode();

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1, await db.Payments.CountAsync(p => p.Id == payment.Id && p.Status == PaymentStatus.Berhasil));
    }

    [Fact]
    public async Task OrderIdYangTidakDikenalMenjawabNotFound()
    {
        var tidakDikenal = Guid.NewGuid().ToString("N");

        var jawaban = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/webhooks/midtrans",
            Notifikasi(tidakDikenal, "200", "15000.00", "settlement"));

        Assert.Equal(HttpStatusCode.NotFound, jawaban.StatusCode);
    }

    [Fact]
    public async Task JumlahYangKurangDariTagihanTidakMelunasiOrder()
    {
        var (order, payment) = await SeedAsync(15000m);
        var orderIdMidtrans = payment.Id.ToString("N");

        var jawaban = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/webhooks/midtrans",
            Notifikasi(orderIdMidtrans, "200", "1000.00", "settlement"));

        jawaban.EnsureSuccessStatusCode();

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var orderSesudah = await db.Orders.SingleAsync(o => o.Id == order.Id);
        Assert.Equal(OrderStatus.MenungguPembayaran, orderSesudah.Status);
        Assert.Equal(
            PaymentStatus.JumlahTidakCocok,
            (await db.Payments.SingleAsync(p => p.Id == payment.Id)).Status);
    }

    [Fact]
    public async Task StatusPendingTidakMengubahApaPun()
    {
        var (order, payment) = await SeedAsync(15000m);
        var orderIdMidtrans = payment.Id.ToString("N");

        var jawaban = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/webhooks/midtrans",
            Notifikasi(orderIdMidtrans, "201", "15000.00", "pending"));

        jawaban.EnsureSuccessStatusCode();

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        var pembayaranSesudah = await db.Payments.SingleAsync(p => p.Id == payment.Id);
        Assert.Equal(PaymentStatus.Pending, pembayaranSesudah.Status);
    }

    [Fact]
    public async Task ExpireMenandaiTransaksiKedaluwarsa()
    {
        var (_, payment) = await SeedAsync(15000m);
        var orderIdMidtrans = payment.Id.ToString("N");

        var jawaban = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/webhooks/midtrans",
            Notifikasi(orderIdMidtrans, "200", "15000.00", "expire"));

        jawaban.EnsureSuccessStatusCode();

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(
            PaymentStatus.Kedaluwarsa,
            (await db.Payments.SingleAsync(p => p.Id == payment.Id)).Status);
    }

    /// <summary>
    /// Sama seperti <see cref="DatabaseApiFactory"/>, ditambah <c>Midtrans:ServerKey</c>
    /// supaya <c>Program.cs</c> mendaftarkan gateway Midtrans sungguhan dan
    /// <c>MidtransWebhookController</c> punya kunci untuk memverifikasi tanda tangan --
    /// persis kombinasi yang berlaku di mesin produksi begitu Midtrans dipasang.
    /// </summary>
    public class MidtransApiFactory : DatabaseApiFactory
    {
        public const string ServerKey = "kunci-uji-midtrans-yang-cukup-panjang-sekali";

        protected override IHost CreateHost(IHostBuilder builder)
        {
            builder.ConfigureHostConfiguration(config =>
            {
                config.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["Midtrans:ServerKey"] = ServerKey,
                    // Wajib diisi begitu ServerKey diisi (lihat Program.cs) -- nilainya tidak
                    // dipanggil jaringan mana pun di tes ini, cuma perlu ada supaya server
                    // tidak menolak menyala.
                    ["Midtrans:NotificationUrl"] = "https://uji.contoh/api/webhooks/midtrans",
                });
            });

            return base.CreateHost(builder);
        }
    }
}
