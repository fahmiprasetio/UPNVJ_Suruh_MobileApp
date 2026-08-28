using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController(
    AppDbContext db,
    ITokenService token,
    IPenyimpanOtp penyimpanOtp,
    IPembuatKodeOtp pembuatKode,
    IPengirimOtp pengirimOtp) : ControllerBase
{
    /// <summary>
    /// Mendaftarkan akun baru. Selalu lahir sebagai klien, lihat <see cref="DaftarRequest"/>.
    /// </summary>
    [HttpPost("daftar")]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<UserResponse>> Daftar(DaftarRequest permintaan, CancellationToken batal)
    {
        var noHp = permintaan.NoHp.Trim();

        // Pemeriksaan ini demi pesan galat yang enak dibaca. Yang benar-benar menjaga adalah
        // index unik di kolom Phone, karena dua pendaftaran yang tiba bersamaan sama-sama
        // lolos pemeriksaan yang cuma membaca.
        if (await db.Users.AnyAsync(u => u.Phone == noHp, batal))
        {
            return Conflict(new ProblemDetails
            {
                Title = "Nomor sudah terdaftar",
                Detail = "Nomor ini sudah punya akun. Masuk saja, tidak perlu mendaftar lagi.",
                Status = StatusCodes.Status409Conflict,
            });
        }

        var user = new User
        {
            Name = permintaan.Nama.Trim(),
            Phone = noHp,
            // Ditulis di sini, tidak pernah diambil dari permintaan.
            Roles = [UserRole.Klien],
        };

        db.Users.Add(user);

        try
        {
            await db.SaveChangesAsync(batal);
        }
        catch (DbUpdateException galat) when (GalatDb.Bentrok(galat))
        {
            // Kalah cepat dengan pendaftaran lain untuk nomor yang sama. Inilah sebabnya
            // pemeriksaan di atas saja tidak cukup: keduanya membaca sebelum ada yang menulis,
            // jadi keduanya sama-sama lolos.
            return Conflict(new ProblemDetails
            {
                Title = "Nomor sudah terdaftar",
                Status = StatusCodes.Status409Conflict,
            });
        }

        return CreatedAtAction(nameof(Daftar), UserResponse.Dari(user));
    }

    /// <summary>
    /// Meminta kode masuk dikirim ke nomor tersebut.
    /// </summary>
    /// <remarks>
    /// Selalu menjawab 202, terdaftar maupun tidak. Jawaban yang berbeda untuk nomor yang ada
    /// dan tidak ada mengubah endpoint ini jadi alat memeriksa siapa saja yang punya akun,
    /// cukup dengan mencoba nomor satu per satu.
    /// </remarks>
    [HttpPost("minta-kode")]
    [ProducesResponseType(StatusCodes.Status202Accepted)]
    public async Task<IActionResult> MintaKode(MintaKodeRequest permintaan, CancellationToken batal)
    {
        var noHp = permintaan.NoHp.Trim();
        var terdaftar = await db.Users.AnyAsync(u => u.Phone == noHp, batal);

        if (terdaftar)
        {
            var kode = pembuatKode.Buat();
            penyimpanOtp.Simpan(noHp, kode);
            await pengirimOtp.KirimAsync(noHp, kode, batal);
        }

        return Accepted();
    }

    /// <summary>
    /// Menukar kode yang benar dengan token.
    /// </summary>
    [HttpPost("masuk")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<MasukResponse>> Masuk(MasukRequest permintaan, CancellationToken batal)
    {
        var noHp = permintaan.NoHp.Trim();

        // Kodenya diperiksa lebih dulu, dan galatnya satu macam untuk semua sebab. Membedakan
        // "nomor tidak terdaftar" dari "kode salah" memberi tahu penyerang bahwa ia sudah
        // menebak setengah jawabannya.
        if (!penyimpanOtp.Pakai(noHp, permintaan.Kode))
        {
            return Unauthorized(new ProblemDetails
            {
                Title = "Nomor atau kode tidak cocok",
                Status = StatusCodes.Status401Unauthorized,
            });
        }

        var user = await db.Users.SingleOrDefaultAsync(u => u.Phone == noHp, batal);
        if (user is null)
        {
            return Unauthorized(new ProblemDetails
            {
                Title = "Nomor atau kode tidak cocok",
                Status = StatusCodes.Status401Unauthorized,
            });
        }

        var (nilai, kedaluwarsa) = token.Terbitkan(user);
        return Ok(new MasukResponse(nilai, kedaluwarsa, UserResponse.Dari(user)));
    }
}
