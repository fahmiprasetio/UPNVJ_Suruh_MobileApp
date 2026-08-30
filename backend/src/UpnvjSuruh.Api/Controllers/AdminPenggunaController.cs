using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
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
public class AdminPenggunaController(AppDbContext db) : ControllerBase
{
    /// <summary>Mencari pengguna, untuk dashboard admin.</summary>
    /// <remarks>
    /// Menuntut kata kunci, dan tidak menyediakan cara mengambil seluruh daftar. Dashboard
    /// mencari orang tertentu untuk diangkat jadi runner; menumpahkan seluruh nomor HP
    /// pelanggan ke satu jawaban bukan bagian dari pekerjaan itu.
    /// </remarks>
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<UserResponse>>> Cari(
        [FromQuery] string? q,
        CancellationToken batal)
    {
        var kunci = (q ?? string.Empty).Trim();
        if (kunci.Length < 3)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Kata kunci terlalu pendek",
                Detail = "Isi minimal 3 huruf dari nama atau nomor HP-nya.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        var pengguna = await db.Users
            .Where(u => EF.Functions.ILike(u.Name, $"%{kunci}%") || u.Phone.Contains(kunci))
            .OrderBy(u => u.Name)
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
