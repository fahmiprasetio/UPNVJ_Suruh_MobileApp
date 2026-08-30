using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Payments;

namespace UpnvjSuruh.Api.Controllers;

/// <summary>
/// Kabar dari gateway pembayaran.
///
/// Hanya lewat sinilah sebuah order bisa berubah jadi lunas. Klien tidak punya satu pun
/// endpoint untuk menyatakan dirinya sudah membayar, dan itu bukan kelupaan: uang yang masuk
/// adalah kejadian di luar aplikasi, jadi yang boleh mengabarkannya adalah pihak yang menerima
/// uangnya, bukan pihak yang mengirimkannya.
/// </summary>
[ApiController]
[Route("api/webhooks/pembayaran")]
[AllowAnonymous]
// Dikecualikan dari batas laju, termasuk dari jaring umum, dan itu keputusan yang disengaja.
//
// Kabar yang ditolak di sini adalah kabar bahwa uang sudah masuk. Gateway memang mengulang
// kiriman yang gagal, tapi mengandalkan pengulangan itu berarti menunda order yang sudah
// dibayar karena alasan yang tidak ada hubungannya dengan pembayarannya. Yang menjaga
// endpoint ini adalah rahasia bersama, dan permintaan tanpa rahasia yang benar sudah
// ditolak sebelum menyentuh basis data.
[DisableRateLimiting]
public class WebhookPembayaranController(
    IOptions<WebhookOptions> opsi,
    PenyelesaiPembayaran penyelesai,
    ILogger<WebhookPembayaranController> log) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Terima(WebhookPembayaranRequest permintaan, CancellationToken batal)
    {
        // Gateway bukan pengguna yang masuk, jadi ia membuktikan dirinya dengan rahasia
        // bersama, bukan token. Diperiksa paling awal, sebelum apa pun dibaca dari basis data.
        if (!opsi.Value.Cocok(Request.Headers[WebhookOptions.Header]))
        {
            log.LogWarning("Webhook pembayaran ditolak: rahasia tidak cocok.");
            return Unauthorized();
        }

        var hasil = await penyelesai.SelesaikanAsync(
            permintaan.OrderId,
            permintaan.ReferensiGateway,
            permintaan.Status,
            permintaan.Jumlah,
            batal);

        return hasil switch
        {
            HasilPenyelesaian.TidakDitemukan => NotFound(),

            // Jumlah yang tidak cocok tetap dijawab 200, dan itu bukan kelalaian.
            //
            // Gateway mengulang kiriman yang dijawab selain 2xx, jadi menjawab galat di sini
            // berarti kabar yang sama datang terus-menerus sampai kiriman ulangnya menyerah,
            // dan tidak satu pun pengulangan itu mengubah apa pun: jumlahnya akan tetap sama.
            // Yang dibutuhkan keadaan ini adalah orang yang memeriksanya, bukan gateway yang
            // mencoba lagi. Kabarnya sudah diterima dan tercatat, dan itulah yang dijawab.
            _ => Ok(),
        };
    }
}
