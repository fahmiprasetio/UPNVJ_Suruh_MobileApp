using System.Net.Http.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Payments;

/// <summary>
/// Membuat checkout Midtrans Snap lewat endpoint <c>/snap/v1/transactions</c>.
///
/// Snap sengaja dipakai sebagai jalur Midtrans utama: halaman pembayaran, pilihan channel,
/// dan kartu Sandbox ditampilkan oleh Midtrans sendiri. QRIS Core API lama tidak dihapus;
/// implementasi QRIS dapat dipasang lagi sebagai gateway lain bila merchant sudah mendapat
/// akses channel tersebut.
///
/// <c>HttpClient</c>-nya (Authorization Basic dengan Server Key, BaseAddress Sandbox/Production)
/// dipasang sekali di <c>Program.cs</c>. <see cref="MidtransOptions"/> cuma disentuh untuk satu
/// hal: <see cref="MidtransOptions.NotificationUrl"/>, lihat <see cref="XOverrideNotification"/>.
/// </summary>
public class MidtransPembayaranGateway(
    HttpClient http, IOptions<MidtransOptions> opsi, ILogger<MidtransPembayaranGateway> log)
    : IPembayaranGateway
{
    /// <summary>
    /// Header Midtrans yang menimpa alamat webhook dari pengaturan dashboard, khusus
    /// transaksi ini saja.
    ///
    /// Server Key Sandbox terikat ke SATU akun merchant, bukan satu proyek -- akun Sandbox
    /// yang sama sudah dipakai proyek lain milik pemilik produk sebelum ini, dan dashboard
    /// Midtrans cuma punya satu alamat webhook bawaan untuk seluruh akun itu. Tanpa header
    /// ini, notifikasi transaksi proyek ini akan mendarat di alamat webhook proyek lain itu
    /// (atau sebaliknya), tergantung mana yang kebetulan tersimpan di dashboard duluan.
    /// Didokumentasikan Midtrans di https://docs.midtrans.com/reference/override-notification-url.
    /// </summary>
    private const string XOverrideNotification = "X-Override-Notification";

    public async Task<HasilPembuatanPembayaran> BuatTransaksiAsync(
        Order order,
        Guid paymentId,
        decimal jumlah,
        CancellationToken batal)
    {
        // Id baris Payment sendiri, bukan Order.Id: satu order boleh punya beberapa transaksi
        // berurutan (tagihan yang kedaluwarsa lalu diterbitkan ulang, lihat 5.14 rencana
        // capstone), dan Midtrans menolak order_id yang dipakai ulang untuk transaksi baru.
        var orderIdMidtrans = paymentId.ToString("N");

        using var permintaan = new HttpRequestMessage(HttpMethod.Post, "snap/v1/transactions")
        {
            Content = JsonContent.Create(new
            {
                transaction_details = new
                {
                    order_id = orderIdMidtrans,
                    gross_amount = (long)jumlah,
                },
                // Samakan masa checkout Snap dengan aturan transaksi aplikasi. Tanpa start_time
                // masa berlaku metode asynchronous baru mulai ketika pelanggan memilih channel.
                expiry = new
                {
                    start_time = DateTimeOffset.UtcNow.ToOffset(TimeSpan.FromHours(7))
                        .ToString("yyyy-MM-dd HH:mm:ss +0700"),
                    unit = "minute",
                    duration = 30,
                },
                page_expiry = new { unit = "minute", duration = 30 },
            }),
        };
        permintaan.Headers.Add(XOverrideNotification, opsi.Value.NotificationUrl);

        var jawaban = await http.SendAsync(permintaan, batal);

        var isi = await jawaban.Content.ReadFromJsonAsync<MidtransSnapResponse>(
            cancellationToken: batal);

        if (!jawaban.IsSuccessStatusCode || string.IsNullOrWhiteSpace(isi?.Token) ||
            !SnapUrlSah(isi.RedirectUrl))
        {
            // Tidak meneruskan isi jawaban Midtrans ke pemanggil: itu bisa memuat detail
            // internal yang tidak seharusnya sampai ke klien (lihat pola yang sama di
            // PengirimOtpWhatsapp.Samarkan). Dicatat ke log server, bukan dibocorkan lewat
            // pengecualian yang isinya ikut lolos ke ProblemDetails.
            log.LogError(
            "Midtrans Snap menolak transaksi order {OrderCode}: {StatusCode}",
            order.OrderCode, (int)jawaban.StatusCode);
            throw new InvalidOperationException(
                "Gateway pembayaran sedang bermasalah, coba lagi sebentar lagi.");
        }

        return new HasilPembuatanPembayaran(orderIdMidtrans, string.Empty, isi.RedirectUrl!);
    }

    private static bool SnapUrlSah(string? nilai) =>
        Uri.TryCreate(nilai, UriKind.Absolute, out var uri) &&
        uri.Scheme == Uri.UriSchemeHttps &&
        (uri.Host.Equals("app.sandbox.midtrans.com", StringComparison.OrdinalIgnoreCase) ||
         uri.Host.Equals("app.midtrans.com", StringComparison.OrdinalIgnoreCase));
}

/// <summary>Cuma bidang yang benar-benar dipakai; Midtrans mengirim jauh lebih banyak.</summary>
file sealed record MidtransSnapResponse(
    [property: JsonPropertyName("token")] string? Token,
    [property: JsonPropertyName("redirect_url")] string? RedirectUrl);
