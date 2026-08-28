using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Hubs;

namespace UpnvjSuruh.Api.Controllers;

/// <summary>
/// Kabar dari gateway pembayaran.
///
/// Hanya di sinilah sebuah order bisa berubah jadi lunas. Klien tidak punya satu pun endpoint
/// untuk menyatakan dirinya sudah membayar, dan itu bukan kelupaan: uang yang masuk adalah
/// kejadian di luar aplikasi, jadi yang boleh mengabarkannya adalah pihak yang menerima
/// uangnya, bukan pihak yang mengirimkannya.
/// </summary>
[ApiController]
[Route("api/webhooks/pembayaran")]
[AllowAnonymous]
public class WebhookPembayaranController(
    AppDbContext db,
    IOptions<WebhookOptions> opsi,
    IHubContext<OrderHub> hub,
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

        var order = await db.Orders
            .Include(o => o.Payment)
            .SingleOrDefaultAsync(o => o.Id == permintaan.OrderId, batal);

        if (order is null) return NotFound();

        var pembayaran = order.Payment;
        if (pembayaran is null)
        {
            pembayaran = new Payment
            {
                OrderId = order.Id,
                Amount = permintaan.Jumlah,
                GatewayReference = permintaan.ReferensiGateway,
            };
            db.Payments.Add(pembayaran);
        }

        // Status akhir tidak bisa dianulir. Gateway boleh mengirim kabar yang sama berkali-kali,
        // dan memang begitu perilakunya kalau jawaban kita telat sampai, jadi permintaan kedua
        // untuk order yang sudah lunas harus berakhir sama dengan yang pertama, bukan menambah
        // pembayaran kedua atau menyiarkan ulang ordernya.
        if (pembayaran.Status != PaymentStatus.Pending)
        {
            return Ok();
        }

        pembayaran.Status = permintaan.Status;
        pembayaran.GatewayReference = permintaan.ReferensiGateway;

        if (permintaan.Status != PaymentStatus.Berhasil)
        {
            await db.SaveChangesAsync(batal);
            return Ok();
        }

        if (order.Status != OrderStatus.MenungguPembayaran)
        {
            // Uang masuk untuk order yang sudah tidak menunggu bayaran. Bukan galat gateway,
            // tapi harus terlihat orang, karena kemungkinan besar ada uang yang perlu
            // dikembalikan.
            log.LogWarning(
                "Pembayaran berhasil untuk order {OrderId} yang berstatus {Status}.",
                order.Id, order.Status);
            await db.SaveChangesAsync(batal);
            return Ok();
        }

        pembayaran.SettledAt = DateTime.UtcNow;
        order.PaidAt = DateTime.UtcNow;
        order.Status = OrderStatus.MencariRunner;

        await db.SaveChangesAsync(batal);

        // Baru sekarang ordernya disiarkan, dan hanya ke grup runner. Yang dikirim sengaja
        // cuma secukupnya untuk memutuskan mau ambil atau tidak. Alamat lengkap menyusul
        // lewat endpoint order, yang memeriksa siapa penanyanya.
        await hub.Clients.Group(OrderHub.RunnersGroup).SendAsync(
            "OrderBroadcast",
            new
            {
                OrderId = order.Id,
                ServiceType = order.ServiceType.ToString(),
                Harga = order.Price,
                JumlahRunnerDibutuhkan = order.RequiredRunnerCount,
            },
            batal);

        return Ok();
    }
}
