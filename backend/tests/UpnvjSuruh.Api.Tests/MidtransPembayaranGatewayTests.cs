using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Payments;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Satu-satunya jalur yang bisa menyusun tagihan sungguhan sejak Midtrans dipasang. Diuji
/// lewat <see cref="HttpMessageHandler"/> tiruan, bukan jaringan sungguhan: sandbox Midtrans
/// yang sedang bermasalah tidak boleh membuat CI ikut merah.
/// </summary>
public class MidtransPembayaranGatewayTests
{
    private const string NotificationUrlUji = "https://uji.contoh/api/webhooks/midtrans";

    private static Order OrderUji() => new()
    {
        ClientId = Guid.NewGuid(),
        ServiceType = ServiceType.AnterJemput,
        OrderCode = "SRH-0001",
        Status = OrderStatus.MenungguPembayaran,
    };

    private static MidtransPembayaranGateway Gateway(
        Func<HttpRequestMessage, HttpResponseMessage> jawab) => new(
        new HttpClient(new HandlerTiruan(jawab)) { BaseAddress = new Uri("https://api.sandbox.midtrans.com/") },
        Options.Create(new MidtransOptions { NotificationUrl = NotificationUrlUji }),
        NullLogger<MidtransPembayaranGateway>.Instance);

    [Fact]
    public async Task JawabanSuksesMenghasilkanCheckoutSnapDanReferensiDariPaymentId()
    {
        string? jalur = null;
        JsonElement badan = default;
        IEnumerable<string>? headerOverride = null;

        var gateway = Gateway(permintaan =>
        {
            // Dibaca sinkron di sini, selagi permintaannya masih hidup -- BuatTransaksiAsync
            // membuang HttpRequestMessage-nya (`using`) begitu selesai, jadi menyimpan
            // referensinya untuk dibaca sesudah await di bawah akan mengenai objek yang
            // sudah dibuang.
            jalur = permintaan.RequestUri!.AbsolutePath.TrimStart('/');
            badan = JsonSerializer.Deserialize<JsonElement>(
                permintaan.Content!.ReadAsStringAsync().GetAwaiter().GetResult());
            permintaan.Headers.TryGetValues("X-Override-Notification", out headerOverride);

            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = JsonContent.Create(new
                {
                    token = "token-snap-uji",
                    redirect_url = "https://app.sandbox.midtrans.com/snap/v2/vtweb/token-snap-uji",
                }),
            };
        });

        var paymentId = Guid.NewGuid();
        var (referensi, checkoutUrl) = await gateway.BuatTransaksiAsync(
            OrderUji(), paymentId, 15000m, CancellationToken.None);

        Assert.Equal(paymentId.ToString("N"), referensi);
        Assert.Equal(
            "https://app.sandbox.midtrans.com/snap/v2/vtweb/token-snap-uji",
            checkoutUrl);

        Assert.Equal("snap/v1/transactions", jalur);
        Assert.Equal(
            paymentId.ToString("N"),
            badan.GetProperty("transaction_details").GetProperty("order_id").GetString());
        Assert.Equal(15000, badan.GetProperty("transaction_details").GetProperty("gross_amount").GetInt64());

        Assert.NotNull(headerOverride);
        Assert.Equal(NotificationUrlUji, Assert.Single(headerOverride!));
    }

    [Fact]
    public async Task JawabanGagalMelemparGalatYangTidakMembocorkanIsiJawabanMidtrans()
    {
        var gateway = Gateway(_ => new HttpResponseMessage(HttpStatusCode.BadRequest)
        {
            Content = JsonContent.Create(new
            {
                status_code = "402",
                status_message = "Rahasia internal Midtrans yang tidak boleh sampai ke klien",
            }),
        });

        var galat = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            gateway.BuatTransaksiAsync(OrderUji(), Guid.NewGuid(), 15000m, CancellationToken.None));

        Assert.DoesNotContain("Rahasia internal Midtrans", galat.Message, StringComparison.Ordinal);
    }

    [Fact]
    public async Task JawabanSuksesTanpaCheckoutSnapTetapDianggapGagal()
    {
        // Token tanpa redirect_url tidak dapat dibuka oleh aplikasi, sehingga respons
        // tersebut belum merupakan checkout Snap yang dapat dipakai pengguna.
        var gateway = Gateway(_ => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = JsonContent.Create(new { token = "token-snap-uji" }),
        });

        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            gateway.BuatTransaksiAsync(OrderUji(), Guid.NewGuid(), 15000m, CancellationToken.None));
    }

    private sealed class HandlerTiruan(Func<HttpRequestMessage, HttpResponseMessage> jawab)
        : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage permintaan, CancellationToken batal) =>
            Task.FromResult(jawab(permintaan));
    }
}
