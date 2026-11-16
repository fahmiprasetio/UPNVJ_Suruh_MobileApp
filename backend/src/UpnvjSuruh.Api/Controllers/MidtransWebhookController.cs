using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Payments;

namespace UpnvjSuruh.Api.Controllers;

/// <summary>
/// Kabar HTTP sungguhan dari Midtrans, terpisah dari <see cref="WebhookPembayaranController"/>
/// yang formatnya tiruan sendiri (dipakai tes dan tiruan gateway lokal).
///
/// Midtrans tidak mendukung header rahasia bersama kustom seperti
/// <see cref="Auth.WebhookOptions"/> -- ia cuma mengirim <c>signature_key</c> di dalam badan
/// JSON-nya sendiri, jadi endpoint ini memeriksa <see cref="MidtransOptions.SignatureValid"/>
/// lalu mengambil status terkini langsung dari Midtrans. Keduanya sama-sama berakhir memanggil
/// <see cref="PenyelesaiPembayaran"/> yang sama, satu-satunya tempat order berubah lunas.
/// </summary>
[ApiController]
[Route("api/webhooks/midtrans")]
[AllowAnonymous]
// Alasannya sama dengan WebhookPembayaranController: kabar bahwa uang sudah masuk tidak boleh
// tertunda oleh batas laju yang tidak ada hubungannya dengan pembayaran, dan penjaga sungguhan
// di sini adalah tanda tangannya, bukan jaring umum.
[DisableRateLimiting]
public class MidtransWebhookController(
    IOptions<MidtransOptions> opsi,
    IStatusPembayaranMidtrans statusMidtrans,
    PenyelesaiPembayaran penyelesai,
    AppDbContext db,
    ILogger<MidtransWebhookController> log) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Terima(MidtransNotifikasiRequest notifikasi, CancellationToken batal)
    {
        if (notifikasi.OrderId is null || notifikasi.StatusCode is null || notifikasi.GrossAmount is null)
        {
            return BadRequest();
        }

        // Diperiksa paling awal, sebelum satu baris pun basis data tersentuh -- pola yang
        // sama dengan WebhookPembayaranController.
        if (!opsi.Value.SignatureValid(
                notifikasi.OrderId, notifikasi.StatusCode, notifikasi.GrossAmount, notifikasi.SignatureKey))
        {
            log.LogWarning("Webhook Midtrans ditolak: tanda tangan tidak cocok.");
            return Unauthorized();
        }

        // order_id yang dikirim balik Midtrans adalah Payment.Id ("N", lihat
        // MidtransPembayaranGateway), bukan Order.Id -- perlu satu pencarian tambahan untuk
        // sampai ke order yang dituju PenyelesaiPembayaran.
        if (!Guid.TryParseExact(notifikasi.OrderId, "N", out var paymentId))
        {
            return NotFound();
        }

        var orderId = await db.Payments
            .Where(p => p.Id == paymentId)
            .Select(p => (Guid?)p.OrderId)
            .SingleOrDefaultAsync(batal);

        if (orderId is null) return NotFound();

        // transaction_status dan fraud_status tidak tercakup signature Midtrans.
        // Ambil keadaan sebenarnya langsung dari Midtrans, bukan dari badan webhook.
        StatusTransaksiMidtrans terverifikasi;
        try
        {
            if (!opsi.Value.ServerKeySesuaiLingkungan()) throw new MidtransTidakTersediaException();
            terverifikasi = await statusMidtrans.AmbilAsync(paymentId, batal);
        }
        catch (MidtransTidakTersediaException)
        {
            // Jangan mengakui penerimaan sebagai sukses ketika verifikasi belum tersedia.
            // Midtrans dapat mengirim ulang, tanpa mengubah status pembayaran lokal.
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new ProblemDetails
            {
                Title = "Status pembayaran belum dapat diverifikasi",
                Status = StatusCodes.Status503ServiceUnavailable,
            });
        }

        if (terverifikasi.OrderId != notifikasi.OrderId)
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable);
        }

        var status = StatusDari(terverifikasi);
        if (status is null)
        {
            // "pending": QR baru diterbitkan, belum ada yang perlu dicatat -- Payment sudah
            // lahir berstatus Pending sejak dibuat. Diterima tanpa mengubah apa pun supaya
            // Midtrans tidak mengulang kirimannya karena mengira gagal.
            return Ok();
        }

        if (!decimal.TryParse(
                terverifikasi.GrossAmount,
                System.Globalization.NumberStyles.AllowDecimalPoint,
                System.Globalization.CultureInfo.InvariantCulture,
                out var jumlah) || jumlah <= 0)
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable);
        }

        var hasil = await penyelesai.SelesaikanAsync(
            orderId.Value, notifikasi.OrderId, status.Value, jumlah, batal, terverifikasiMidtrans: true);

        return hasil switch
        {
            HasilPenyelesaian.TidakDitemukan => NotFound(),
            _ => Ok(),
        };
    }

    private static PaymentStatus? StatusDari(StatusTransaksiMidtrans transaksi) => transaksi.TransactionStatus switch
    {
        "settlement" when transaksi.StatusCode == "200" &&
            (transaksi.FraudStatus is null || transaksi.FraudStatus == "accept") => PaymentStatus.Berhasil,
        "capture" when transaksi.StatusCode == "200" && transaksi.FraudStatus == "accept" => PaymentStatus.Berhasil,
        "expire" => PaymentStatus.Kedaluwarsa,
        "deny" or "cancel" or "failure" => PaymentStatus.Gagal,
        _ => null,
    };
}
