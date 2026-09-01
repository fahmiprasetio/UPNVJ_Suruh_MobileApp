using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Controllers;

/// <summary>
/// Daftar order dari sudut pandang admin.
/// </summary>
/// <remarks>
/// Admin tidak lagi menentukan harga Jalur B, itu sekarang urusan tawar-menawar langsung
/// antara klien dan runner. Yang tersisa untuk admin murni memantau: melihat semua order
/// yang berjalan, disaring statusnya, tanpa perlu tahu id-nya lebih dulu, supaya order yang
/// macet atau penawaran yang janggal tetap kelihatan tanpa admin harus menebak-nebak id
/// mana yang perlu diperiksa.
///
/// Terpisah dari OrdersController karena pertanyaannya memang berbeda. Yang di sana selalu
/// "order milik siapa": pemesannya melihat ordernya sendiri, runner melihat yang ia pegang.
/// Yang di sini "order yang mana", tanpa hubungan kepemilikan sama sekali, dan itu justru
/// yang membuatnya berbahaya kalau penjagaannya meleset satu baris. Menaruhnya di controller
/// yang seluruh isinya dijaga peran admin membuat penjagaan itu tidak bergantung pada satu
/// atribut yang bisa hilang saat penyuntingan.
/// </remarks>
[ApiController]
[Route("api/admin/orders")]
[Authorize(Roles = Peran.Admin)]
public class AdminOrderController(AppDbContext db) : ControllerBase
{
    /// <summary>Order yang ada di sistem, disaring status dan dipotong per halaman.</summary>
    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<HalamanResponse<OrderResponse>>> Daftar(
        [FromQuery] PermintaanDaftarOrder permintaan,
        CancellationToken batal)
    {
        var kueri = db.Orders.AsQueryable();

        if (permintaan.Status is { } status)
        {
            kueri = kueri.Where(o => o.Status == status);
        }

        // Dihitung sebelum dipotong, jadi angkanya menyebut seluruh yang cocok, bukan yang
        // muat di halaman ini. Itulah satu-satunya angka yang berguna bagi yang membacanya:
        // "menunggu penawaran: 20" yang ternyata cuma isi satu halaman adalah kabar yang
        // menyesatkan justru ketika antreannya sedang menumpuk.
        var total = await kueri.CountAsync(batal);

        var orders = await kueri
            .Include(o => o.RunnerAssignments)
            .Include(o => o.Offers)
            .Include(o => o.Client)
            // Terbaru di atas, sama seperti seluruh daftar order lain di API ini.
            //
            // Untuk antrean penawaran, yang paling lama menunggu di atas sebenarnya lebih
            // masuk akal. Tapi urutan yang berubah menurut penyaringnya adalah aturan
            // tersembunyi: dua permintaan yang cuma beda satu parameter menjawab dengan
            // urutan berbeda tanpa ada yang menyebutkannya. Kalau nanti antreannya cukup
            // panjang sampai ada yang terlantar di halaman belakang, yang ditambahkan adalah
            // parameter urutan yang disebut terang-terangan, bukan kelakuan diam-diam.
            .OrderByDescending(o => o.CreatedAt)
            .ThenByDescending(o => o.Id)
            .Skip(permintaan.Dilewati)
            .Take(permintaan.Ukuran)
            .ToListAsync(batal);

        var jumlahPesan = await db.JumlahPesanAsync(
            [.. orders.Select(o => o.Id)], User.Id(), User.Punya(Peran.Admin), batal);

        return Ok(new HalamanResponse<OrderResponse>(
            [.. orders.Select(o => OrderResponse.Dari(
                o, o.Client?.Name ?? "Klien", jumlahPesan.GetValueOrDefault(o.Id)))],
            total,
            permintaan.Halaman,
            permintaan.Ukuran));
    }
}
