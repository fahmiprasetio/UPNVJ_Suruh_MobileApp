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
public class AdminOrderController(
    AppDbContext db,
    IHubContext<OrderHub> hub,
    ILogger<AdminOrderController> log) : ControllerBase
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

        // Satu-satunya antrean di dashboard ini yang isinya menuntut jawaban, bukan sekadar
        // ditonton: di ujungnya ada uang yang dikembalikan atau tidak, dan klien yang sedang
        // menunggu jawabannya. Tanpa penyaring ini admin harus memindai seluruh daftar order
        // untuk menemukan yang mana yang sedang bertanya.
        if (permintaan.MintaBatal == true)
        {
            kueri = kueri.Where(o => o.CancellationRequestedAt != null);
        }

        // Disaring di basis data, bukan sesudah halamannya terpotong. Menyaring di sisi sini
        // berarti "5 order macet" yang sebenarnya berarti "5 di antara dua puluh yang muat di
        // halaman ini", dan yang berada di halaman berikutnya tidak pernah ditemukan siapa pun.
        if (permintaan.Macet == true)
        {
            kueri = kueri.Where(OrderMacet.Ekspresi(DateTime.UtcNow));
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

    /// <summary>
    /// Membatalkan order yang sudah dibayar, sekaligus mencatat pengembalian dananya.
    /// </summary>
    /// <remarks>
    /// Ini bukan endpoint batal yang sudah ada di <c>OrdersController</c>. Yang di sana
    /// sengaja menolak order yang <c>PaidAt</c>-nya sudah terisi, persis dengan pesan
    /// "harus lewat admin" — inilah jalur itu. Order yang BELUM dibayar tetap dibatalkan
    /// lewat endpoint klien biasa; endpoint ini menjawab 400 kalau dipanggil untuk order
    /// yang belum ada uangnya, supaya admin tidak menduga ada dua jalan pembatalan yang
    /// tumpang tindih.
    ///
    /// Pengembaliannya cuma catatan pembukuan (lihat <see cref="PaymentStatus.Dikembalikan"/>),
    /// bukan panggilan ke gateway sungguhan: capstone ini berjalan di sandbox (rencana bagian
    /// 6), jadi tidak ada uang sungguhan yang perlu ditarik balik lewat API mana pun. Begitu
    /// mitra mengaktifkan mode produksi, di sinilah panggilan refund gateway sungguhan akan
    /// ditambahkan, tanpa mengubah bentuk endpoint ini.
    /// </remarks>
    [HttpPost("{id:guid}/batalkan")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<OrderResponse>> Batalkan(
        Guid id,
        BatalkanOrderRequest permintaan,
        CancellationToken batal)
    {
        var order = await db.Orders
            .Include(o => o.Payments)
            .Include(o => o.RunnerAssignments)
            .Include(o => o.Offers)
            .Include(o => o.Client)
            .SingleOrDefaultAsync(o => o.Id == id, batal);

        if (order is null) return NotFound();

        if (!order.Status.Aktif())
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Order sudah berakhir",
                Detail = $"Order ini sudah {order.Status}.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        if (order.PaidAt is null)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Order ini belum dibayar",
                Detail = "Order yang belum dibayar dibatalkan lewat endpoint order biasa "
                         + "(POST /api/orders/{id}/batal), bukan lewat sini. Endpoint ini "
                         + "khusus order yang sudah ada uangnya, dan karena itu perlu "
                         + "dicatat pengembaliannya.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        var pembayaranLunas = order.Payments.SingleOrDefault(p => p.Status == PaymentStatus.Berhasil);
        if (pembayaranLunas is null)
        {
            // Tidak seharusnya terjadi: PaidAt cuma diisi PenyelesaiPembayaran bersamaan
            // dengan menandai satu transaksi Berhasil. Dicatat, bukan dilempar, karena
            // ordernya tetap harus bisa dibatalkan biar tidak menggantung selamanya sambil
            // menunggu data yang sudah janggal ini diperiksa.
            log.LogError(
                "Order {OrderId} punya PaidAt tapi tidak ada transaksi Berhasil.", order.Id);
        }
        else
        {
            pembayaranLunas.Status = PaymentStatus.Dikembalikan;
            pembayaranLunas.RefundedAt = DateTime.UtcNow;
            pembayaranLunas.RefundedByAdminId = User.Id();
            pembayaranLunas.RefundReason = permintaan.Alasan.Trim();
        }

        // Transaksi lain yang masih menunggu (mustahil dalam keadaan normal karena index
        // unik parsial di Payments membatasi satu order ke satu transaksi Pending sekaligus,
        // tapi order yang sudah lunas bisa saja punya percobaan lama yang belum sempat
        // hangus) ikut dimatikan, sama seperti pembatalan order biasa.
        foreach (var pembayaran in order.Payments.Where(p => p.Menunggu))
        {
            pembayaran.Status = PaymentStatus.Gagal;
        }

        order.Status = OrderStatus.Batal;

        // Permintaan yang sedang menunggu (kalau pembatalan ini memang menjawabnya) ikut
        // diturunkan benderanya. Membiarkannya berarti order yang sudah batal tetap terhitung
        // sebagai menunggu keputusan di dashboard, dan angka antrean yang tidak pernah
        // berkurang adalah angka yang berhenti dibaca orang.
        order.CancellationRequestedAt = null;

        await db.SaveChangesAsync(batal);
        await hub.BeriTahuPerubahanOrderAsync(order.Id, batal);

        return Ok(await OrderResponse.DariAsync(db, order, User.Id(), User.Punya(Peran.Admin), batal));
    }

    /// <summary>
    /// Admin menolak permintaan pembatalan dari klien: ordernya tetap berjalan.
    /// </summary>
    /// <remarks>
    /// Jawaban "tidak" harus punya jalannya sendiri, bukan cuma dibiarkan menggantung.
    /// Tanpa endpoint ini, benderanya menempel selamanya pada order yang tetap dikerjakan,
    /// dashboard terus menghitungnya sebagai menunggu keputusan, dan klien tidak pernah tahu
    /// permintaannya sudah dibaca.
    ///
    /// Alasannya masuk ke percakapan ordernya sebagai pesan dari admin, mengikuti pola yang
    /// sama dengan permintaannya sendiri. Klien membaca jawabannya di tempat ia menuliskan
    /// pertanyaannya, bukan di layar lain yang harus ia temukan sendiri.
    /// </remarks>
    [EnableRateLimiting(BatasLaju.KebijakanTulis)]
    [HttpPost("{id:guid}/tolak-pembatalan")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<OrderResponse>> TolakPembatalan(
        Guid id,
        TolakPembatalanRequest permintaan,
        CancellationToken batal)
    {
        var order = await db.Orders
            .Include(o => o.RunnerAssignments)
            .Include(o => o.Offers)
            .Include(o => o.Client)
            .SingleOrDefaultAsync(o => o.Id == id, batal);

        if (order is null) return NotFound();

        if (order.CancellationRequestedAt is null)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Tidak ada permintaan pembatalan",
                Detail = "Order ini tidak sedang menunggu keputusan pembatalan.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        order.CancellationRequestedAt = null;

        db.OrderMessages.Add(new OrderMessage
        {
            OrderId = order.Id,
            SenderId = User.Id(),
            SenderRole = UserRole.Admin,
            Text = permintaan.Alasan.Trim(),
        });

        await db.SaveChangesAsync(batal);
        await hub.BeriTahuPerubahanOrderAsync(order.Id, batal);

        return Ok(await OrderResponse.DariAsync(db, order, User.Id(), User.Punya(Peran.Admin), batal));
    }
}
