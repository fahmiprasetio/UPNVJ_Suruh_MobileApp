using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Media;

namespace UpnvjSuruh.Api.Controllers;

/// <summary>
/// Unggahan foto bukti pekerjaan.
/// </summary>
/// <remarks>
/// Terpisah dari endpoint penutupan order, dan itu disengaja. Runner memotret lebih dulu,
/// melihat hasilnya, mungkin mengulang, baru menekan selesai. Menggabungkannya jadi satu
/// permintaan berarti foto ikut hangus setiap kali penutupannya gagal karena hal lain.
/// </remarks>
[ApiController]
[Route("api/orders/{orderId:guid}/foto-bukti")]
[Authorize(Roles = Peran.Runner)]
public class FotoBuktiController(AppDbContext db, PenyimpanFoto penyimpan) : ControllerBase
{
    /// <summary>Mengunggah satu foto untuk order yang sedang dipegang.</summary>
    /// <remarks>
    /// Punya batas lajunya sendiri, terpisah dari penulisan biasa, karena satu permintaan di
    /// sini jauh lebih mahal daripada satu permintaan di mana pun: delapan megabita yang
    /// ditulis ke cakram dan tidak pernah dihapus siapa pun. Tanpa batas, satu akun runner
    /// cukup mengunggah berulang kali untuk memenuhi cakram server.
    /// </remarks>
    [EnableRateLimiting(BatasLaju.KebijakanUnggah)]
    [HttpPost]
    [RequestSizeLimit(PenyimpanFoto.BatasUkuranByte)]
    public async Task<ActionResult<FotoBuktiResponse>> Unggah(
        Guid orderId,
        IFormFile berkas,
        CancellationToken batal)
    {
        var order = await db.Orders
            .Include(o => o.RunnerAssignments)
            .SingleOrDefaultAsync(o => o.Id == orderId, batal);

        // Yang tidak memegang order ini tidak berhak tahu bahwa ordernya ada, sama seperti
        // di endpoint order lainnya. Kalau tidak, siapa pun yang punya peran runner bisa
        // memetakan order yang sedang berjalan dengan mencoba banyak id.
        if (order is null || order.RunnerAssignments.All(a => a.RunnerId != User.Id()))
        {
            return NotFound();
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

        // Jenisnya ditentukan dari isi berkasnya, bukan dari Content-Type maupun nama berkas
        // kiriman. Keduanya ditulis pengunggah, jadi keduanya bisa berbohong, dan berkas yang
        // mengaku gambar lalu dilayani sebagai gambar adalah cara lama menyelundupkan skrip
        // ke browser orang lain.
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

        // Byte penanda di atas cuma memeriksa awal berkasnya. Ini memeriksa seluruhnya:
        // berkas yang diawali penanda JPEG/PNG asli lalu ditambahi apa saja sesudah data
        // gambarnya berakhir (berkas polyglot) ditolak di sini, sebelum sempat tersimpan.
        var sah = ekstensi == ".jpg" ? ValidasiGambar.SahJpeg(byteMentah) : ValidasiGambar.SahPng(byteMentah);
        if (!sah)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Berkasnya bukan gambar",
                Detail = "Struktur berkas tidak sesuai JPEG/PNG yang sah.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        // Metadata Exif -- termasuk lokasi GPS kamera ponsel -- dibuang sebelum disimpan.
        // Lihat alasannya di PembersihExif. PNG tidak diproses ulang, sesuai batasannya.
        if (ekstensi == ".jpg")
        {
            using var bersih = new MemoryStream(PembersihExif.Buang(byteMentah));
            var urlBersih = await penyimpan.SimpanAsync(orderId, bersih, ekstensi, batal);
            return Ok(new FotoBuktiResponse(urlBersih));
        }

        using var png = new MemoryStream(byteMentah);
        var url = await penyimpan.SimpanAsync(orderId, png, ekstensi, batal);
        return Ok(new FotoBuktiResponse(url));
    }
}

/// <summary>URL foto yang baru diunggah, untuk dikirim balik saat menutup order.</summary>
public record FotoBuktiResponse(string Url);

/// <summary>Mengenali jenis gambar dari beberapa byte pertamanya.</summary>
/// <remarks>
/// Cuma dua yang diterima, dan keduanya punya penanda awal yang tetap: JPEG selalu dimulai
/// FF D8 FF, PNG selalu 89 50 4E 47. Memakai pustaka pengolah gambar untuk ini berarti
/// menambah ketergantungan yang jauh lebih besar daripada masalahnya.
/// </remarks>
public static class JenisGambar
{
    public static async Task<string?> EkstensiAsync(Stream isi, CancellationToken batal)
    {
        var kepala = new byte[4];
        var terbaca = await isi.ReadAtLeastAsync(kepala, kepala.Length, throwOnEndOfStream: false, batal);
        if (terbaca < 4) return null;

        if (kepala[0] == 0xFF && kepala[1] == 0xD8 && kepala[2] == 0xFF) return ".jpg";
        if (kepala[0] == 0x89 && kepala[1] == 0x50 && kepala[2] == 0x4E && kepala[3] == 0x47) return ".png";
        return null;
    }
}
