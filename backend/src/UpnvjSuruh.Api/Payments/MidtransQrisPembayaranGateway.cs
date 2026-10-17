using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Payments;

/// <summary>
/// Jalur QRIS Midtrans Core API yang tetap dipertahankan sebagai fallback.
///
/// Snap adalah pilihan utama karena akun Sandbox ini belum diberi akses QRIS Core.
/// Kelas ini tidak dibuang: jika akses QRIS tersedia, pilih <c>Midtrans:Mode=CoreQris</c>
/// tanpa mengubah mobile maupun kontrak pembayaran.
/// </summary>
public sealed class MidtransQrisPembayaranGateway(
    HttpClient http, IOptions<MidtransOptions> opsi, ILogger<MidtransQrisPembayaranGateway> log)
    : IPembayaranGateway
{
    private const string XOverrideNotification = "X-Override-Notification";

    public async Task<HasilPembuatanPembayaran> BuatTransaksiAsync(
        Order order,
        Guid paymentId,
        decimal jumlah,
        CancellationToken batal)
    {
        var orderIdMidtrans = paymentId.ToString("N");
        using var permintaan = new HttpRequestMessage(HttpMethod.Post, "v2/charge")
        {
            Content = JsonContent.Create(new
            {
                payment_type = "qris",
                transaction_details = new
                {
                    order_id = orderIdMidtrans,
                    gross_amount = (long)jumlah,
                },
            }),
        };
        permintaan.Headers.Add(XOverrideNotification, opsi.Value.NotificationUrl);

        var jawaban = await http.SendAsync(permintaan, batal);
        var isi = await jawaban.Content.ReadFromJsonAsync<MidtransQrisResponse>(
            cancellationToken: batal);

        if (!jawaban.IsSuccessStatusCode || string.IsNullOrWhiteSpace(isi?.QrString))
        {
            log.LogError(
                "Midtrans QRIS menolak transaksi order {OrderCode}: {StatusCode} {StatusCodeMidtrans}",
                order.OrderCode, (int)jawaban.StatusCode, isi?.StatusCode);
            throw new InvalidOperationException(
                "Gateway pembayaran sedang bermasalah, coba lagi sebentar lagi.");
        }

        return new HasilPembuatanPembayaran(orderIdMidtrans, isi.QrString, null);
    }
}

file sealed record MidtransQrisResponse(
    [property: JsonPropertyName("status_code")] string? StatusCode,
    [property: JsonPropertyName("qr_string")] string? QrString);
