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
/// Jalur B: pekerjaan yang harganya tidak bisa dihitung sebelum dilihat.
///
/// Alurnya tawar-menawar, mirip aplikasi ojek daring, bukan penawaran tunggal dari satu
/// admin. Klien menuliskan kebutuhannya sekaligus mengusulkan harga, lalu permintaan itu
/// terbuka untuk ditawar seluruh runner yang tersedia. Beberapa runner boleh punya
/// penawaran yang sama-sama menunggu jawaban klien pada order yang sama; klien memilih
/// satu, sisanya otomatis ditutup. Selama belum dipilih, angka di penawaran mana pun belum
/// jadi harga order, karena order yang memajang harga yang belum disepakati akan terbaca
/// sebagai tagihan.
/// </summary>
[ApiController]
[Route("api/orders")]
[Authorize]
public class JalurBController(AppDbContext db, IHubContext<OrderHub> hub) : ControllerBase
{
    /// <summary>Klien mengirim permintaan Jalur B, sekaligus mengusulkan harga.</summary>
    [EnableRateLimiting(BatasLaju.KebijakanTulis)]
    [HttpPost("jalur-b")]
    [Authorize(Roles = Peran.Klien)]
    public async Task<ActionResult<OrderResponse>> BuatPermintaan(
        BuatPermintaanJalurBRequest permintaan,
        CancellationToken batal)
    {
        if (permintaan.ServiceType.Track() != OrderTrack.JalurB)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Layanan ini Jalur A",
                Detail = "Harganya sudah bisa dihitung dari isian form, jadi tidak perlu ditawar.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        var klienId = User.Id();
        var klien = await db.Users.SingleOrDefaultAsync(u => u.Id == klienId, batal);
        if (klien is null) return Unauthorized();

        var order = new Order
        {
            ClientId = klienId,
            ServiceType = permintaan.ServiceType,
            // Lahir sebagai permintaan, bukan menunggu pembayaran. Belum ada yang bisa
            // dibayar sampai satu penawaran runner disetujui klien.
            Status = OrderStatus.Permintaan,
            Description = permintaan.Deskripsi.Trim(),
            DestinationAddress = permintaan.AlamatTujuan?.Trim(),
            ScheduledStart = permintaan.JadwalMulai.ToUniversalTime(),
            RequiredRunnerCount = permintaan.JumlahRunnerDibutuhkan,
            SuggestedPrice = permintaan.HargaUsulan,
        };

        db.Orders.Add(order);
        await db.SaveChangesAsync(batal);

        // Permintaan Jalur B langsung tampil di daftar order masuk runner (lihat penyaring
        // Permintaan di OrdersController.Tersiar), jadi ia layak disiarkan sama seperti order
        // Jalur A yang baru lunas. Beda dari Jalur A, di sini kecepatannya bukan sekadar
        // kenyamanan: yang menunggu adalah perlombaan menawar, dan runner yang daftarnya baru
        // menyusul lima belas detik kemudian kalah bukan karena harganya.
        //
        // Yang dikirim mengikuti "OrderBroadcast" Jalur A, dengan satu bedanya yang jujur:
        // harganya masih usulan klien, belum harga order. Angka sungguhannya baru ada setelah
        // salah satu penawaran runner disetujui.
        await hub.Clients.Group(OrderHub.RunnersGroup).SendAsync(
            "OrderBroadcast",
            new
            {
                OrderId = order.Id,
                KodeOrder = order.OrderCode,
                ServiceType = order.ServiceType.ToString(),
                Harga = order.SuggestedPrice,
                JumlahRunnerDibutuhkan = order.RequiredRunnerCount,
            },
            batal);
        await hub.BeriTahuPerubahanOrderAsync(order.Id, batal);

        return CreatedAtAction(
            nameof(OrdersController.Ambil),
            "Orders",
            new { id = order.Id },
            OrderResponse.Dari(order, klien.Name));
    }

    /// <summary>
    /// Seorang runner mengirim penawaran harga untuk satu permintaan.
    /// </summary>
    /// <remarks>
    /// Hanya Jalur B yang punya penawaran. Harga Jalur A dihitung dari isian form sejak
    /// awal, dan mengizinkan penawaran di sana berarti membuka jalan mengubah harga yang
    /// sudah tertulis di layar klien.
    ///
    /// Runner boleh mengirim harga persis sama dengan <see cref="Order.SuggestedPrice"/>
    /// kalau ia setuju dengan usulan klien apa adanya, atau angka lain kalau ia mau menawar
    /// balik. Keduanya penawaran yang sah dan sama-sama bisa dipilih klien; tidak ada jalur
    /// "setuju" yang terpisah dari mengirim penawaran.
    /// </remarks>
    [HttpPost("{id:guid}/penawaran")]
    [Authorize(Roles = Peran.Runner)]
    public async Task<ActionResult<OrderResponse>> BuatPenawaran(
        Guid id,
        BuatPenawaranRequest permintaan,
        CancellationToken batal)
    {
        var order = await Muat(id, batal);
        if (order is null) return NotFound();

        if (order.Track != OrderTrack.JalurB)
        {
            return Salah("Bukan Jalur B", "Harga order ini sudah pasti sejak dibuat.");
        }

        var runnerId = User.Id();

        // Klien yang akun yang sama juga menyandang peran Runner tidak boleh menawar
        // ordernya sendiri. Tanpa ini, satu akun bisa "memenangkan" pesanannya sendiri
        // dengan harga berapa pun yang ia mau.
        if (order.ClientId == runnerId)
        {
            return Salah("Tidak bisa menawar order sendiri", "Order ini milik Anda sebagai klien.");
        }

        // Order yang masih menerima penawaran selalu berstatus Permintaan, tidak peduli
        // sudah ada berapa banyak penawaran pending di dalamnya. Status berubah hanya
        // ketika klien sudah memilih satu, jadi ini juga yang menahan runner menawar order
        // yang penawarannya sudah dipilih atau dibatalkan.
        if (order.Status != OrderStatus.Permintaan)
        {
            return Salah(
                "Bukan permintaan yang menerima penawaran",
                $"Order ini sedang berstatus {order.Status}.");
        }

        var penawaran = new OrderOffer
        {
            OrderId = order.Id,
            CreatedByRunnerId = runnerId,
            Price = permintaan.Harga,
            EstimatedDuration = TimeSpan.FromMinutes(permintaan.EstimasiDurasiMenit),
            ScheduledStart = permintaan.JadwalMulai.ToUniversalTime(),
            Note = permintaan.Catatan?.Trim(),
        };

        // Lewat DbSet, bukan lewat koleksi navigasinya, dan cukup satu di antara keduanya.
        //
        // OrderOffer membuat Id-nya sendiri, jadi entitas yang ditemukan hanya lewat navigasi
        // terbaca sebagai baris yang sudah ada: EF menandainya Modified lalu mengirim UPDATE
        // untuk baris yang belum pernah ada, dan gagalnya muncul sebagai galat konkurensi
        // yang menyesatkan.
        //
        // Menambahkannya ke keduanya juga salah, karena EF menautkannya sendiri ke
        // `order.Offers` begitu terlacak, dan penawarannya jadi muncul dua kali di jawaban.
        db.OrderOffers.Add(penawaran);

        // Status ordernya sengaja tidak berubah di sini. Runner lain masih boleh menawar
        // selama klien belum memilih siapa pun, dan harga ordernya baru terisi begitu
        // klien menyetujui satu penawaran, bukan begitu penawaran pertama masuk.

        try
        {
            await db.SaveChangesAsync(batal);
        }
        catch (DbUpdateException galat) when (GalatDb.Bentrok(galat))
        {
            // Runner yang sama mengirim dua penawaran sekaligus untuk order yang sama.
            // Index unik parsial pada pasangan (OrderId, CreatedByRunnerId) yang menahannya,
            // bukan pemeriksaan status di atas, karena keduanya membaca sebelum ada yang
            // menulis. Runner LAIN yang menawar order ini pada saat bersamaan tidak kena
            // konflik ini sama sekali, itu memang tawar-menawar, bukan tabrakan.
            return Konflik("Anda sudah punya penawaran yang menunggu jawaban untuk order ini.");
        }

        return Ok(await OrderResponse.DariAsync(db, order, User.Id(), User.Punya(Peran.Admin), batal));
    }

    /// <summary>
    /// Klien menyetujui satu penawaran tertentu.
    /// </summary>
    /// <remarks>
    /// Di sinilah harga, estimasi durasi, dan jadwal penawaran itu pindah menjadi milik
    /// ordernya, lalu order lanjut ke menunggu pembayaran. Seluruh penawaran lain yang
    /// masih menunggu pada order yang sama otomatis ditutup: runner yang tidak terpilih
    /// tidak menggantung tanpa kabar, dan tidak ada dua penawaran yang bisa disetujui untuk
    /// order yang sama.
    /// </remarks>
    [HttpPost("{id:guid}/penawaran/{offerId:guid}/setujui")]
    [Authorize(Roles = Peran.Klien)]
    public async Task<ActionResult<OrderResponse>> Setujui(
        Guid id, Guid offerId, CancellationToken batal)
    {
        var (order, penawaran, galat) = await MuatPenawaranUntukKlien(id, offerId, batal);
        if (galat is not null) return galat;

        order!.Price = penawaran!.Price;
        order.EstimatedDuration = penawaran.EstimatedDuration;
        order.ScheduledStart = penawaran.ScheduledStart;
        db.OrderStatusChanges.Add(OrderStatusChange.Catat(order, OrderStatus.MenungguPembayaran, User.Id()));
        Jawab(penawaran, OfferStatus.Disetujui);

        foreach (var lainnya in order.Offers.Where(f => f.Id != penawaran.Id && f.Status == OfferStatus.Pending))
        {
            Jawab(lainnya, OfferStatus.Ditutup);
        }

        await db.SaveChangesAsync(batal);
        await hub.BeriTahuPerubahanOrderAsync(order.Id, batal);
        return Ok(await OrderResponse.DariAsync(db, order, User.Id(), User.Punya(Peran.Admin), batal));
    }

    /// <summary>
    /// Klien menolak satu penawaran tertentu.
    /// </summary>
    /// <remarks>
    /// Menolak satu penawaran tidak mengakhiri ordernya, dan tidak menyentuh penawaran
    /// runner lain yang masih menunggu pada order yang sama. Klien yang mau membatalkan
    /// permintaannya sama sekali memakai endpoint pembatalan order, bukan ini: ini cuma
    /// urusan satu penawaran dari satu runner.
    /// </remarks>
    [HttpPost("{id:guid}/penawaran/{offerId:guid}/tolak")]
    [Authorize(Roles = Peran.Klien)]
    public async Task<ActionResult<OrderResponse>> Tolak(
        Guid id, Guid offerId, CancellationToken batal)
    {
        var (order, penawaran, galat) = await MuatPenawaranUntukKlien(id, offerId, batal);
        if (galat is not null) return galat;

        Jawab(penawaran!, OfferStatus.Ditolak);

        await db.SaveChangesAsync(batal);
        return Ok(await OrderResponse.DariAsync(db, order!, User.Id(), User.Punya(Peran.Admin), batal));
    }

    /// <summary>
    /// Runner menarik kembali penawarannya sendiri.
    /// </summary>
    /// <remarks>
    /// Sebelum ini runner tidak punya jalan keluar apa pun atas penawarannya. Ia tidak bisa
    /// mencabutnya, dan tidak bisa mengirim penawaran pengganti selama yang lama masih
    /// menunggu (index unik parsial pada pasangan OrderId dan runner menahannya). Sementara
    /// itu klien boleh menyetujuinya kapan saja, dan persetujuan memindahkan harga penawaran
    /// menjadi harga order lalu mengunci runner itu sebagai pemegangnya begitu lunas.
    ///
    /// Artinya satu digit yang salah ketik — 50.000 padahal maksudnya 150.000 — mengikat
    /// runner ke pekerjaan seharga sepertiga, dan satu-satunya harapannya klien kebetulan
    /// menolak. Itu bukan tawar-menawar, itu jebakan.
    ///
    /// ## Yang bisa dan tidak bisa dicabut
    ///
    /// Yang masih menunggu jawaban (<see cref="OfferStatus.Pending"/>) dan yang diminta
    /// dihitung ulang (<see cref="OfferStatus.DinegoUlang"/>): boleh. Keduanya belum jadi
    /// komitmen apa pun bagi klien.
    ///
    /// Yang sudah disetujui: tidak. Harga ordernya sudah ditetapkan dari penawaran itu dan
    /// klien mungkin sedang membayarnya; membiarkan runner menariknya di titik itu berarti
    /// klien membayar pekerjaan yang tidak lagi punya siapa-siapa. Runner yang tetap ingin
    /// mundur menunggu pembayarannya masuk, lalu memakai jalan yang memang untuk itu
    /// (<c>POST /api/orders/{id}/lepas</c>), yang mengembalikan ordernya ke pencarian runner
    /// alih-alih meninggalkannya kosong.
    ///
    /// Sesudah dicabut, order itu muncul lagi di daftar order masuk runner dan ia boleh
    /// menawar ulang dengan angka yang benar. Itu memang tujuannya.
    /// </remarks>
    [EnableRateLimiting(BatasLaju.KebijakanTulis)]
    [HttpPost("{id:guid}/penawaran/{offerId:guid}/cabut")]
    [Authorize(Roles = Peran.Runner)]
    public async Task<ActionResult<OrderResponse>> Cabut(
        Guid id,
        Guid offerId,
        CabutPenawaranRequest permintaan,
        CancellationToken batal)
    {
        var order = await Muat(id, batal);
        if (order is null) return NotFound();

        var runnerId = User.Id();

        var penawaran = order.Offers.SingleOrDefault(
            f => f.Id == offerId && f.CreatedByRunnerId == runnerId);

        // 404, bukan 403: penawaran orang lain bukan sesuatu yang boleh ia ketahui ada.
        if (penawaran is null) return NotFound();

        if (penawaran.Status is not (OfferStatus.Pending or OfferStatus.DinegoUlang))
        {
            return Salah(
                "Penawaran ini sudah tidak bisa dicabut",
                penawaran.Status == OfferStatus.Disetujui
                    ? "Penawaranmu sudah dipilih klien dan harganya sudah jadi harga order. "
                      + "Kalau tetap ingin mundur, tunggu pembayarannya masuk lalu lepas "
                      + "ordernya."
                    : $"Penawaran ini sudah {penawaran.Status}.");
        }

        // Ditulis selagi runnernya masih pihak yang berkepentingan di order ini. Sesudah
        // penawarannya dicabut ia bukan siapa-siapa di sana lagi (AksesOrder.MasihMenawar),
        // dan endpoint chat akan menolaknya.
        var alasan = permintaan.Alasan?.Trim();
        if (!string.IsNullOrEmpty(alasan))
        {
            db.OrderMessages.Add(new OrderMessage
            {
                OrderId = order.Id,
                // Ke jalur obrolan pribadinya sendiri, bukan obrolan umum: yang perlu
                // membacanya cuma klien, dan runner lain yang menawar order yang sama tidak
                // ada urusannya dengan tawaran yang ditarik ini.
                RunnerPenawarId = runnerId,
                SenderId = runnerId,
                SenderRole = UserRole.Runner,
                Text = alasan,
            });
        }

        Jawab(penawaran, OfferStatus.Dicabut);

        await db.SaveChangesAsync(batal);

        // Status ordernya tidak bergeser: permintaan Jalur B yang kehilangan satu penawaran
        // tetap permintaan yang menerima penawaran. Yang berubah cuma isi daftar tawarannya,
        // dan itu terlihat dari ordernya sendiri.
        await hub.BeriTahuPerubahanOrderAsync(order.Id, batal);

        return Ok(await OrderResponse.DariAsync(db, order, runnerId, User.Punya(Peran.Admin), batal));
    }

    /// <summary>
    /// Klien meminta satu penawaran tertentu ditinjau ulang, disertai alasannya.
    /// </summary>
    /// <remarks>
    /// Bukan dikembalikan ke antrean admin seperti dulu, karena tidak ada lagi antrean
    /// admin di Jalur B: alasannya ditulis di jalur obrolan pribadi klien dengan runner
    /// yang bersangkutan, dan runner itu bebas mengirim penawaran baru begitu penawaran
    /// lamanya berstatus DinegoUlang (bukan lagi Pending), tanpa menyentuh runner lain
    /// yang mungkin sedang menawar order yang sama.
    /// </remarks>
    [HttpPost("{id:guid}/penawaran/{offerId:guid}/nego")]
    [Authorize(Roles = Peran.Klien)]
    public async Task<ActionResult<OrderResponse>> Nego(
        Guid id,
        Guid offerId,
        NegoPenawaranRequest permintaan,
        CancellationToken batal)
    {
        var (order, penawaran, galat) = await MuatPenawaranUntukKlien(id, offerId, batal);
        if (galat is not null) return galat;

        Jawab(penawaran!, OfferStatus.DinegoUlang);

        db.OrderMessages.Add(new OrderMessage
        {
            OrderId = order!.Id,
            // Ditandai ke jalur obrolan pribadi runner ini, bukan chat umum, supaya runner
            // lain yang sedang menawar order yang sama tidak ikut membaca alasan nego ini.
            RunnerPenawarId = penawaran!.CreatedByRunnerId,
            // Pengirimnya diambil dari token. Peran penulis pesan tidak pernah datang dari
            // badan permintaan, karena kalau begitu siapa pun bisa menulis atas nama admin.
            SenderId = User.Id(),
            SenderRole = UserRole.Klien,
            Text = permintaan.Alasan.Trim(),
        });

        await db.SaveChangesAsync(batal);
        return Ok(await OrderResponse.DariAsync(db, order, User.Id(), User.Punya(Peran.Admin), batal));
    }

    private Task<Order?> Muat(Guid id, CancellationToken batal) => db.Orders
        .Include(o => o.Offers)
        .Include(o => o.RunnerAssignments)
        .Include(o => o.Client)
        .SingleOrDefaultAsync(o => o.Id == id, batal);

    /// <summary>
    /// Memuat order beserta satu penawaran tertentu yang masih menunggu jawaban, sambil
    /// memastikan pemanggilnya memang pemesan order itu.
    ///
    /// Peran klien saja tidak cukup. Tanpa pemeriksaan pemilik, klien mana pun bisa
    /// menjawab penawaran di order orang lain, cukup dengan menebak idnya.
    /// </summary>
    private async Task<(Order? Order, OrderOffer? Penawaran, ActionResult? Galat)> MuatPenawaranUntukKlien(
        Guid id,
        Guid offerId,
        CancellationToken batal)
    {
        var order = await Muat(id, batal);
        if (order is null) return (null, null, NotFound());

        // 404, bukan 403, sama seperti membaca order: yang bukan pemesannya tidak berhak tahu
        // bahwa ordernya ada.
        if (order.ClientId != User.Id()) return (null, null, NotFound());

        var penawaran = order.Offers.SingleOrDefault(f => f.Id == offerId && f.Status == OfferStatus.Pending);
        if (penawaran is null)
        {
            return (null, null, Salah(
                "Tidak ada penawaran yang menunggu jawaban dengan id itu",
                "Penawaran ini mungkin sudah dijawab, ditutup, atau tidak pernah ada."));
        }

        return (order, penawaran, null);
    }

    private static void Jawab(OrderOffer penawaran, OfferStatus status)
    {
        penawaran.Status = status;
        penawaran.RespondedAt = DateTime.UtcNow;
    }

    private ActionResult Salah(string judul, string detail) => BadRequest(new ProblemDetails
    {
        Title = judul,
        Detail = detail,
        Status = StatusCodes.Status400BadRequest,
    });

    private ActionResult Konflik(string detail) => Conflict(new ProblemDetails
    {
        Title = "Bentrok dengan perubahan lain",
        Detail = detail,
        Status = StatusCodes.Status409Conflict,
    });
}
