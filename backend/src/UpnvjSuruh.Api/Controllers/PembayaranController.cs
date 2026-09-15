using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Payments;
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
/// <see cref="Buat"/> tidak pernah tahu gateway mana yang sedang aktif -- itu keputusan
/// <see cref="IPembayaranGateway"/> yang dipilih <c>Program.cs</c> dari ada-tidaknya
/// <c>Midtrans:ServerKey</c>. Bentuk endpoint ini tidak berubah waktu gateway sungguhan
/// dipasang, persis seperti yang dijanjikan komentar lama di sini.
/// </summary>
[ApiController]
[Route("api/orders/{orderId:guid}/pembayaran")]
[Authorize(Roles = Peran.Klien)]
public class PembayaranController(AppDbContext db, IPembayaranGateway gateway) : ControllerBase
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
        var paymentId = Guid.NewGuid();

        // Baris ini disimpan SEBELUM gateway dipanggil, bukan sesudah. Kalau urutannya
        // dibalik dan panggilan ke gateway berhasil (QR sungguhan sudah bisa dipindai dan
        // dibayar orang) tapi penyimpanan ke sini gagal sesudahnya -- koneksi basis data
        // putus, permintaan dibatalkan klien, proses server berhenti di tengah -- webhook
        // yang datang belakangan tidak punya apa pun untuk dicocokkan lewat paymentId, dan
        // uang yang sudah dibayar orang jadi transaksi yatim yang tidak tercatat ke order
        // mana pun. Menyimpannya lebih dulu berarti baris ini sudah ada sebelum uang
        // sempat berpindah sama sekali.
        var pembayaran = new Payment
        {
            Id = paymentId,
            OrderId = order.Id,
            // Diambil dari harga ordernya, tidak pernah dari badan permintaan.
            Amount = harga,
            GatewayReference = $"{paymentId:N}",
            // Dibaca dari jam yang sama dengan ExpiresAt, bukan dibiarkan memakai
            // nilai bawaan entitasnya. Dua pembacaan jam membuat jarak antara dibuat
            // dan kedaluwarsa meleset dari BatasWaktuBayar, dan yang membaca selisihnya
            // nanti akan menyimpulkan batas waktunya bukan angka yang tertulis di sini.
            CreatedAt = sekarang,
            QrPayload = string.Empty,
            ExpiresAt = sekarang.Add(TarifConfig.BatasWaktuBayar),
        };

        db.Payments.Add(pembayaran);
        await db.SaveChangesAsync(batal);

        try
        {
            var (referensiGateway, qrPayload) = await gateway.BuatTransaksiAsync(
                order, paymentId, harga, batal);
            pembayaran.GatewayReference = referensiGateway;
            pembayaran.QrPayload = qrPayload;
        }
        catch
        {
            // Barisnya tetap ada (lihat alasan di atas), tapi ditandai gagal supaya
            // percobaan berikutnya tidak macet menunggu QR yang tidak pernah lahir sampai
            // batas waktunya lewat sendiri -- Hidup() di bawah cuma melihat transaksi yang
            // masih Pending.
            pembayaran.Status = PaymentStatus.Gagal;
            await db.SaveChangesAsync(batal);
            throw;
        }

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
}
