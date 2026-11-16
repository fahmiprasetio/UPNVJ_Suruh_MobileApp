using System.Net;
using System.Net.Http.Json;
using System.Collections.Concurrent;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Payments;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Endpoint webhook dengan tanda tangan sungguhan dan respons GET status terkontrol.
/// Tidak ada panggilan Midtrans eksternal dalam CI.
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
            ExpiresAt = DateTime.UtcNow.AddMinutes(30),
        };
        db.Payments.Add(payment);

        await db.SaveChangesAsync();
        pabrik.Status.Transaksi[payment.Id] = new StatusTransaksiMidtrans(
            payment.Id.ToString("N"), "200", harga.ToString("F2", System.Globalization.CultureInfo.InvariantCulture),
            "settlement", null);
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

        var sebelum = pabrik.Status.JumlahPermintaan;

        var jawaban = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/webhooks/midtrans",
            Notifikasi(orderIdMidtrans, "200", "15000.00", "settlement"));

        jawaban.EnsureSuccessStatusCode();
        Assert.Equal(sebelum + 1, pabrik.Status.JumlahPermintaan);

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
        var sebelum = pabrik.Status.JumlahPermintaan;

        var jawaban = await pabrik.CreateClient().PostAsJsonAsync(
            "/api/webhooks/midtrans",
            Notifikasi(orderIdMidtrans, "200", "15000.00", "settlement", tandaTangan: "tanda-tangan-palsu"));

        Assert.Equal(HttpStatusCode.Unauthorized, jawaban.StatusCode);
        Assert.Equal(sebelum, pabrik.Status.JumlahPermintaan);

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
        pabrik.Status.Transaksi[payment.Id] = pabrik.Status.Transaksi[payment.Id] with { GrossAmount = "1000.00" };

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
        pabrik.Status.Transaksi[payment.Id] = pabrik.Status.Transaksi[payment.Id] with
        {
            StatusCode = "201", TransactionStatus = "pending",
        };

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
        pabrik.Status.Transaksi[payment.Id] = pabrik.Status.Transaksi[payment.Id] with { TransactionStatus = "expire" };

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

    [Fact]
    public async Task StatusNotifikasiYangDiubahTidakBisaMelunasiTransaksiPending()
    {
        var (order, payment) = await SeedAsync(15000m);
        pabrik.Status.Transaksi[payment.Id] = pabrik.Status.Transaksi[payment.Id] with
        {
            StatusCode = "201", TransactionStatus = "pending",
        };

        // Signature tetap sah walaupun transaction_status diubah menjadi settlement.
        var jawaban = await pabrik.CreateClient().PostAsJsonAsync("/api/webhooks/midtrans",
            Notifikasi(payment.Id.ToString("N"), "201", "15000.00", "settlement"));
        jawaban.EnsureSuccessStatusCode();

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(OrderStatus.MenungguPembayaran, (await db.Orders.FindAsync(order.Id))!.Status);
        Assert.Equal(PaymentStatus.Pending, (await db.Payments.FindAsync(payment.Id))!.Status);
    }

    [Theory]
    [InlineData("capture", "challenge")]
    [InlineData("capture", "deny")]
    [InlineData("capture", null)]
    [InlineData("settlement", "deny")]
    [InlineData("settlement", "challenge")]
    public async Task FraudYangBelumDiterimaTidakMelunasiOrder(string status, string? fraud)
    {
        var (order, payment) = await SeedAsync(15000m);
        pabrik.Status.Transaksi[payment.Id] = pabrik.Status.Transaksi[payment.Id] with
        {
            TransactionStatus = status, FraudStatus = fraud,
        };

        var jawaban = await pabrik.CreateClient().PostAsJsonAsync("/api/webhooks/midtrans",
            Notifikasi(payment.Id.ToString("N"), "200", "15000.00", "settlement"));
        jawaban.EnsureSuccessStatusCode();

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Null((await db.Orders.FindAsync(order.Id))!.PaidAt);
        Assert.Equal(PaymentStatus.Pending, (await db.Payments.FindAsync(payment.Id))!.Status);
    }

    [Fact]
    public async Task CaptureYangDiterimaMelunasiOrder()
    {
        var (order, payment) = await SeedAsync(15000m);
        pabrik.Status.Transaksi[payment.Id] = pabrik.Status.Transaksi[payment.Id] with
        {
            TransactionStatus = "capture", FraudStatus = "accept",
        };

        var jawaban = await pabrik.CreateClient().PostAsJsonAsync("/api/webhooks/midtrans",
            Notifikasi(payment.Id.ToString("N"), "200", "15000.00", "capture"));
        jawaban.EnsureSuccessStatusCode();

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(OrderStatus.MencariRunner, (await db.Orders.FindAsync(order.Id))!.Status);
    }

    [Fact]
    public async Task JumlahDariMidtransTetapMenjadiPatokanWalauNotifikasiMenyebutLunasPenuh()
    {
        var (order, payment) = await SeedAsync(15000m);
        pabrik.Status.Transaksi[payment.Id] = pabrik.Status.Transaksi[payment.Id] with { GrossAmount = "1000.00" };

        var jawaban = await pabrik.CreateClient().PostAsJsonAsync("/api/webhooks/midtrans",
            Notifikasi(payment.Id.ToString("N"), "200", "15000.00", "settlement"));
        jawaban.EnsureSuccessStatusCode();

        using var lingkup = pabrik.Services.CreateScope();
        var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Null((await db.Orders.FindAsync(order.Id))!.PaidAt);
        Assert.Equal(PaymentStatus.JumlahTidakCocok, (await db.Payments.FindAsync(payment.Id))!.Status);
    }

    [Fact]
    public async Task VerifikasiYangGagalMemintaPengirimanUlangTanpaMengubahPembayaran()
    {
        var (order, payment) = await SeedAsync(15000m);
        var status = pabrik.Status.Transaksi[payment.Id];
        pabrik.Status.Transaksi.TryRemove(payment.Id, out _);
        var klien = pabrik.CreateClient();
        var notifikasi = Notifikasi(payment.Id.ToString("N"), "200", "15000.00", "settlement");

        var gagal = await klien.PostAsJsonAsync("/api/webhooks/midtrans", notifikasi);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, gagal.StatusCode);
        using (var lingkup = pabrik.Services.CreateScope())
        {
            var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
            Assert.Null((await db.Orders.FindAsync(order.Id))!.PaidAt);
            Assert.Equal(PaymentStatus.Pending, (await db.Payments.FindAsync(payment.Id))!.Status);
        }

        pabrik.Status.Transaksi[payment.Id] = status;
        (await klien.PostAsJsonAsync("/api/webhooks/midtrans", notifikasi)).EnsureSuccessStatusCode();
        using var verifikasi = pabrik.Services.CreateScope();
        var dbVerifikasi = verifikasi.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.NotNull((await dbVerifikasi.Orders.FindAsync(order.Id))!.PaidAt);
    }

    [Theory]
    [InlineData(PaymentStatus.Gagal)]
    [InlineData(PaymentStatus.Kedaluwarsa)]
    public async Task KonfirmasiLunasTerlambatMemulihkanPembayaranDanMenutupTagihanPengganti(PaymentStatus statusLokal)
    {
        var (order, payment) = await SeedAsync(15000m);
        var pengganti = new Payment
        {
            OrderId = order.Id, Amount = 15000m, GatewayReference = Guid.NewGuid().ToString("N"),
            ExpiresAt = DateTime.UtcNow.AddMinutes(30),
        };
        using (var lingkup = pabrik.Services.CreateScope())
        {
            var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
            (await db.Payments.FindAsync(payment.Id))!.Status = statusLokal;
            await db.SaveChangesAsync();
            db.Payments.Add(pengganti);
            await db.SaveChangesAsync();
        }

        var notifikasi = Notifikasi(payment.Id.ToString("N"), "201", "15000.00", "pending");
        var klien = pabrik.CreateClient();
        (await klien.PostAsJsonAsync("/api/webhooks/midtrans", notifikasi)).EnsureSuccessStatusCode();
        (await klien.PostAsJsonAsync("/api/webhooks/midtrans", notifikasi)).EnsureSuccessStatusCode();

        using var verifikasi = pabrik.Services.CreateScope();
        var dbVerifikasi = verifikasi.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(OrderStatus.MencariRunner, (await dbVerifikasi.Orders.FindAsync(order.Id))!.Status);
        var lunas = (await dbVerifikasi.Payments.FindAsync(payment.Id))!;
        Assert.Equal(PaymentStatus.Berhasil, lunas.Status);
        Assert.NotNull(lunas.SettledAt);
        Assert.Equal(PaymentStatus.Gagal, (await dbVerifikasi.Payments.FindAsync(pengganti.Id))!.Status);
        Assert.Equal(1, await dbVerifikasi.OrderStatusChanges.CountAsync(p => p.OrderId == order.Id));
    }

    [Fact]
    public async Task KonfirmasiTerlambatTidakMenghidupkanKembaliOrderBatal()
    {
        var (order, payment) = await SeedAsync(15000m);
        using (var lingkup = pabrik.Services.CreateScope())
        {
            var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
            (await db.Orders.FindAsync(order.Id))!.Status = OrderStatus.Batal;
            (await db.Payments.FindAsync(payment.Id))!.Status = PaymentStatus.Gagal;
            await db.SaveChangesAsync();
        }

        (await pabrik.CreateClient().PostAsJsonAsync("/api/webhooks/midtrans",
            Notifikasi(payment.Id.ToString("N"), "200", "15000.00", "settlement"))).EnsureSuccessStatusCode();

        using var verifikasi = pabrik.Services.CreateScope();
        var dbVerifikasi = verifikasi.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(OrderStatus.Batal, (await dbVerifikasi.Orders.FindAsync(order.Id))!.Status);
        Assert.Equal(PaymentStatus.Berhasil, (await dbVerifikasi.Payments.FindAsync(payment.Id))!.Status);
        Assert.NotNull((await dbVerifikasi.Payments.FindAsync(payment.Id))!.SettledAt);
        Assert.False(await dbVerifikasi.OrderStatusChanges.AnyAsync(p => p.OrderId == order.Id));
    }

    [Fact]
    public async Task KonfirmasiLunasTidakMembatalkanRefundAdmin()
    {
        var (order, payment) = await SeedAsync(15000m);
        using (var lingkup = pabrik.Services.CreateScope())
        {
            var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
            (await db.Orders.FindAsync(order.Id))!.Status = OrderStatus.Batal;
            (await db.Payments.FindAsync(payment.Id))!.Status = PaymentStatus.Dikembalikan;
            await db.SaveChangesAsync();
        }

        (await pabrik.CreateClient().PostAsJsonAsync("/api/webhooks/midtrans",
            Notifikasi(payment.Id.ToString("N"), "200", "15000.00", "settlement"))).EnsureSuccessStatusCode();

        using var verifikasi = pabrik.Services.CreateScope();
        var dbVerifikasi = verifikasi.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(PaymentStatus.Dikembalikan, (await dbVerifikasi.Payments.FindAsync(payment.Id))!.Status);
        Assert.Equal(OrderStatus.Batal, (await dbVerifikasi.Orders.FindAsync(order.Id))!.Status);
    }

    [Fact]
    public async Task PembayaranTambahanTerlambatTidakMembuatDuaPembayaranUtama()
    {
        var (order, lama) = await SeedAsync(15000m);
        var utama = new Payment
        {
            OrderId = order.Id, Amount = 15000m, GatewayReference = Guid.NewGuid().ToString("N"),
            Status = PaymentStatus.Berhasil, SettledAt = DateTime.UtcNow, ExpiresAt = DateTime.UtcNow,
        };
        using (var lingkup = pabrik.Services.CreateScope())
        {
            var db = lingkup.ServiceProvider.GetRequiredService<AppDbContext>();
            (await db.Payments.FindAsync(lama.Id))!.Status = PaymentStatus.Kedaluwarsa;
            var tersimpan = (await db.Orders.FindAsync(order.Id))!;
            tersimpan.Status = OrderStatus.MencariRunner;
            tersimpan.PaidAt = utama.SettledAt;
            db.Payments.Add(utama);
            await db.SaveChangesAsync();
        }

        (await pabrik.CreateClient().PostAsJsonAsync("/api/webhooks/midtrans",
            Notifikasi(lama.Id.ToString("N"), "200", "15000.00", "settlement"))).EnsureSuccessStatusCode();

        using var verifikasi = pabrik.Services.CreateScope();
        var dbVerifikasi = verifikasi.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(1, await dbVerifikasi.Payments.CountAsync(p => p.OrderId == order.Id && p.Status == PaymentStatus.Berhasil));
        var tambahan = (await dbVerifikasi.Payments.FindAsync(lama.Id))!;
        Assert.Equal(PaymentStatus.JumlahTidakCocok, tambahan.Status);
        Assert.NotNull(tambahan.SettledAt);
        Assert.Equal(PaymentStatus.Berhasil, (await dbVerifikasi.Payments.FindAsync(utama.Id))!.Status);
    }

    public class MidtransApiFactory : DatabaseApiFactory
    {
        public const string ServerKey = ApiFactory.MidtransServerKey;
        public StatusMidtransTiruan Status { get; } = new();

        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            base.ConfigureWebHost(builder);
            builder.ConfigureTestServices(services =>
            {
                services.RemoveAll<IStatusPembayaranMidtrans>();
                services.AddSingleton<IStatusPembayaranMidtrans>(Status);
            });
        }
    }

    public sealed class StatusMidtransTiruan : IStatusPembayaranMidtrans
    {
        public ConcurrentDictionary<Guid, StatusTransaksiMidtrans> Transaksi { get; } = new();
        public int JumlahPermintaan { get; private set; }

        public Task<StatusTransaksiMidtrans> AmbilAsync(Guid paymentId, CancellationToken batal)
        {
            JumlahPermintaan++;
            return Transaksi.TryGetValue(paymentId, out var status)
                ? Task.FromResult(status)
                : throw new MidtransTidakTersediaException();
        }
    }
}
