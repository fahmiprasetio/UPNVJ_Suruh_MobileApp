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
/// Jalur B: pekerjaan yang harganya tidak bisa dihitung sebelum dilihat.
///
/// Alurnya tawar-menawar, bukan pesan-langsung-bayar. Klien menuliskan kebutuhannya, admin
/// membalas dengan penawaran, klien menyetujui, menolak, atau meminta dihitung ulang.
/// Selama belum disetujui, angka di penawaran belum jadi harga order, karena order yang
/// memajang harga yang belum disepakati akan terbaca sebagai tagihan.
/// </summary>
[ApiController]
[Route("api/orders")]
[Authorize]
public class JalurBController(AppDbContext db) : ControllerBase
{
    /// <summary>Klien mengirim permintaan Jalur B. Belum ada harga di sini.</summary>
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
            // dibayar sampai admin menyebut angkanya.
            Status = OrderStatus.Permintaan,
            Description = permintaan.Deskripsi.Trim(),
            DestinationAddress = permintaan.AlamatTujuan?.Trim(),
            ScheduledStart = permintaan.JadwalMulai.ToUniversalTime(),
            RequiredRunnerCount = permintaan.JumlahRunnerDibutuhkan,
        };

        db.Orders.Add(order);
        await db.SaveChangesAsync(batal);

        return CreatedAtAction(
            nameof(OrdersController.Ambil),
            "Orders",
            new { id = order.Id },
            OrderResponse.Dari(order, klien.Name));
    }

    /// <summary>
    /// Admin mengirim penawaran harga untuk satu permintaan.
    /// </summary>
    /// <remarks>
    /// Hanya Jalur B yang punya penawaran. Harga Jalur A dihitung dari isian form sejak
    /// awal, dan mengizinkan penawaran di sana berarti membuka jalan mengubah harga yang
    /// sudah tertulis di layar klien.
    /// </remarks>
    [HttpPost("{id:guid}/penawaran")]
    [Authorize(Roles = Peran.Admin)]
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

        // Hanya permintaan yang belum punya penawaran menunggu yang boleh ditawari. Tanpa
        // syarat ini, penawaran kedua diam-diam menimpa penawaran yang sedang dibaca klien,
        // dan klien menekan setuju untuk harga yang berbeda dari yang tampil di layarnya.
        if (order.Status != OrderStatus.Permintaan)
        {
            return Salah(
                "Bukan permintaan yang menunggu penawaran",
                $"Order ini sedang berstatus {order.Status}.");
        }

        var penawaran = new OrderOffer
        {
            OrderId = order.Id,
            CreatedByAdminId = User.Id(),
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

        // Harga ordernya sengaja tidak diisi di sini. Angka itu masih usulan sampai klien
        // menyetujuinya.
        order.Status = OrderStatus.MenungguPersetujuanKlien;

        try
        {
            await db.SaveChangesAsync(batal);
        }
        catch (DbUpdateException galat) when (GalatDb.Bentrok(galat))
        {
            // Dua admin menawar order yang sama pada saat yang sama. Index unik parsial pada
            // penawaran yang masih menunggu yang menahannya, bukan pemeriksaan status di atas,
            // karena keduanya membaca sebelum ada yang menulis.
            return Konflik("Order ini baru saja ditawari admin lain.");
        }

        return Ok(OrderResponse.Dari(
            order, order.Client?.Name ?? "Klien", await db.JumlahPesanAsync(order.Id, batal)));
    }

    /// <summary>
    /// Klien menyetujui penawaran yang sedang menunggu.
    /// </summary>
    /// <remarks>
    /// Di sinilah harga, estimasi durasi, dan jadwal penawaran pindah menjadi milik ordernya,
    /// lalu order lanjut ke menunggu pembayaran.
    /// </remarks>
    [HttpPost("{id:guid}/penawaran/setujui")]
    [Authorize(Roles = Peran.Klien)]
    public async Task<ActionResult<OrderResponse>> Setujui(Guid id, CancellationToken batal)
    {
        var (order, penawaran, galat) = await MuatUntukKlien(id, batal);
        if (galat is not null) return galat;

        order!.Price = penawaran!.Price;
        order.EstimatedDuration = penawaran.EstimatedDuration;
        order.ScheduledStart = penawaran.ScheduledStart;
        order.Status = OrderStatus.MenungguPembayaran;
        Jawab(penawaran, OfferStatus.Disetujui);

        await db.SaveChangesAsync(batal);
        return Ok(OrderResponse.Dari(
            order, order.Client?.Name ?? "Klien", await db.JumlahPesanAsync(order.Id, batal)));
    }

    /// <summary>
    /// Klien menolak penawaran.
    /// </summary>
    /// <remarks>
    /// Penolakan mengakhiri ordernya, bukan mengembalikannya ke antrean admin. Klien yang
    /// masih berminat dengan harga lain memakai nego; yang menekan tolak memang sudah tidak
    /// berminat.
    /// </remarks>
    [HttpPost("{id:guid}/penawaran/tolak")]
    [Authorize(Roles = Peran.Klien)]
    public async Task<ActionResult<OrderResponse>> Tolak(Guid id, CancellationToken batal)
    {
        var (order, penawaran, galat) = await MuatUntukKlien(id, batal);
        if (galat is not null) return galat;

        order!.Status = OrderStatus.Batal;
        Jawab(penawaran!, OfferStatus.Ditolak);

        await db.SaveChangesAsync(batal);
        return Ok(OrderResponse.Dari(
            order, order.Client?.Name ?? "Klien", await db.JumlahPesanAsync(order.Id, batal)));
    }

    /// <summary>
    /// Klien meminta penawaran ditinjau ulang, disertai alasannya.
    /// </summary>
    /// <remarks>
    /// Ordernya kembali ke antrean admin, dan alasannya ditulis sebagai pesan di chat
    /// ordernya. Alasan itu tidak disimpan di dalam penawaran karena tempat menjawabnya
    /// memang chat: admin membaca, bertanya kalau perlu, lalu mengirim penawaran baru.
    /// </remarks>
    [HttpPost("{id:guid}/penawaran/nego")]
    [Authorize(Roles = Peran.Klien)]
    public async Task<ActionResult<OrderResponse>> Nego(
        Guid id,
        NegoPenawaranRequest permintaan,
        CancellationToken batal)
    {
        var (order, penawaran, galat) = await MuatUntukKlien(id, batal);
        if (galat is not null) return galat;

        // Kembali ke antrean admin, bukan batal: klien masih berminat.
        order!.Status = OrderStatus.Permintaan;
        Jawab(penawaran!, OfferStatus.DinegoUlang);

        db.OrderMessages.Add(new OrderMessage
        {
            OrderId = order.Id,
            // Pengirimnya diambil dari token. Peran penulis pesan tidak pernah datang dari
            // badan permintaan, karena kalau begitu siapa pun bisa menulis atas nama admin.
            SenderId = User.Id(),
            SenderRole = UserRole.Klien,
            Text = permintaan.Alasan.Trim(),
        });

        await db.SaveChangesAsync(batal);
        return Ok(OrderResponse.Dari(
            order, order.Client?.Name ?? "Klien", await db.JumlahPesanAsync(order.Id, batal)));
    }

    private Task<Order?> Muat(Guid id, CancellationToken batal) => db.Orders
        .Include(o => o.Offers)
        .Include(o => o.RunnerAssignments)
        .Include(o => o.Client)
        .SingleOrDefaultAsync(o => o.Id == id, batal);

    /// <summary>
    /// Memuat order beserta penawaran yang menunggu, sambil memastikan pemanggilnya memang
    /// pemesan order itu.
    ///
    /// Peran klien saja tidak cukup. Tanpa pemeriksaan pemilik, klien mana pun bisa
    /// menyetujui atau menolak penawaran di order orang lain, cukup dengan menebak idnya.
    /// </summary>
    private async Task<(Order? Order, OrderOffer? Penawaran, ActionResult? Galat)> MuatUntukKlien(
        Guid id,
        CancellationToken batal)
    {
        var order = await Muat(id, batal);
        if (order is null) return (null, null, NotFound());

        // 404, bukan 403, sama seperti membaca order: yang bukan pemesannya tidak berhak tahu
        // bahwa ordernya ada.
        if (order.ClientId != User.Id()) return (null, null, NotFound());

        var penawaran = order.Offers.SingleOrDefault(f => f.Status == OfferStatus.Pending);
        if (penawaran is null || order.Status != OrderStatus.MenungguPersetujuanKlien)
        {
            return (null, null, Salah(
                "Tidak ada penawaran yang menunggu jawaban",
                $"Order ini sedang berstatus {order.Status}."));
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
