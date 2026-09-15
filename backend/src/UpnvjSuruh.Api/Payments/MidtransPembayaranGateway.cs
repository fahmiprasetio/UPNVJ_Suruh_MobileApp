using System.Net.Http.Json;
using System.Text.Json.Serialization;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Payments;

/// <summary>
/// Membuat transaksi QRIS sungguhan lewat Midtrans Core API (<c>/v2/charge</c>).
///
/// Bukan Snap: Snap membuka halaman pembayaran hostingan Midtrans, sedangkan aplikasi ini
/// sudah menggambar kode QR-nya sendiri (lihat <c>pembayaran_screen.dart</c>). Core API
/// menjawab <c>qr_string</c> mentah yang bisa langsung dipakai di situ, jadi tidak ada yang
/// berubah di sisi mobile -- cuma isi <c>QrPayload</c>-nya yang tadinya karangan sendiri,
/// sekarang QRIS asli.
///
/// <c>HttpClient</c>-nya (Authorization Basic dengan Server Key, BaseAddress Sandbox/Production)
/// dipasang sekali di <c>Program.cs</c>, bukan di sini -- kelas ini tidak pernah menyentuh
/// <see cref="MidtransOptions"/> secara langsung.
/// </summary>
public class MidtransPembayaranGateway(HttpClient http, ILogger<MidtransPembayaranGateway> log)
    : IPembayaranGateway
{
    public async Task<(string ReferensiGateway, string QrPayload)> BuatTransaksiAsync(
        Order order,
        Guid paymentId,
        decimal jumlah,
        CancellationToken batal)
    {
        // Id baris Payment sendiri, bukan Order.Id: satu order boleh punya beberapa transaksi
        // berurutan (tagihan yang kedaluwarsa lalu diterbitkan ulang, lihat 5.14 rencana
        // capstone), dan Midtrans menolak order_id yang dipakai ulang untuk transaksi baru.
        var orderIdMidtrans = paymentId.ToString("N");

        var jawaban = await http.PostAsJsonAsync(
            "v2/charge",
            new
            {
                payment_type = "qris",
                transaction_details = new
                {
                    order_id = orderIdMidtrans,
                    // QRIS tidak mengenal pecahan rupiah.
                    gross_amount = (long)jumlah,
                },
            },
            batal);

        var isi = await jawaban.Content.ReadFromJsonAsync<MidtransChargeResponse>(
            cancellationToken: batal);

        if (!jawaban.IsSuccessStatusCode || string.IsNullOrWhiteSpace(isi?.QrString))
        {
            // Tidak meneruskan isi jawaban Midtrans ke pemanggil: itu bisa memuat detail
            // internal yang tidak seharusnya sampai ke klien (lihat pola yang sama di
            // PengirimOtpWhatsapp.Samarkan). Dicatat ke log server, bukan dibocorkan lewat
            // pengecualian yang isinya ikut lolos ke ProblemDetails.
            log.LogError(
                "Midtrans menolak transaksi order {OrderCode}: {StatusCode} {StatusCodeMidtrans}",
                order.OrderCode, (int)jawaban.StatusCode, isi?.StatusCode);
            throw new InvalidOperationException(
                "Gateway pembayaran sedang bermasalah, coba lagi sebentar lagi.");
        }

        return (orderIdMidtrans, isi.QrString);
    }
}

/// <summary>Cuma bidang yang benar-benar dipakai; Midtrans mengirim jauh lebih banyak.</summary>
file sealed record MidtransChargeResponse(
    [property: JsonPropertyName("status_code")] string? StatusCode,
    [property: JsonPropertyName("qr_string")] string? QrString);
