using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace UpnvjSuruh.Api.Payments;

public interface IStatusPembayaranMidtrans
{
    Task<StatusTransaksiMidtrans> AmbilAsync(Guid paymentId, CancellationToken batal);
}

/// <summary>Status dipercaya hanya dari respons HTTPS backend-ke-backend Midtrans.</summary>
public sealed class StatusPembayaranMidtrans(
    HttpClient http, ILogger<StatusPembayaranMidtrans> log) : IStatusPembayaranMidtrans
{
    public async Task<StatusTransaksiMidtrans> AmbilAsync(Guid paymentId, CancellationToken batal)
    {
        try
        {
            using var jawaban = await http.GetAsync($"v2/{paymentId:N}/status", batal);
            if (!jawaban.IsSuccessStatusCode)
            {
                log.LogWarning("Verifikasi status Midtrans ditolak: HTTP {StatusCode}.", (int)jawaban.StatusCode);
                throw new MidtransTidakTersediaException();
            }

            var isi = await jawaban.Content.ReadFromJsonAsync<StatusTransaksiMidtrans>(batal);
            if (isi is null || isi.OrderId != paymentId.ToString("N") ||
                string.IsNullOrWhiteSpace(isi.StatusCode) || string.IsNullOrWhiteSpace(isi.GrossAmount) ||
                string.IsNullOrWhiteSpace(isi.TransactionStatus))
            {
                throw new MidtransTidakTersediaException();
            }

            return isi;
        }
        catch (Exception galat) when (galat is HttpRequestException or JsonException or NotSupportedException ||
            galat is OperationCanceledException && !batal.IsCancellationRequested)
        {
            // Jangan sertakan isi respons, kredensial, atau exception provider ke pemanggil.
            log.LogWarning("Verifikasi status Midtrans belum tersedia.");
            throw new MidtransTidakTersediaException();
        }
    }
}

public sealed record StatusTransaksiMidtrans(
    [property: JsonPropertyName("order_id")] string? OrderId,
    [property: JsonPropertyName("status_code")] string? StatusCode,
    [property: JsonPropertyName("gross_amount")] string? GrossAmount,
    [property: JsonPropertyName("transaction_status")] string? TransactionStatus,
    [property: JsonPropertyName("fraud_status")] string? FraudStatus);

public sealed class MidtransTidakTersediaException() : Exception(
    "Layanan pembayaran belum tersedia. Coba lagi sebentar lagi.");
