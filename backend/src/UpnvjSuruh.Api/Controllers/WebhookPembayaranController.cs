using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
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

        return hasil == HasilPenyelesaian.TidakDitemukan ? NotFound() : Ok();
    }
}
