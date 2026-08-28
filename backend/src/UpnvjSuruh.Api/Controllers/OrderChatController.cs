using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Controllers;

/// <summary>
/// Ruang chat sebuah order.
///
/// Jalurnya menempel pada ordernya, dan itu bukan sekadar penataan URL. Tidak ada chat yang
/// berdiri sendiri di sistem ini: setiap pesan wajib punya order. Tanpa aturan itu, ruang
/// chatnya pelan-pelan berubah jadi WhatsApp versi lebih jelek, persis masalah yang mau
/// ditinggalkan mitra.
/// </summary>
[ApiController]
[Route("api/orders/{id:guid}/pesan")]
[Authorize]
public class OrderChatController(AppDbContext db) : ControllerBase
{
    /// <summary>Seluruh pesan di satu order, terlama di atas.</summary>
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<OrderMessageResponse>>> Daftar(
        Guid id,
        CancellationToken batal)
    {
        var order = await Muat(id, batal);
        if (order is null || !AksesOrder.BolehLihat(order, User.Id(), User)) return NotFound();

        var pesan = await db.OrderMessages
            .Where(m => m.OrderId == id)
            .OrderBy(m => m.CreatedAt)
            .ToListAsync(batal);

        return Ok(pesan.Select(OrderMessageResponse.Dari).ToList());
    }

    /// <summary>Mengirim satu pesan.</summary>
    [HttpPost]
    public async Task<ActionResult<OrderMessageResponse>> Kirim(
        Guid id,
        KirimPesanRequest permintaan,
        CancellationToken batal)
    {
        var order = await Muat(id, batal);
        if (order is null) return NotFound();

        var pemanggil = User.Id();
        var peran = AksesOrder.PeranPada(order, pemanggil, User);

        // 404, bukan 403, sama seperti membaca order: yang bukan siapa-siapa di order ini
        // tidak berhak tahu bahwa ordernya ada.
        if (peran is null) return NotFound();

        // Order yang sudah selesai atau batal tidak boleh dihidupkan lagi lewat chat. Kalau
        // masih ada urusan, urusan itu butuh order baru atau campur tangan admin, bukan
        // percakapan yang menempel pada pekerjaan yang sudah ditutup.
        if (!order.Status.Aktif())
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Chat order ini sudah ditutup",
                Detail = $"Order ini sudah {order.Status}.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        var pesan = new OrderMessage
        {
            OrderId = order.Id,
            SenderId = pemanggil,
            SenderRole = peran.Value,
            Text = permintaan.Isi.Trim(),
        };

        db.OrderMessages.Add(pesan);
        await db.SaveChangesAsync(batal);

        return Ok(OrderMessageResponse.Dari(pesan));
    }

    private Task<Order?> Muat(Guid id, CancellationToken batal) => db.Orders
        .Include(o => o.RunnerAssignments)
        .SingleOrDefaultAsync(o => o.Id == id, batal);
}
