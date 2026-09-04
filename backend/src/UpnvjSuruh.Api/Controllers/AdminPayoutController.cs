using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Payouts;

namespace UpnvjSuruh.Api.Controllers;

/// <summary>
/// Rekap pembayaran runner, dan rumus bagi hasil yang mendasarinya.
/// </summary>
/// <remarks>
/// Seluruh permukaannya dijaga peran admin di level controller, tidak seperti
/// <see cref="TarifController"/> yang sisi bacanya sengaja terbuka untuk klien. Bedanya ada pada
/// siapa yang butuh: tarif dibaca klien untuk tahu berapa ia akan ditagih sebelum memesan,
/// sedangkan rumus bagi hasil tidak punya pembaca di luar admin. Runner melihat rupiah miliknya
/// sendiri lewat <see cref="PendapatanController"/>, yaitu angka yang sudah dibekukan, bukan
/// rumus yang melahirkannya, dan berapa margin organisasi bukan bagian dari pertanyaan itu.
/// </remarks>
[ApiController]
[Route("api/admin/payout")]
[Authorize(Roles = Peran.Admin)]
public class AdminPayoutController(AppDbContext db, ILogger<AdminPayoutController> log) : ControllerBase
{
    /// <summary>Rumus bagi hasil yang sedang berlaku.</summary>
    [HttpGet("setting")]
    public async Task<ActionResult<PayoutSettingResponse>> AmbilSetting(CancellationToken batal)
    {
        var setting = await db.PayoutSettings.SingleAsync(p => p.Id == PayoutSetting.SatuSatunyaId, batal);
        return Ok(PayoutSettingResponse.Dari(setting));
    }

    /// <summary>Menyimpan rumus bagi hasil, lalu menyusul bayaran yang menunggu rumus itu.</summary>
    /// <remarks>
    /// Penyimpanan pertama tidak cuma mengisi satu baris. Order yang sudah selesai selagi rumusnya
    /// belum ada meninggalkan bayaran yang belum dihitung, dan yang seperti itu ikut dihitung di
    /// sini, dalam penyimpanan yang sama dengan rumusnya. Kalau tidak, runner yang bekerja sebelum
    /// admin sempat mengisi form ini tidak akan pernah dibayar oleh sistem, dan tidak ada satu pun
    /// layar yang akan menunjukkan bahwa ia terlewat.
    ///
    /// Bayaran yang sudah pernah dibekukan tidak ikut dihitung ulang (dijaga
    /// <see cref="PembekuPayout"/>), jadi penyimpanan kedua dan seterusnya cuma mengubah rumus
    /// untuk order yang selesai sesudahnya. Itu ditulis terang-terangan di layar admin juga,
    /// bukan cuma di sini.
    /// </remarks>
    [HttpPut("setting")]
    public async Task<ActionResult<PayoutSettingResponse>> PerbaruiSetting(
        PerbaruiPayoutSettingRequest permintaan,
        CancellationToken batal)
    {
        var setting = await db.PayoutSettings.SingleAsync(p => p.Id == PayoutSetting.SatuSatunyaId, batal);

        setting.Mode = permintaan.Mode;
        setting.KomisiPersen = permintaan.KomisiPersen;
        setting.KomisiTetap = permintaan.KomisiTetap;
        setting.DiaturPada = DateTime.UtcNow;
        setting.DiaturOlehAdminId = User.Id();

        // Cuma order yang benar-benar punya bayaran menggantung yang dimuat, bukan seluruh order
        // selesai: sesudah penyimpanan pertama, daftar ini praktis selalu kosong, dan kueri yang
        // menyaringnya di basis data tidak ikut jadi lebih mahal seiring bertambahnya riwayat.
        var menunggu = await db.Orders
            .Where(o => o.Status == OrderStatus.Selesai
                        && o.Price != null
                        && o.RunnerAssignments.Any(a => a.PayoutAmount == null))
            .Include(o => o.RunnerAssignments)
            .ToListAsync(batal);

        var disusulkan = menunggu.Sum(o => PembekuPayout.Bekukan(o, setting));

        await db.SaveChangesAsync(batal);

        if (disusulkan > 0)
        {
            log.LogInformation(
                "Rumus bagi hasil disimpan, {Jumlah} bayaran yang menunggu ikut dihitung.", disusulkan);
        }

        return Ok(PayoutSettingResponse.Dari(setting));
    }

    /// <summary>Siapa harus dibayar berapa.</summary>
    /// <remarks>
    /// Dijawab satu kueri agregat, bukan dengan memuat tiap penugasan lalu menjumlahkannya di
    /// memori. Yang dibaca layar ini adalah seluruh riwayat penugasan yang pernah ada, dan itu
    /// bagian yang tumbuh terus; menjumlahkannya di sisi aplikasi berarti memindahkan seluruh
    /// riwayat itu lewat jaringan setiap kali admin membuka halamannya.
    /// </remarks>
    [HttpGet("rekap")]
    public async Task<ActionResult<RekapPayoutResponse>> Rekap(CancellationToken batal)
    {
        var setting = await db.PayoutSettings.SingleAsync(p => p.Id == PayoutSetting.SatuSatunyaId, batal);

        var baris = await db.OrderRunnerAssignments
            .Where(a => a.Order!.Status == OrderStatus.Selesai)
            .GroupBy(a => a.RunnerId)
            .Select(g => new
            {
                RunnerId = g.Key,
                JumlahOrderBelumDibayar = g.Count(a => a.PayoutSettledAt == null && a.PayoutAmount != null),
                TotalBelumDibayar = g
                    .Where(a => a.PayoutSettledAt == null && a.PayoutAmount != null)
                    .Sum(a => a.PayoutAmount) ?? 0m,
                TotalSudahDibayar = g
                    .Where(a => a.PayoutSettledAt != null)
                    .Sum(a => a.PayoutAmount) ?? 0m,
                MenungguRumus = g.Count(a => a.PayoutAmount == null),
                TerakhirDibayarPada = g.Max(a => a.PayoutSettledAt),
            })
            .ToListAsync(batal);

        // Nama dan nomor diambil terpisah, sesudah pengelompokan, bukan lewat gabungan di dalam
        // kueri agregatnya. Yang dibutuhkan cuma segelintir baris user (satu per runner yang
        // pernah menyelesaikan order), dan menggabungkannya lebih dulu berarti tabel user ikut
        // dibaca untuk setiap baris penugasan sepanjang riwayat.
        var runnerIds = baris.Select(b => b.RunnerId).ToList();
        var pemilik = await db.Users
            .Where(u => runnerIds.Contains(u.Id))
            .Select(u => new { u.Id, u.Name, u.Phone })
            .ToDictionaryAsync(u => u.Id, batal);

        var rekap = baris
            .Select(b => new RekapRunnerResponse(
                b.RunnerId,
                pemilik.TryGetValue(b.RunnerId, out var u) ? u.Name : "Runner",
                pemilik.TryGetValue(b.RunnerId, out var v) ? v.Phone : "",
                b.JumlahOrderBelumDibayar,
                b.TotalBelumDibayar,
                b.TotalSudahDibayar,
                b.MenungguRumus,
                b.TerakhirDibayarPada))
            // Yang paling besar tagihannya di atas: itulah urutan yang dipakai orang yang sedang
            // memutuskan siapa dibayar lebih dulu ketika uangnya belum cukup untuk semua.
            .OrderByDescending(r => r.TotalBelumDibayar)
            .ThenBy(r => r.Nama)
            .ToList();

        return Ok(new RekapPayoutResponse(
            PayoutSettingResponse.Dari(setting),
            rekap,
            rekap.Sum(r => r.TotalBelumDibayar),
            rekap.Sum(r => r.MenungguRumus)));
    }

    /// <summary>Order mana saja yang membentuk tagihan seorang runner.</summary>
    [HttpGet("rekap/{runnerId:guid}")]
    public async Task<ActionResult<RincianPayoutResponse>> Rincian(
        Guid runnerId,
        [FromQuery] PermintaanHalaman halaman,
        CancellationToken batal)
    {
        var runner = await db.Users.SingleOrDefaultAsync(u => u.Id == runnerId, batal);
        if (runner is null) return NotFound();

        var selesai = db.OrderRunnerAssignments
            .Where(a => a.RunnerId == runnerId && a.Order!.Status == OrderStatus.Selesai);

        // Yang belum dibayar dikirim seluruhnya, tanpa halaman. Ini angka yang dijumlahkan admin
        // sebelum menyerahkan uang, dan jumlah yang cuma sebagian bukan jumlah.
        var belum = await selesai
            .Where(a => a.PayoutSettledAt == null)
            .OrderByDescending(a => a.Order!.CompletedAt)
            .AmbilBarisAsync(batal);

        var sudahKueri = selesai.Where(a => a.PayoutSettledAt != null);
        var totalSudah = await sudahKueri.CountAsync(batal);
        var jumlahSudah = await sudahKueri.SumAsync(a => a.PayoutAmount, batal) ?? 0m;

        var sudah = await sudahKueri
            .OrderByDescending(a => a.PayoutSettledAt)
            .Skip(halaman.Dilewati)
            .Take(halaman.Ukuran)
            .AmbilBarisAsync(batal);

        return Ok(new RincianPayoutResponse(
            runnerId,
            runner.Name,
            runner.Phone,
            belum,
            belum.Sum(b => b.Jumlah ?? 0m),
            new HalamanResponse<BarisPayoutResponse>(sudah, totalSudah, halaman.Halaman, halaman.Ukuran),
            jumlahSudah));
    }

    /// <summary>Menandai bayaran yang disebut sudah diserahkan ke runner.</summary>
    /// <remarks>
    /// Menolak seluruh permintaan kalau ada satu saja id yang tidak memenuhi syarat, bukan
    /// mengerjakan yang bisa lalu melewatkan sisanya. Yang ditandai di sini adalah pengakuan bahwa
    /// uang sungguhan sudah berpindah tangan, dan pengakuan yang cuma sebagian berhasil
    /// meninggalkan admin dengan pertanyaan yang paling tidak enak: yang mana tadi yang jadi.
    ///
    /// Ketiga syaratnya dijawab dengan keterangan yang berbeda-beda, karena ketiganya menuntut
    /// tindakan yang berbeda dari admin. Ini bukan permukaan yang perlu irit bicara: seluruh
    /// controller ini cuma untuk admin, jadi keterangan yang jelas di sini tidak membocorkan apa
    /// pun kepada siapa pun yang belum boleh melihatnya.
    /// </remarks>
    [HttpPost("rekap/{runnerId:guid}/lunas")]
    public async Task<ActionResult<TandaiLunasResponse>> TandaiLunas(
        Guid runnerId,
        TandaiLunasRequest permintaan,
        CancellationToken batal)
    {
        var ids = permintaan.PenugasanIds.Distinct().ToList();

        var penugasan = await db.OrderRunnerAssignments
            .Where(a => ids.Contains(a.Id))
            .ToListAsync(batal);

        // Id yang bukan milik runner ini dijawab sama dengan id yang tidak ada sama sekali, supaya
        // jawabannya tidak jadi alat untuk memastikan sebuah id itu ada.
        var milikRunner = penugasan.Where(a => a.RunnerId == runnerId).ToList();
        if (milikRunner.Count != ids.Count)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Ada bayaran yang tidak dikenali",
                Detail = "Muat ulang rekapnya, lalu tandai lagi dari daftar yang baru.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        if (milikRunner.Any(a => a.PayoutSettledAt != null))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Ada bayaran yang sudah pernah ditandai lunas",
                Detail = "Muat ulang rekapnya supaya tidak ada yang terbayar dua kali.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        if (milikRunner.Any(a => a.PayoutAmount is null))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Ada bayaran yang belum dihitung",
                Detail = "Simpan dulu rumus bagi hasilnya, baru bayaran itu punya angka untuk dilunasi.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        var sekarang = DateTime.UtcNow;
        foreach (var a in milikRunner)
        {
            a.PayoutSettledAt = sekarang;
            a.PayoutSettledByAdminId = User.Id();
        }

        await db.SaveChangesAsync(batal);

        return Ok(new TandaiLunasResponse(
            milikRunner.Count,
            milikRunner.Sum(a => a.PayoutAmount ?? 0m),
            sekarang));
    }
}
