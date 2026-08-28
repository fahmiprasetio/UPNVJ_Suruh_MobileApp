using System.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Pricing;

namespace UpnvjSuruh.Api.Controllers;

[ApiController]
[Route("api/orders")]
[Authorize]
public class OrdersController(AppDbContext db, IKalkulatorTarif kalkulator) : ControllerBase
{
    /// <summary>
    /// Klien membuat order Jalur A. Harganya dihitung di sini, bukan diterima dari klien.
    /// </summary>
    [HttpPost("jalur-a")]
    [Authorize(Roles = Peran.Klien)]
    public async Task<ActionResult<BuatOrderResponse>> BuatJalurA(
        BuatOrderJalurARequest permintaan,
        CancellationToken batal)
    {
        if (permintaan.ServiceType.Track() != OrderTrack.JalurA)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Layanan ini Jalur B",
                Detail = "Harganya ditentukan admin lewat penawaran, bukan dihitung otomatis.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        HasilTarif tarif;
        try
        {
            tarif = kalkulator.Hitung(permintaan.ServiceType, permintaan.JarakKm);
        }
        catch (ArgumentException galat)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Order belum bisa dihitung",
                Detail = galat.Message,
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
            // Jalur A melewati dua status pertama, harganya sudah pasti sejak awal.
            Status = OrderStatus.MenungguPembayaran,
            Price = tarif.Total,
            Description = permintaan.Deskripsi?.Trim(),
            PickupAddress = permintaan.AlamatJemput?.Trim(),
            DestinationAddress = permintaan.AlamatTujuan?.Trim(),
            DistanceKm = permintaan.JarakKm,
        };

        db.Orders.Add(order);
        await db.SaveChangesAsync(batal);

        return CreatedAtAction(
            nameof(Ambil),
            new { id = order.Id },
            new BuatOrderResponse(
                OrderResponse.Dari(order, klien.Name),
                [.. tarif.Rincian.Select(RincianTarifResponse.Dari)]));
    }

    /// <summary>
    /// Satu order. Hanya bisa dibaca pemesannya, runner yang memegangnya, dan admin.
    /// </summary>
    /// <remarks>
    /// Yang tidak berhak dijawab 404, bukan 403. Membedakan "tidak ada" dari "ada tapi bukan
    /// punyamu" memberi tahu orang asing bahwa order itu ada, dan dengan mencoba banyak id
    /// ia bisa memetakan berapa banyak order yang berjalan.
    /// </remarks>
    [HttpGet("{id:guid}")]
    public async Task<ActionResult<OrderResponse>> Ambil(Guid id, CancellationToken batal)
    {
        var order = await db.Orders
            .Include(o => o.RunnerAssignments)
            .Include(o => o.Client)
            .SingleOrDefaultAsync(o => o.Id == id, batal);

        if (order is null) return NotFound();

        var pemanggil = User.Id();
        var berhak = order.ClientId == pemanggil
                     || order.RunnerAssignments.Any(a => a.RunnerId == pemanggil)
                     || User.Punya(Peran.Admin);

        if (!berhak) return NotFound();

        return Ok(OrderResponse.Dari(order, order.Client?.Name ?? "Klien"));
    }

    /// <summary>Order milik klien yang sedang masuk, terbaru di atas.</summary>
    [HttpGet("saya")]
    [Authorize(Roles = Peran.Klien)]
    public async Task<ActionResult<IReadOnlyList<OrderResponse>>> Saya(CancellationToken batal)
    {
        var klienId = User.Id();

        var orders = await db.Orders
            .Include(o => o.RunnerAssignments)
            .Include(o => o.Client)
            .Where(o => o.ClientId == klienId)
            .OrderByDescending(o => o.CreatedAt)
            .ToListAsync(batal);

        return Ok(orders.Select(o => OrderResponse.Dari(o, o.Client?.Name ?? "Klien")).ToList());
    }

    /// <summary>
    /// Order yang sedang disiarkan, dilihat dari sudut pandang runner yang sedang masuk.
    /// </summary>
    /// <remarks>
    /// Order milik sendiri tidak pernah ikut disiarkan, dan order yang sudah dipegang runner
    /// ini juga tidak. Penyaringan ada di sini, bukan di tampilan: daftar yang cuma dipangkas
    /// tampilan tetap terkirim utuh ke perangkatnya, dan isinya nama serta alamat orang.
    /// </remarks>
    [HttpGet("tersiar")]
    [Authorize(Roles = Peran.Runner)]
    public async Task<ActionResult<IReadOnlyList<OrderResponse>>> Tersiar(CancellationToken batal)
    {
        var runnerId = User.Id();

        var orders = await db.Orders
            .Include(o => o.RunnerAssignments)
            .Include(o => o.Client)
            .Where(o => o.Status == OrderStatus.MencariRunner)
            .Where(o => o.ClientId != runnerId)
            .Where(o => !o.RunnerAssignments.Any(a => a.RunnerId == runnerId))
            .Where(o => o.RunnerAssignments.Count < o.RequiredRunnerCount)
            .OrderByDescending(o => o.CreatedAt)
            .ToListAsync(batal);

        return Ok(orders.Select(o => OrderResponse.Dari(o, o.Client?.Name ?? "Klien")).ToList());
    }

    /// <summary>
    /// Runner menekan TERIMA. Inti teknis proyek (rencana capstone bagian 14.5).
    /// </summary>
    /// <remarks>
    /// Keatomikannya ditegakkan basis data, bukan urutan pemeriksaan di kode ini. Transaksi
    /// serializable membuat dua runner yang menekan pada detik yang sama tidak mungkin
    /// sama-sama lolos: salah satunya gagal serialisasi dan dijawab sebagai kalah cepat.
    /// Index unik pada (OrderId, RunnerId) menutup sisanya.
    ///
    /// Kalah cepat bukan galat, jadi tetap 200 dengan Dapat bernilai false. Yang melanggar
    /// aturan, yaitu pemesan menerima ordernya sendiri, dijawab 400.
    /// </remarks>
    [HttpPost("{id:guid}/terima")]
    [Authorize(Roles = Peran.Runner)]
    public async Task<ActionResult<TerimaOrderResponse>> Terima(Guid id, CancellationToken batal)
    {
        var runnerId = User.Id();

        await using var transaksi = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, batal);

        var order = await db.Orders
            .Include(o => o.RunnerAssignments)
            .SingleOrDefaultAsync(o => o.Id == id, batal);

        if (order is null) return NotFound();

        // Pemesan tidak boleh jadi runner ordernya sendiri. Akun yang memegang peran klien
        // sekaligus runner membuat ini mungkin secara teknis, dan membiarkannya berarti
        // membuka jalan memesan lalu menerima sendiri, menagih upah atas pekerjaan yang
        // tidak pernah berpindah tangan.
        if (order.ClientId == runnerId)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Tidak bisa menerima order sendiri",
                Detail = "Order ini kamu sendiri yang memesan.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        if (order.Status != OrderStatus.MencariRunner)
        {
            return Ok(new TerimaOrderResponse(false, "Order ini sudah tidak mencari runner."));
        }

        if (order.RunnerAssignments.Any(a => a.RunnerId == runnerId))
        {
            return Ok(new TerimaOrderResponse(false, "Kamu sudah memegang order ini."));
        }

        if (order.RunnerAssignments.Count >= order.RequiredRunnerCount)
        {
            return Ok(new TerimaOrderResponse(false, "Kuota runner sudah penuh."));
        }

        db.OrderRunnerAssignments.Add(new OrderRunnerAssignment
        {
            OrderId = order.Id,
            RunnerId = runnerId,
        });

        if (order.RunnerAssignments.Count + 1 >= order.RequiredRunnerCount)
        {
            order.Status = OrderStatus.Dikerjakan;
        }

        try
        {
            await db.SaveChangesAsync(batal);
            await transaksi.CommitAsync(batal);
        }
        catch (Exception galat) when (KalahCepat(galat))
        {
            await transaksi.RollbackAsync(batal);
            return Ok(new TerimaOrderResponse(false, "Order ini keburu diambil runner lain."));
        }

        return Ok(new TerimaOrderResponse(true, "Order jadi milikmu."));
    }

    /// <summary>
    /// Benar kalau galatnya berarti runner ini kalah lomba, bukan ada yang rusak.
    ///
    /// 40001 adalah kegagalan serialisasi, yaitu dua transaksi yang tidak bisa diurutkan.
    /// 23505 adalah pelanggaran index unik, yaitu runner yang sama menyelip dua kali.
    /// Keduanya hasil yang wajar di sini dan tidak boleh muncul sebagai galat server.
    /// </summary>
    private static bool KalahCepat(Exception galat) =>
        galat is DbUpdateConcurrencyException
        || (galat.InnerException ?? galat) is PostgresException
        {
            SqlState: PostgresErrorCodes.SerializationFailure or PostgresErrorCodes.UniqueViolation,
        };
}
