using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
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
    /// <summary>Pesan di satu order, terlama di atas, sebanyak jendela yang diminta.</summary>
    /// <remarks>
    /// Dua hal yang membatasi jawabannya, dan keduanya bukan hal yang sama.
    ///
    /// Yang pertama siapa pemanggilnya. Runner melihat percakapan sejak ia menerima ordernya,
    /// tidak lebih awal, karena tawar-menawar harga antara klien dan admin di Jalur B terjadi
    /// jauh sebelum ia bergabung dan bukan bagian dari pekerjaannya. Aturannya ada di
    /// <see cref="PesanTerlihat"/>, dipakai bersama penghitung jumlah pesan, supaya tidak
    /// pernah ada penanda "ada 12 pesan" pada percakapan yang isinya tiga.
    ///
    /// Yang kedua panjangnya. Percakapan cuma bertambah, dan aplikasi mengambilnya ulang
    /// setiap lima belas detik selama layar chat terbuka; tanpa batas, satu order yang ramai
    /// mengirim seluruh isinya berkali-kali setiap menit.
    ///
    /// Yang dikirim adalah pesan terbaru sebanyak jendela itu, lalu dibalik supaya terlama
    /// tetap di atas seperti percakapan dibaca. Bukan halaman pertama dari yang terlama:
    /// orang yang membuka chat ingin melihat yang barusan, bukan yang bulan lalu.
    ///
    /// Cara mengambil yang lebih lama adalah memperbesar jendelanya, bukan penunjuk posisi
    /// (keyset). Penunjuk posisi lebih hemat di atas kertas, dan tidak menolong di sini:
    /// aplikasi mengambil ulang seluruh jendelanya setiap lima belas detik, jadi hasil yang
    /// ditumpuk sendiri akan tertimpa setiap kali pengambilan itu datang. Kalau suatu saat
    /// chat perlu benar-benar hemat, yang dibutuhkan bukan keysetnya melainkan pengambilan
    /// yang cuma meminta pesan yang lebih baru daripada yang sudah dipegang.
    /// </remarks>
    [HttpGet]
    public async Task<ActionResult<HalamanResponse<OrderMessageResponse>>> Daftar(
        Guid id,
        [FromQuery] PermintaanHalaman permintaan,
        CancellationToken batal)
    {
        var order = await Muat(id, batal);
        var pemanggil = User.Id();
        if (order is null || !AksesOrder.BolehLihat(order, pemanggil, User)) return NotFound();

        var terlihat = db
            .PesanUntuk(pemanggil, User.Punya(Peran.Admin))
            .Where(m => m.OrderId == id);

        var total = await terlihat.CountAsync(batal);

        var pesan = await terlihat
            // Pemecah seri, sama alasannya dengan daftar order: dua pesan yang tersimpan pada
            // milidetik yang sama boleh diurutkan bagaimana saja oleh Postgres, dan urutan
            // yang tidak pasti membuat satu pesan hilang dari jendela lalu muncul dua kali
            // setelah jendelanya diperlebar.
            .OrderByDescending(m => m.CreatedAt)
            .ThenByDescending(m => m.Id)
            .Skip(permintaan.Dilewati)
            .Take(permintaan.Ukuran)
            .ToListAsync(batal);

        pesan.Reverse();

        return Ok(new HalamanResponse<OrderMessageResponse>(
            [.. pesan.Select(OrderMessageResponse.Dari)],
            total,
            permintaan.Halaman,
            permintaan.Ukuran));
    }

    /// <summary>Mengirim satu pesan.</summary>
    /// <remarks>
    /// Dibatasi per pengguna. Ruang chat adalah satu-satunya tempat di sistem ini yang
    /// menerima teks bebas berulang kali dari orang yang sudah masuk, jadi ia juga
    /// satu-satunya tempat satu akun bisa menumbuhkan tabel tanpa batas hanya dengan
    /// menekan kirim terus-menerus.
    /// </remarks>
    [EnableRateLimiting(BatasLaju.KebijakanTulis)]
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
