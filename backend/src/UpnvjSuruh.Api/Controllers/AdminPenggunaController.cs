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
/// Pemberian peran. Satu-satunya jalan seseorang bisa menjadi runner atau admin.
///
/// Inilah tempat yang dituju seluruh aturan "peran hanya diberikan admin". Pendaftaran
/// mandiri tidak punya field peran, kontrak mobile tidak punya method yang mengubahnya, dan
/// keduanya benar hanya kalau pintu satu-satunya ini memang dijaga.
///
/// Ini juga endpoint paling berbahaya di sistem: siapa pun yang bisa memanggilnya bisa
/// mengangkat dirinya sendiri jadi admin, lalu melakukan apa saja.
/// </summary>
[ApiController]
[Route("api/admin/pengguna")]
[Authorize(Roles = Peran.Admin)]
public class AdminPenggunaController(
    AppDbContext db,
    ILogger<AdminPenggunaController> log) : ControllerBase
{
    /// <summary>Mencari pengguna, untuk dashboard admin.</summary>
    /// <remarks>
    /// Menuntut kata kunci, dan tidak menyediakan cara mengambil seluruh daftar. Dashboard
    /// mencari orang tertentu untuk diangkat jadi runner; menumpahkan seluruh nomor HP
    /// pelanggan ke satu jawaban bukan bagian dari pekerjaan itu.
    ///
    /// Satu pengecualian: <c>tertangguh=true</c>. Penangguhan diberikan admin dan bisa
    /// dicabut admin, tapi sampai sekarang satu-satunya jalan menemukan akunnya kembali
    /// adalah mengingat namanya. Admin yang menangguhkan seseorang hari ini dan diminta
    /// memulihkannya minggu depan tidak punya cara bertanya "siapa saja yang sedang
    /// berhenti" — dan itu pertanyaan yang justru menjadi pekerjaannya.
    ///
    /// Alasan kata kunci wajib tidak berlaku di sana. Yang dijaganya adalah nomor HP
    /// pelanggan yang tidak ada urusannya dengan siapa pun; akun yang ditangguhkan
    /// himpunan kecil, dibuat oleh admin sendiri, dan seluruhnya memang perlu ditinjau.
    /// Kata kunci tetap boleh dipakai bersamanya untuk mempersempit.
    /// </remarks>
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<UserResponse>>> Cari(
        [FromQuery] string? q,
        [FromQuery] bool tertangguh,
        CancellationToken batal)
    {
        var kunci = (q ?? string.Empty).Trim();
        if (!tertangguh && kunci.Length < 3)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Kata kunci terlalu pendek",
                Detail = "Isi minimal 3 huruf dari nama atau nomor HP-nya.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        var kueri = db.Users.AsQueryable();

        if (tertangguh) kueri = kueri.Where(u => u.SuspendedAt != null);

        // Kata kunci yang terlalu pendek diabaikan alih-alih ditolak saat menyaring yang
        // tertangguh: admin yang baru mengetik satu huruf sedang di tengah mengetik, dan
        // membalasnya dengan galat berarti daftar yang sudah tampil lenyap di huruf pertama.
        if (kunci.Length >= 3)
        {
            kueri = kueri.Where(u => EF.Functions.ILike(u.Name, $"%{kunci}%") || u.Phone.Contains(kunci));
        }

        // Yang tertangguh diurutkan dari yang terbaru: yang paling mungkin ditanyakan
        // adalah yang barusan dihentikan, bukan yang namanya berawalan A.
        // ponytail: dipotong 50 seperti pencarian biasa, tanpa halaman. Penangguhan dicabut
        // sesering ia diberikan, jadi daftarnya tidak tumbuh satu arah seperti catatan audit.
        var pengguna = await (tertangguh
                ? kueri.OrderByDescending(u => u.SuspendedAt)
                : kueri.OrderBy(u => u.Name))
            .Take(50)
            .ToListAsync(batal);

        return Ok(pengguna.Select(UserResponse.Dari).ToList());
    }

    /// <summary>Riwayat perubahan peran satu pengguna.</summary>
    /// <remarks>
    /// Berhalaman seperti daftar lain, walaupun satu akun biasanya cuma punya beberapa baris
    /// di sini. Alasannya bukan ukurannya sekarang melainkan sifatnya: catatan audit tidak
    /// pernah dihapus, jadi satu-satunya arah pertumbuhannya naik. Endpoint yang dibiarkan
    /// tanpa batas karena "isinya masih sedikit" adalah endpoint yang batasnya baru dicari
    /// setelah ada yang mengeluh.
    /// </remarks>
    [HttpGet("{id:guid}/peran/riwayat")]
    public async Task<ActionResult<HalamanResponse<PerubahanPeranResponse>>> Riwayat(
        Guid id,
        [FromQuery] PermintaanHalaman permintaan,
        CancellationToken batal)
    {
        var kueri = db.UserRoleChanges.Where(p => p.UserId == id);

        var total = await kueri.CountAsync(batal);
        var riwayat = await kueri
            .OrderByDescending(p => p.ChangedAt)
            .ThenByDescending(p => p.Id)
            .Skip(permintaan.Dilewati)
            .Take(permintaan.Ukuran)
            .ToListAsync(batal);

        return Ok(new HalamanResponse<PerubahanPeranResponse>(
            [.. riwayat.Select(PerubahanPeranResponse.Dari)],
            total,
            permintaan.Halaman,
            permintaan.Ukuran));
    }

    /// <summary>Menetapkan peran seseorang.</summary>
    /// <summary>Menangguhkan sebuah akun: pemiliknya tidak bisa memakai aplikasi sama sekali.</summary>
    /// <remarks>
    /// Sebelum ini tidak ada cara menghentikan akun. Yang bisa dilakukan admin cuma mengubah
    /// peran, dan peran tidak boleh kosong, jadi runner yang menyalahgunakan sistem masih
    /// bisa dicabut peran runnernya sementara klien yang memesan lalu meminta pembatalan
    /// berulang kali tidak bisa dihentikan dengan cara apa pun.
    ///
    /// Berlaku seketika, bukan setelah token lamanya kedaluwarsa: setiap permintaan membaca
    /// ulang akunnya saat tokennya divalidasi (lihat <c>OnTokenValidated</c> di Program.cs).
    /// Penjagaan yang baru berlaku sejam kemudian bukan penjagaan untuk hal yang alasannya
    /// penyalahgunaan.
    ///
    /// Ditangguhkan, bukan dihapus. Akun yang dihapus membawa serta seluruh ordernya, dan
    /// order yang hilang berarti riwayat pembayaran dan bayaran runner ikut hilang bersama
    /// jejaknya — justru pada akun yang paling mungkin dipersoalkan belakangan.
    ///
    /// ponytail: cuma penangguhan terakhir yang tersimpan, bukan riwayatnya. Kalau pola
    /// "ditangguhkan lalu dipulihkan berulang kali" jadi pertanyaan, yang dibutuhkan tabel
    /// tersendiri seperti <c>UserRoleChange</c>.
    /// </remarks>
    [EnableRateLimiting(BatasLaju.KebijakanTulis)]
    [HttpPost("{id:guid}/tangguhkan")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<UserResponse>> Tangguhkan(
        Guid id,
        TangguhkanAkunRequest permintaan,
        CancellationToken batal)
    {
        var user = await db.Users.SingleOrDefaultAsync(u => u.Id == id, batal);
        if (user is null) return NotFound();

        // Aturan yang sama persis dengan mencabut peran admin, dan alasannya sama: yang
        // paling mungkin melakukannya orang yang salah menekan sambil menyunting akunnya
        // sendiri, dan akibatnya ia langsung kehilangan akses ke satu-satunya layar yang
        // bisa mengembalikannya.
        if (id == User.Id())
        {
            return Salah(
                "Tidak bisa menangguhkan akun sendiri",
                "Minta admin lain yang melakukannya.");
        }

        if (user.Roles.Contains(UserRole.Admin))
        {
            var sisaAdmin = await db.Users.CountAsync(
                u => u.Id != id && u.Roles.Contains(UserRole.Admin) && u.SuspendedAt == null,
                batal);

            if (sisaAdmin == 0)
            {
                return Salah(
                    "Ini admin terakhir yang masih berlaku",
                    "Angkat admin lain dulu sebelum menangguhkan yang ini.");
            }
        }

        if (user.Ditangguhkan) return Ok(UserResponse.Dari(user));

        user.SuspendedAt = DateTime.UtcNow;
        user.SuspendedReason = permintaan.Alasan.Trim();
        user.SuspendedByAdminId = User.Id();

        await db.SaveChangesAsync(batal);

        log.LogWarning(
            "Akun {UserId} ditangguhkan oleh admin {AdminId}.", user.Id, User.Id());

        return Ok(UserResponse.Dari(user));
    }

    /// <summary>Memulihkan akun yang ditangguhkan.</summary>
    /// <remarks>
    /// Alasannya wajib juga, bukan cuma saat menangguhkan. Keputusan mengembalikan akses
    /// kepada orang yang pernah dihentikan sama layaknya punya sebab tercatat dengan
    /// keputusan menghentikannya.
    /// </remarks>
    [EnableRateLimiting(BatasLaju.KebijakanTulis)]
    [HttpPost("{id:guid}/pulihkan")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<UserResponse>> Pulihkan(
        Guid id,
        TangguhkanAkunRequest permintaan,
        CancellationToken batal)
    {
        var user = await db.Users.SingleOrDefaultAsync(u => u.Id == id, batal);
        if (user is null) return NotFound();

        if (!user.Ditangguhkan)
        {
            return Salah(
                "Akun ini tidak sedang ditangguhkan",
                "Tidak ada yang perlu dipulihkan.");
        }

        user.SuspendedAt = null;
        user.SuspendedReason = null;
        user.SuspendedByAdminId = null;

        await db.SaveChangesAsync(batal);

        log.LogWarning(
            "Akun {UserId} dipulihkan oleh admin {AdminId}: {Alasan}",
            user.Id, User.Id(), permintaan.Alasan.Trim());

        return Ok(UserResponse.Dari(user));
    }

    [HttpPut("{id:guid}/peran")]
    public async Task<ActionResult<UserResponse>> TetapkanPeran(
        Guid id,
        TetapkanPeranRequest permintaan,
        CancellationToken batal)
    {
        var user = await db.Users.SingleOrDefaultAsync(u => u.Id == id, batal);
        if (user is null) return NotFound();

        var sebelum = user.Roles.Distinct().OrderBy(r => r).ToList();
        var sesudah = permintaan.Roles.Distinct().OrderBy(r => r).ToList();

        if (sesudah.Count == 0)
        {
            return Salah(
                "Peran tidak boleh kosong",
                "Akun tanpa peran tidak bisa membuka apa pun. Kalau maksudnya menutup akses, "
                + "yang dicabut cukup peran runner atau adminnya.");
        }

        var adminId = User.Id();

        // Admin tidak boleh mencabut peran adminnya sendiri.
        //
        // Bukan demi kenyamanan. Yang paling mungkin melakukannya adalah orang yang salah
        // menekan sambil menyunting akunnya sendiri, dan akibatnya ia langsung kehilangan
        // akses ke satu-satunya layar yang bisa mengembalikannya.
        if (id == adminId && !sesudah.Contains(UserRole.Admin))
        {
            return Salah(
                "Tidak bisa mencabut peran admin milik sendiri",
                "Minta admin lain yang melakukannya.");
        }

        // Dan admin terakhir tidak boleh dicabut oleh siapa pun.
        //
        // Sistem tanpa admin tidak punya jalan mengangkat admin baru lewat aplikasi sama
        // sekali; pemulihannya menuntut orang menyunting basis data langsung.
        if (sebelum.Contains(UserRole.Admin) && !sesudah.Contains(UserRole.Admin))
        {
            var sisaAdmin = await db.Users
                .CountAsync(u => u.Id != id && u.Roles.Contains(UserRole.Admin), batal);

            if (sisaAdmin == 0)
            {
                return Salah(
                    "Ini admin terakhir",
                    "Angkat admin lain dulu sebelum mencabut yang ini.");
            }
        }

        if (sebelum.SequenceEqual(sesudah))
        {
            // Tidak ada yang berubah, jadi tidak ada yang perlu dicatat. Catatan audit yang
            // penuh baris "tidak terjadi apa-apa" akan berhenti dibaca orang.
            return Ok(UserResponse.Dari(user));
        }

        user.Roles = sesudah;

        db.UserRoleChanges.Add(new UserRoleChange
        {
            UserId = user.Id,
            ChangedByAdminId = adminId,
            RolesBefore = sebelum,
            RolesAfter = sesudah,
            Reason = permintaan.Alasan.Trim(),
        });

        await db.SaveChangesAsync(batal);
        return Ok(UserResponse.Dari(user));
    }

    private ActionResult Salah(string judul, string detail) => BadRequest(new ProblemDetails
    {
        Title = judul,
        Detail = detail,
        Status = StatusCodes.Status400BadRequest,
    });
}
