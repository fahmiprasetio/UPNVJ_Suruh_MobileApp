using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Pricing;

namespace UpnvjSuruh.Api.Controllers;

/// <summary>
/// Transaksi pembayaran satu order.
///
/// Yang ada di sini cuma dua hal yang memang boleh dilakukan klien: minta dibuatkan
/// transaksi, dan menanyakan statusnya. Mengubah statusnya tidak ada, dan itu bukan
/// kelupaan. Uang yang masuk adalah kejadian di luar aplikasi, jadi yang boleh
/// mengabarkannya adalah pihak yang menerima uangnya, lewat webhook.
///
/// Nanti, ketika mitra memilih gateway, yang berubah adalah isi <see cref="Buat"/>: alih-alih
/// menyusun payload simulasi, ia memanggil gateway dengan Server Key dan menyimpan jawabannya.
/// Bentuk endpoint-nya tidak berubah, jadi aplikasi tidak perlu disentuh.
/// </summary>
[ApiController]
[Route("api/orders/{orderId:guid}/pembayaran")]
[Authorize(Roles = Peran.Klien)]
public class PembayaranController(AppDbContext db) : ControllerBase
{
    /// <summary>
    /// Membuat transaksi untuk order ini, atau mengembalikan yang masih menunggu.
    /// </summary>
    /// <remarks>
    /// Membuka ulang layar bayar tidak melahirkan QR baru. Dua QR untuk satu order berarti
    /// klien bisa membayar dua kali untuk pekerjaan yang sama, dan yang kedua harus
    /// dikembalikan.
    /// </remarks>
    [HttpPost]
    public async Task<ActionResult<TransaksiPembayaranResponse>> Buat(
        Guid orderId,
        CancellationToken batal)
    {
        var order = await Muat(orderId, batal);
        if (order is null) return NotFound();

        if (order.Status != OrderStatus.MenungguPembayaran)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Order ini tidak sedang menunggu pembayaran",
                Detail = $"Statusnya sekarang {order.Status}.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        if (order.Price is not { } harga || harga <= 0)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Order ini belum punya harga",
                Detail = "Jalur B baru bisa dibayar setelah penawaran admin disetujui.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        var adaYangMenunggu = Hidup(order);
        if (adaYangMenunggu is not null)
        {
            return Ok(TransaksiPembayaranResponse.Dari(adaYangMenunggu));
        }

        var sekarang = DateTime.UtcNow;
        var pembayaran = new Payment
        {
            OrderId = order.Id,
            // Diambil dari harga ordernya, tidak pernah dari badan permintaan.
            Amount = harga,
            GatewayReference = $"sim-{Guid.NewGuid():N}",
            QrPayload = PayloadSimulasi(order, harga),
            ExpiresAt = sekarang.Add(TarifConfig.BatasWaktuBayar),
        };

        db.Payments.Add(pembayaran);
        await db.SaveChangesAsync(batal);

        return Ok(TransaksiPembayaranResponse.Dari(pembayaran));
    }

    /// <summary>Status transaksi yang sedang berlaku untuk order ini.</summary>
    [HttpGet]
    public async Task<ActionResult<TransaksiPembayaranResponse>> Ambil(
        Guid orderId,
        CancellationToken batal)
    {
        var order = await Muat(orderId, batal);
        if (order is null) return NotFound();

        var pembayaran = Hidup(order)
                         ?? order.Payments.OrderByDescending(p => p.CreatedAt).FirstOrDefault();

        if (pembayaran is null) return NotFound();

        // Kalau yang tadinya menunggu ternyata sudah lewat batas waktunya, statusnya
        // diperbarui sekarang juga. Kedaluwarsa yang cuma dihitung saat ditanya akan membuat
        // dua penanya mendapat jawaban berbeda untuk transaksi yang sama.
        if (pembayaran.Menunggu && pembayaran.ExpiresAt <= DateTime.UtcNow)
        {
            pembayaran.Status = PaymentStatus.Kedaluwarsa;
            await db.SaveChangesAsync(batal);
        }

        return Ok(TransaksiPembayaranResponse.Dari(pembayaran));
    }

    /// <summary>Membatalkan transaksi yang masih menunggu.</summary>
    /// <remarks>
    /// Membatalkan transaksi bukan membatalkan order. Ordernya tetap menunggu pembayaran,
    /// dan klien bisa membuat transaksi baru. Yang mengakhiri order adalah endpoint batal
    /// ordernya sendiri.
    /// </remarks>
    [HttpPost("batal")]
    public async Task<IActionResult> Batalkan(Guid orderId, CancellationToken batal)
    {
        var order = await Muat(orderId, batal);
        if (order is null) return NotFound();

        var pembayaran = Hidup(order);
        if (pembayaran is null) return NotFound();

        pembayaran.Status = PaymentStatus.Gagal;
        await db.SaveChangesAsync(batal);

        return NoContent();
    }

    /// <summary>Order milik pemanggil, atau <c>null</c> kalau bukan.</summary>
    private async Task<Order?> Muat(Guid orderId, CancellationToken batal)
    {
        var order = await db.Orders
            .Include(o => o.Payments)
            .SingleOrDefaultAsync(o => o.Id == orderId, batal);

        // Order orang lain diperlakukan sebagai tidak ada, sama seperti di endpoint order.
        return order is null || order.ClientId != User.Id() ? null : order;
    }

    /// <summary>Transaksi yang masih menunggu dan belum lewat batas waktunya.</summary>
    private static Payment? Hidup(Order order) => order.Payments
        .SingleOrDefault(p => p.Menunggu && p.ExpiresAt > DateTime.UtcNow);

    /// <summary>
    /// Isi QR selama gateway sungguhan belum dipasang.
    ///
    /// Sengaja tidak menyerupai payload QRIS resmi. String yang mirip aslinya tapi palsu akan
    /// lolos pandangan sekilas dan menipu penguji; yang seperti ini gagal dipindai aplikasi
    /// bank, dan memang seharusnya begitu.
    /// </summary>
    private static string PayloadSimulasi(Order order, decimal jumlah) =>
        $"SIMULASI-QRIS|order={order.OrderCode}|jumlah={jumlah:0}";
}
