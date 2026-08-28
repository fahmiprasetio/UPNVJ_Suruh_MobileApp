using System.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Media;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Pricing;

namespace UpnvjSuruh.Api.Controllers;

[ApiController]
[Route("api/orders")]
[Authorize]
public class OrdersController(
    AppDbContext db,
    IKalkulatorTarif kalkulator,
    PenyimpanFoto penyimpanFoto) : ControllerBase
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
            .Include(o => o.Offers)
            .Include(o => o.Client)
            .SingleOrDefaultAsync(o => o.Id == id, batal);

        if (order is null) return NotFound();

        if (!AksesOrder.BolehLihat(order, User.Id(), User)) return NotFound();

        return Ok(OrderResponse.Dari(
            order, order.Client?.Name ?? "Klien", await db.JumlahPesanAsync(order.Id, batal)));
    }

    /// <summary>Order milik klien yang sedang masuk, terbaru di atas.</summary>
    [HttpGet("saya")]
    [Authorize(Roles = Peran.Klien)]
    public async Task<ActionResult<IReadOnlyList<OrderResponse>>> Saya(CancellationToken batal)
    {
        var klienId = User.Id();

        var orders = await db.Orders
            .Include(o => o.RunnerAssignments)
            .Include(o => o.Offers)
            .Include(o => o.Client)
            .Where(o => o.ClientId == klienId)
            .OrderByDescending(o => o.CreatedAt)
            .ToListAsync(batal);

        var jumlahPesan = await db.JumlahPesanAsync([.. orders.Select(o => o.Id)], batal);
        return Ok(orders
            .Select(o => OrderResponse.Dari(
                o, o.Client?.Name ?? "Klien", jumlahPesan.GetValueOrDefault(o.Id)))
            .ToList());
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
            .Include(o => o.Offers)
            .Include(o => o.Client)
            .Where(o => o.Status == OrderStatus.MencariRunner)
            .Where(o => o.ClientId != runnerId)
            .Where(o => !o.RunnerAssignments.Any(a => a.RunnerId == runnerId))
            .Where(o => o.RunnerAssignments.Count < o.RequiredRunnerCount)
            .OrderByDescending(o => o.CreatedAt)
            .ToListAsync(batal);

        var jumlahPesan = await db.JumlahPesanAsync([.. orders.Select(o => o.Id)], batal);
        return Ok(orders
            .Select(o => OrderResponse.Dari(
                o, o.Client?.Name ?? "Klien", jumlahPesan.GetValueOrDefault(o.Id)))
            .ToList());
    }

    /// <summary>Order yang sedang dipegang runner yang masuk, terbaru di atas.</summary>
    /// <remarks>
    /// Termasuk yang sudah selesai, karena runner perlu melihat riwayat pekerjaannya sendiri.
    /// Yang memisahkan "sedang dikerjakan" dari "sudah selesai" adalah statusnya, dan itu
    /// pekerjaan tampilan, bukan alasan membuat dua endpoint.
    /// </remarks>
    [HttpGet("runner-saya")]
    [Authorize(Roles = Peran.Runner)]
    public async Task<ActionResult<IReadOnlyList<OrderResponse>>> RunnerSaya(CancellationToken batal)
    {
        var runnerId = User.Id();

        var orders = await db.Orders
            .Include(o => o.RunnerAssignments)
            .Include(o => o.Offers)
            .Include(o => o.Client)
            .Where(o => o.RunnerAssignments.Any(a => a.RunnerId == runnerId))
            .OrderByDescending(o => o.CreatedAt)
            .ToListAsync(batal);

        var jumlahPesan = await db.JumlahPesanAsync([.. orders.Select(o => o.Id)], batal);
        return Ok(orders
            .Select(o => OrderResponse.Dari(
                o, o.Client?.Name ?? "Klien", jumlahPesan.GetValueOrDefault(o.Id)))
            .ToList());
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

        // Seluruh transaksinya dibungkus, bukan cuma penyimpanannya.
        //
        // Di isolasi serializable, Postgres boleh menolak transaksi mana pun yang tidak bisa
        // diurutkan, dan penolakan itu bisa muncul di perintah apa pun, termasuk SELECT.
        // Versi sebelumnya cuma menjaga SaveChanges, jadi kegagalan yang mengenai pembacaan
        // lolos keluar sebagai galat server, dan runner yang cuma kalah cepat melihat
        // aplikasinya rusak.
        try
        {
            return await Jalankan(id, runnerId, batal);
        }
        catch (Exception galat) when (GalatDb.KalahCepat(galat))
        {
            return Ok(new TerimaOrderResponse(false, "Order ini keburu diambil runner lain."));
        }
    }

    private async Task<ActionResult<TerimaOrderResponse>> Jalankan(
        Guid id,
        Guid runnerId,
        CancellationToken batal)
    {
        await using var transaksi = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, batal);

        var order = await db.Orders
            .Include(o => o.RunnerAssignments)
            .Include(o => o.Offers)
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

        await db.SaveChangesAsync(batal);
        await transaksi.CommitAsync(batal);

        return Ok(new TerimaOrderResponse(true, "Order jadi milikmu."));
    }

    /// <summary>
    /// Runner menandai pekerjaannya selesai.
    /// </summary>
    /// <remarks>
    /// Yang berhak menutup order hanya runner yang memegangnya. Pemeriksaan itu tempatnya di
    /// sini, bukan di tampilan: tombol yang disembunyikan tidak menghentikan siapa pun yang
    /// memanggil langsung.
    ///
    /// Foto bukti wajib ada, dan itu yang membedakan pekerjaan selesai dari pengakuan
    /// selesai.
    ///
    /// Pada order multi-runner, runner mana pun yang ditugaskan boleh menutupnya. Itu
    /// keputusan sementara: siapa yang berhak menekan selesai kalau pekerjaannya dibagi tiga
    /// orang masih menunggu jawaban mitra (rencana capstone bagian 14.7d).
    /// </remarks>
    [HttpPost("{id:guid}/selesai")]
    [Authorize(Roles = Peran.Runner)]
    public async Task<ActionResult<OrderResponse>> Selesaikan(
        Guid id,
        SelesaikanOrderRequest permintaan,
        CancellationToken batal)
    {
        var runnerId = User.Id();

        var order = await db.Orders
            .Include(o => o.RunnerAssignments)
            .Include(o => o.Offers)
            .Include(o => o.Client)
            .SingleOrDefaultAsync(o => o.Id == id, batal);

        if (order is null) return NotFound();

        var penugasan = order.RunnerAssignments.SingleOrDefault(a => a.RunnerId == runnerId);
        // Yang tidak memegang order ini tidak berhak tahu bahwa ordernya ada.
        if (penugasan is null) return NotFound();

        if (order.Status != OrderStatus.Dikerjakan)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Order belum dikerjakan",
                Detail = $"Order ini sedang {order.Status}, jadi belum bisa diselesaikan.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        // Foto buktinya harus benar-benar foto yang pernah diunggah ke server ini lewat
        // endpoint unggah, bukan sekadar tulisan di kolom foto. Tanpa pemeriksaan ini,
        // runner yang tidak mengerjakan apa-apa bisa menutup order dengan menempelkan
        // tautan gambar mana pun dari internet, dan "wajib ada foto bukti" kehilangan
        // seluruh artinya.
        if (!penyimpanFoto.Sah(permintaan.FotoBuktiUrl))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Foto buktinya tidak dikenali",
                Detail = "Unggah fotonya dulu lewat POST /api/orders/{id}/foto-bukti, "
                         + "lalu kirim URL yang dikembalikan endpoint itu.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        var sekarang = DateTime.UtcNow;
        penugasan.MarkedDoneAt = sekarang;
        penugasan.CompletionPhotoUrl = permintaan.FotoBuktiUrl.Trim();

        order.Status = OrderStatus.Selesai;
        order.CompletedAt = sekarang;
        order.PhotoUrl = permintaan.FotoBuktiUrl.Trim();
        order.HandoverNote = permintaan.CatatanSerahTerima?.Trim();

        await db.SaveChangesAsync(batal);
        return Ok(OrderResponse.Dari(
            order, order.Client?.Name ?? "Klien", await db.JumlahPesanAsync(order.Id, batal)));
    }

    /// <summary>
    /// Membatalkan order.
    /// </summary>
    /// <remarks>
    /// Yang boleh membatalkan hanya pemesannya dan admin. Runner tidak, walaupun ia sedang
    /// memegangnya: runner yang tidak jadi mengerjakan adalah urusan yang perlu diketahui
    /// admin, bukan tombol yang menghapus pekerjaan orang lain.
    ///
    /// Order yang sudah dibayar tidak bisa dibatalkan lewat sini, karena membatalkannya
    /// berarti ada uang yang harus kembali, dan pengembalian uang bukan sesuatu yang boleh
    /// terjadi sebagai efek samping satu tombol.
    /// </remarks>
    [HttpPost("{id:guid}/batal")]
    public async Task<ActionResult<OrderResponse>> Batalkan(Guid id, CancellationToken batal)
    {
        var order = await db.Orders
            .Include(o => o.RunnerAssignments)
            .Include(o => o.Offers)
            .Include(o => o.Client)
            .SingleOrDefaultAsync(o => o.Id == id, batal);

        if (order is null) return NotFound();

        var pemanggil = User.Id();
        if (order.ClientId != pemanggil && !User.Punya(Peran.Admin)) return NotFound();

        if (!order.Status.Aktif())
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Order sudah berakhir",
                Detail = $"Order ini sudah {order.Status}.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        if (order.PaidAt is not null)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Order ini sudah dibayar",
                Detail = "Pembatalan setelah pembayaran menyangkut pengembalian uang, "
                         + "jadi harus lewat admin.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        order.Status = OrderStatus.Batal;

        await db.SaveChangesAsync(batal);
        return Ok(OrderResponse.Dari(
            order, order.Client?.Name ?? "Klien", await db.JumlahPesanAsync(order.Id, batal)));
    }
}
