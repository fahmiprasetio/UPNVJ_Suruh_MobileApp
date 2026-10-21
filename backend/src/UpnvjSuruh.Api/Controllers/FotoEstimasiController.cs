using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Media;

namespace UpnvjSuruh.Api.Controllers;

[ApiController]
[Route("api/orders/{orderId:guid}/foto-estimasi")]
[Authorize(Roles = Peran.Klien)]
public class FotoEstimasiController(AppDbContext db, PenyimpanFoto penyimpan) : ControllerBase
{
    [EnableRateLimiting(BatasLaju.KebijakanUnggah)]
    [HttpPost]
    [RequestSizeLimit(PenyimpanFoto.BatasUkuranByte)]
    public async Task<ActionResult<FotoBuktiResponse>> Unggah(
        Guid orderId,
        IFormFile berkas,
        CancellationToken batal)
    {
        var order = await db.Orders.SingleOrDefaultAsync(
            o => o.Id == orderId && o.ClientId == User.Id(), batal);
        if (order is null) return NotFound();

        if (order.ServiceType is not (ServiceType.BersihKos or ServiceType.BersihKamarMandi) ||
            order.Status != OrderStatus.MenungguPembayaran)
        {
            return Conflict(new ProblemDetails
            {
                Title = "Order tidak menerima foto kondisi",
                Detail = "Foto kondisi hanya dapat diunggah untuk layanan kebersihan sebelum pembayaran.",
                Status = StatusCodes.Status409Conflict,
            });
        }

        if (berkas.Length == 0)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Berkasnya kosong",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        await using var isi = berkas.OpenReadStream();
        var ekstensi = await JenisGambar.EkstensiAsync(isi, batal);
        if (ekstensi is null)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Berkasnya bukan gambar",
                Detail = "Yang diterima hanya JPEG dan PNG.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        isi.Position = 0;
        using var mentah = new MemoryStream();
        await isi.CopyToAsync(mentah, batal);
        var byteMentah = mentah.ToArray();
        var sah = ekstensi == ".jpg"
            ? ValidasiGambar.SahJpeg(byteMentah)
            : ValidasiGambar.SahPng(byteMentah);
        if (!sah)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Berkasnya bukan gambar",
                Detail = "Struktur berkas tidak sesuai JPEG/PNG yang sah.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        using var bersih = new MemoryStream(
            ekstensi == ".jpg" ? PembersihExif.Buang(byteMentah) : byteMentah);
        order.EstimatePhotoUrl = await penyimpan.SimpanAsync(orderId, bersih, ekstensi, batal);
        await db.SaveChangesAsync(batal);
        return Ok(new FotoBuktiResponse(order.EstimatePhotoUrl));
    }
}
