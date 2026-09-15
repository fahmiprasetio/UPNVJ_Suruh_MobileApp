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
/// JSON-nya sendiri, jadi endpoint ini butuh cara verifikasi sendiri
/// (<see cref="MidtransOptions.SignatureValid"/>), bukan memakai kembali punya
/// <see cref="WebhookPembayaranController"/>. Keduanya sama-sama berakhir memanggil
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

        var status = StatusDari(notifikasi.TransactionStatus);
        if (status is null)
        {
            // "pending": QR baru diterbitkan, belum ada yang perlu dicatat -- Payment sudah
            // lahir berstatus Pending sejak dibuat. Diterima tanpa mengubah apa pun supaya
            // Midtrans tidak mengulang kirimannya karena mengira gagal.
            return Ok();
        }

        if (!decimal.TryParse(
                notifikasi.GrossAmount,
                System.Globalization.NumberStyles.Number,
                System.Globalization.CultureInfo.InvariantCulture,
                out var jumlah))
        {
            return BadRequest();
        }

        var hasil = await penyelesai.SelesaikanAsync(orderId.Value, notifikasi.OrderId, status.Value, jumlah, batal);

        return hasil switch
        {
            HasilPenyelesaian.TidakDitemukan => NotFound(),
            _ => Ok(),
        };
    }

    private static PaymentStatus? StatusDari(string? transactionStatus) => transactionStatus switch
    {
        // QRIS tidak pernah lewat "capture" (itu khusus kartu kredit dua tahap); disertakan
        // saja untuk berjaga-jaga kalau metode lain menyusul lewat gateway yang sama nanti.
        "settlement" or "capture" => PaymentStatus.Berhasil,
        "expire" => PaymentStatus.Kedaluwarsa,
        "deny" or "cancel" or "failure" => PaymentStatus.Gagal,
        _ => null,
    };
}
