using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.Logging.Abstractions;
using UpnvjSuruh.Api.Payments;

namespace UpnvjSuruh.Api.Tests;

public class StatusPembayaranMidtransTests
{
    private static StatusPembayaranMidtrans Klien(Func<HttpRequestMessage, HttpResponseMessage> jawab) => new(
        new HttpClient(new Handler(jawab)) { BaseAddress = new Uri("https://api.sandbox.midtrans.com/") },
        NullLogger<StatusPembayaranMidtrans>.Instance);

    [Fact]
    public async Task StatusDiambilUntukPaymentIdDenganMetodeGet()
    {
        var id = Guid.NewGuid();
        var klien = Klien(permintaan =>
        {
            Assert.Equal(HttpMethod.Get, permintaan.Method);
            Assert.Equal($"/v2/{id:N}/status", permintaan.RequestUri!.AbsolutePath);
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = JsonContent.Create(new
                {
                    order_id = id.ToString("N"), status_code = "200", gross_amount = "15000.00",
                    transaction_status = "capture", fraud_status = "accept", tambahan = "boleh diabaikan",
                }),
            };
        });

        var status = await klien.AmbilAsync(id, CancellationToken.None);
        Assert.Equal("capture", status.TransactionStatus);
        Assert.Equal("accept", status.FraudStatus);
        Assert.Equal("15000.00", status.GrossAmount);
    }

    [Theory]
    [InlineData(HttpStatusCode.Unauthorized)]
    [InlineData(HttpStatusCode.NotFound)]
    [InlineData(HttpStatusCode.ServiceUnavailable)]
    [InlineData(HttpStatusCode.Redirect)]
    public async Task ResponsGagalTidakMembocorkanIsinya(HttpStatusCode kode)
    {
        var klien = Klien(_ => new HttpResponseMessage(kode)
        {
            Content = new StringContent("informasi internal provider"),
        });

        var galat = await Assert.ThrowsAsync<MidtransTidakTersediaException>(() =>
            klien.AmbilAsync(Guid.NewGuid(), CancellationToken.None));
        Assert.DoesNotContain("informasi internal", galat.Message);
    }

    [Theory]
    [InlineData("<html>galat upstream</html>")]
    [InlineData("null")]
    [InlineData("{}")]
    public async Task ResponsRusakTidakBolehDianggapTerverifikasi(string badan)
    {
        var klien = Klien(_ => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = new StringContent(badan, System.Text.Encoding.UTF8, "application/json"),
        });

        await Assert.ThrowsAsync<MidtransTidakTersediaException>(() =>
            klien.AmbilAsync(Guid.NewGuid(), CancellationToken.None));
    }

    [Fact]
    public async Task ResponsUntukTransaksiLainDitolak()
    {
        var klien = Klien(_ => new HttpResponseMessage(HttpStatusCode.OK)
        {
            Content = JsonContent.Create(new
            {
                order_id = Guid.NewGuid().ToString("N"), status_code = "200", gross_amount = "15000.00",
                transaction_status = "settlement",
            }),
        });

        await Assert.ThrowsAsync<MidtransTidakTersediaException>(() =>
            klien.AmbilAsync(Guid.NewGuid(), CancellationToken.None));
    }

    [Fact]
    public async Task TimeoutDiterjemahkanMenjadiGalatAman()
    {
        var klien = Klien(_ => throw new TaskCanceledException("detail jaringan internal"));
        var galat = await Assert.ThrowsAsync<MidtransTidakTersediaException>(() =>
            klien.AmbilAsync(Guid.NewGuid(), CancellationToken.None));
        Assert.DoesNotContain("detail jaringan", galat.Message);
    }

    [Fact]
    public async Task PembatalanOlehPemanggilTetapDiteruskan()
    {
        using var batal = new CancellationTokenSource();
        batal.Cancel();
        var klien = Klien(_ => throw new TaskCanceledException());
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => klien.AmbilAsync(Guid.NewGuid(), batal.Token));
    }

    private sealed class Handler(Func<HttpRequestMessage, HttpResponseMessage> jawab) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) =>
            Task.FromResult(jawab(request));
    }
}
