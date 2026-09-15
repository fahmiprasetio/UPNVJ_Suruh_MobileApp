using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Logging.Abstractions;
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
        NullLogger<MidtransPembayaranGateway>.Instance);

    [Fact]
    public async Task JawabanSuksesMenghasilkanQrStringDanReferensiDariPaymentId()
    {
        HttpRequestMessage? permintaanTertangkap = null;

        var gateway = Gateway(permintaan =>
        {
            permintaanTertangkap = permintaan;
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = JsonContent.Create(new { status_code = "201", qr_string = "00020101021226610014ID.CO.QRIS" }),
            };
        });

        var paymentId = Guid.NewGuid();
        var (referensi, qr) = await gateway.BuatTransaksiAsync(
            OrderUji(), paymentId, 15000m, CancellationToken.None);

        Assert.Equal(paymentId.ToString("N"), referensi);
        Assert.Equal("00020101021226610014ID.CO.QRIS", qr);

        Assert.NotNull(permintaanTertangkap);
        Assert.Equal("v2/charge", permintaanTertangkap!.RequestUri!.AbsolutePath.TrimStart('/'));
        var badan = JsonSerializer.Deserialize<JsonElement>(
            await permintaanTertangkap.Content!.ReadAsStringAsync());
        Assert.Equal("qris", badan.GetProperty("payment_type").GetString());
        Assert.Equal(
            paymentId.ToString("N"),
            badan.GetProperty("transaction_details").GetProperty("order_id").GetString());
        Assert.Equal(15000, badan.GetProperty("transaction_details").GetProperty("gross_amount").GetInt64());
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
    public async Task JawabanSuksesTanpaQrStringTetapDianggapGagal()
    {
        // Status 200 tapi tanpa qr_string sama sekali tidak berguna -- QRIS tidak bisa
        // digambar dari apa pun kalau ini lolos begitu saja.
        var gateway = Gateway(_ => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = JsonContent.Create(new { status_code = "201" }),
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
