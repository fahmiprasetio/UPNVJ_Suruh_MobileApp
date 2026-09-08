using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Hubs;
using UpnvjSuruh.Api.Notifikasi;

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
public class OrderChatController(AppDbContext db, IHubContext<OrderHub> hub, PengabarOrder pengabar) : ControllerBase
{
    /// <summary>Pesan di satu order, terlama di atas, sebanyak jendela yang diminta.</summary>
    /// <remarks>
    /// Dua hal yang membatasi jawabannya, dan keduanya bukan hal yang sama.
    ///
    /// Yang pertama siapa pemanggilnya, dan jalur obrolan mana yang ia minta lewat
    /// <paramref name="runnerId"/>. Selama order Jalur B masih menerima penawaran, tiap
    /// runner punya jalur obrolan pribadinya sendiri dengan klien; runner selalu melihat
    /// jalurnya sendiri saja (parameter ini diabaikan untuknya), sementara klien harus
    /// menyebutkan runner mana yang mau dilihat obrolannya kalau ada lebih dari satu yang
    /// sedang menawar. Begitu order sudah punya runner tetap, semua ini tidak lagi berarti:
    /// yang tersisa cuma satu jalur obrolan umum, dan runner melihatnya sejak ia diterima,
    /// tidak lebih awal, karena tawar-menawar sebelum ia terpilih bukan bagian dari
    /// pekerjaannya. Aturannya ada di <see cref="PesanTerlihat"/>, dipakai bersama
    /// penghitung jumlah pesan, supaya tidak pernah ada penanda "ada 12 pesan" pada
    /// percakapan yang isinya tiga.
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
        [FromQuery] Guid? runnerId,
        [FromQuery] PermintaanHalaman permintaan,
        CancellationToken batal)
    {
        var order = await Muat(id, batal);
        var pemanggil = User.Id();
        if (order is null || !AksesOrder.BolehLihat(order, pemanggil, User)) return NotFound();

        var jalurObrolan = JalurObrolan(order, pemanggil, runnerId);

        var terlihat = db
            .PesanUntuk(pemanggil, User.Punya(Peran.Admin))
            .Where(m => m.OrderId == id && m.RunnerPenawarId == jalurObrolan);

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
            RunnerPenawarId = JalurObrolan(order, pemanggil, permintaan.RunnerId),
            SenderId = pemanggil,
            SenderRole = peran.Value,
            Text = permintaan.Isi.Trim(),
        };

        db.OrderMessages.Add(pesan);
        await db.SaveChangesAsync(batal);

        // Sesudah tersimpan, bukan sebelum: kabar yang mendahului simpanannya akan membuat
        // penerimanya mengambil ulang percakapan yang belum berisi pesan itu, lalu diam
        // sampai pengambilan berkala berikutnya — persis kelambatan yang mau dihapus di sini.
        await hub.BeriTahuPesanBaruAsync(order.Id, batal);
        await pengabar.KabarkanPesanAsync(pesan, order, batal);

        return Ok(OrderMessageResponse.Dari(pesan));
    }

    /// <summary>Menandai jalur obrolan ini sudah dibaca pemanggil, sampai saat ini.</summary>
    /// <remarks>
    /// Dipanggil aplikasi setiap kali layar chat dibuka atau jendela pesannya diambil ulang,
    /// jadi ia harus tahan dipanggil berulang -- upsert, bukan Add polos, mengikuti pola yang
    /// sama dengan <c>PerangkatController.Daftarkan</c>. Tidak menyaring pesan mana yang
    /// "sudah dibaca": satu penanda waktu per jalur sudah cukup, dan pesan yang belum dibaca
    /// dihitung ulang dari situ lewat <see cref="Data.PesanTerlihat"/> setiap kali order
    /// ini diminta lagi.
    /// </remarks>
    [HttpPost("dibaca")]
    public async Task<IActionResult> TandaiDibaca(Guid id, [FromQuery] Guid? runnerId, CancellationToken batal)
    {
        var order = await Muat(id, batal);
        var pemanggil = User.Id();
        if (order is null || !AksesOrder.BolehLihat(order, pemanggil, User)) return NotFound();

        var jalur = JalurObrolan(order, pemanggil, runnerId) ?? Guid.Empty;

        var baris = await db.OrderMessageReads.SingleOrDefaultAsync(
            r => r.OrderId == id && r.UserId == pemanggil && r.RunnerPenawarId == jalur, batal);

        if (baris is null)
        {
            db.OrderMessageReads.Add(new OrderMessageRead
            {
                OrderId = id,
                UserId = pemanggil,
                RunnerPenawarId = jalur,
            });
        }
        else
        {
            baris.LastReadAt = DateTime.UtcNow;
        }

        try
        {
            await db.SaveChangesAsync(batal);
        }
        catch (DbUpdateException galat) when (GalatDb.Bentrok(galat))
        {
            // Dua permintaan tandai-dibaca dari perangkat yang sama datang nyaris bersamaan
            // (jendela chat yang dibuka lalu langsung diambil ulang berkala). Barisnya sudah
            // ada dengan isi yang hampir sama, bukan kegagalan yang layak dijawab 500.
        }

        return NoContent();
    }

    /// <summary>
    /// Jalur obrolan mana yang berlaku untuk satu pemanggil pada satu order: <c>null</c>
    /// untuk obrolan umum, atau id runner pemilik jalur obrolan pribadi Jalur B.
    /// </summary>
    /// <remarks>
    /// Runner yang belum diterima (masih menawar) selalu memakai jalurnya sendiri, dan
    /// parameter <paramref name="diminta"/> tidak pernah dipercaya untuknya. Kalau
    /// dipercaya, satu runner bisa menyebut runner lain sebagai jalurnya lalu membaca atau
    /// menulis di obrolan pribadi orang itu dengan klien.
    ///
    /// Klien memakai jalur yang diminta, karena ialah satu-satunya pihak yang boleh
    /// berbicara di lebih dari satu jalur pada order yang sama (satu per runner yang
    /// menawar).
    ///
    /// Runner yang sudah diterima, admin, dan seluruh order Jalur A selalu memakai obrolan
    /// umum, tidak peduli apa yang diminta: begitu ada runner tetap, tidak ada lagi jalur
    /// pribadi yang perlu dipisahkan.
    /// </remarks>
    private static Guid? JalurObrolan(Order order, Guid pemanggil, Guid? diminta)
    {
        var sudahDiterima = order.RunnerAssignments.Any(a => a.RunnerId == pemanggil);
        var sedangMenawar = !sudahDiterima && order.Offers.Any(f => f.CreatedByRunnerId == pemanggil);

        if (sedangMenawar) return pemanggil;
        if (order.ClientId == pemanggil) return diminta;
        return null;
    }

    private Task<Order?> Muat(Guid id, CancellationToken batal) => db.Orders
        .Include(o => o.RunnerAssignments)
        .Include(o => o.Offers)
        .SingleOrDefaultAsync(o => o.Id == id, batal);
}
