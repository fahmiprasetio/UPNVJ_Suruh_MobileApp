using System.Globalization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
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
    IPembatasOtp pembatasOtp,
    IPembuatKodeOtp pembuatKode,
    IPengirimOtp pengirimOtp) : ControllerBase
{
    /// <summary>
    /// Mendaftarkan akun baru. Selalu lahir sebagai klien, lihat <see cref="DaftarRequest"/>.
    /// </summary>
    /// <remarks>
    /// Selalu menjawab 202 tanpa badan, terdaftar maupun tidak, persis seperti
    /// <see cref="MintaKode"/>.
    ///
    /// Dulu endpoint ini menjawab 409 "Nomor sudah terdaftar", dan itu membuka kembali persis
    /// kebocoran yang ditutup dengan susah payah di sebelahnya. Minta-kode sengaja menjawab
    /// sama untuk semua nomor supaya ia tidak bisa dipakai memeriksa siapa saja yang punya
    /// akun; kalau endpoint di sebelahnya menjawab berbeda untuk pertanyaan yang sama, pintu
    /// itu tidak pernah benar-benar tertutup. Cukup coba daftar dengan nomor seseorang, dan
    /// jawabannya menyebutkan apakah ia pelanggan di sini.
    ///
    /// Karena jawabannya harus sama, ia tidak boleh memuat apa pun tentang akunnya. Bukan
    /// data akun yang baru dibuat, dan sudah pasti bukan data akun yang sudah ada: nama
    /// pemiliknya adalah hal terakhir yang boleh diserahkan kepada orang yang cuma menebak
    /// nomor. Yang sudah punya akun tidak diubah apa-apa, termasuk namanya.
    ///
    /// Bagi pendaftar yang sah, tidak ada yang hilang. Langkah berikutnya tetap sama:
    /// minta kode, lalu masuk. Yang nomornya ternyata sudah terdaftar akan menerima kode ke
    /// nomor itu juga, dan masuk ke akun yang memang miliknya.
    ///
    /// Tidak ada kode yang dikirim dari sini. Yang mengirim kode tetap satu endpoint saja,
    /// dan batas per nomor di sana yang menjaganya dari dipakai membanjiri ponsel orang.
    /// </remarks>
    [EnableRateLimiting(BatasLaju.KebijakanTamu)]
    [HttpPost("daftar")]
    [ProducesResponseType(StatusCodes.Status202Accepted)]
    public async Task<IActionResult> Daftar(DaftarRequest permintaan, CancellationToken batal)
    {
        var noHp = permintaan.NoHp.Trim();

        // Nomor yang sudah punya akun berhenti di sini tanpa jejak di jawaban. Yang
        // benar-benar menjaga tetap index unik di kolom Phone, karena dua pendaftaran yang
        // tiba bersamaan sama-sama lolos pemeriksaan yang cuma membaca.
        if (await db.Users.AnyAsync(u => u.Phone == noHp, batal)) return Accepted();

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
            // jadi keduanya sama-sama lolos. Berakhir sama dengan nomor yang memang sudah
            // terdaftar, karena dari luar keadaannya memang sama.
        }

        return Accepted();
    }

    /// <summary>
    /// Meminta kode masuk dikirim ke nomor tersebut.
    /// </summary>
    /// <remarks>
    /// Selalu menjawab 202, terdaftar maupun tidak. Jawaban yang berbeda untuk nomor yang ada
    /// dan tidak ada mengubah endpoint ini jadi alat memeriksa siapa saja yang punya akun,
    /// cukup dengan mencoba nomor satu per satu.
    ///
    /// Dibatasi per nomor HP, bukan cuma per pemanggil. Endpoint inilah yang membuat SMS
    /// terkirim, dan SMS itu sampai ke ponsel orang lain serta ditagihkan penyedia ke mitra.
    /// Yang harus dijaga karena itu adalah nomor penerimanya, bukan alamat pengirimnya:
    /// penyerang berganti IP semudah berpindah jaringan, dan tidak satu pun pergantian itu
    /// mengubah siapa yang ponselnya berdering.
    /// </remarks>
    [EnableRateLimiting(BatasLaju.KebijakanTamu)]
    [HttpPost("minta-kode")]
    [ProducesResponseType(StatusCodes.Status202Accepted)]
    [ProducesResponseType(StatusCodes.Status429TooManyRequests)]
    public async Task<IActionResult> MintaKode(MintaKodeRequest permintaan, CancellationToken batal)
    {
        var noHp = permintaan.NoHp.Trim();

        // Diperiksa sebelum basis data disentuh, dan berlaku untuk nomor mana pun.
        //
        // Membatasi hanya nomor yang terdaftar akan mengembalikan kebocoran yang ditutup
        // dengan menjawab 202 untuk semua orang: 429 yang cuma muncul pada sebagian nomor
        // adalah cara memeriksa siapa saja yang punya akun, cukup dengan mencoba nomor satu
        // per satu sampai ada yang menjawab berbeda.
        var izin = pembatasOtp.Catat(noHp);
        if (!izin.Boleh)
        {
            // Invariant, bukan budaya mesin. Nilai header HTTP bukan teks untuk dibaca
            // orang, dan budaya yang memakai pemisah lain akan menghasilkan header yang
            // tidak bisa diurai klien mana pun.
            Response.Headers.RetryAfter = ((int)Math.Ceiling(izin.TungguLagi.TotalSeconds))
                .ToString(CultureInfo.InvariantCulture);

            return StatusCode(StatusCodes.Status429TooManyRequests, new ProblemDetails
            {
                Title = "Terlalu sering meminta kode",
                Detail = "Kode masuk sudah dikirim beberapa kali ke nomor ini. "
                         + "Tunggu sebentar sebelum meminta lagi.",
                Status = StatusCodes.Status429TooManyRequests,
            });
        }

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
    [EnableRateLimiting(BatasLaju.KebijakanTamu)]
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

    /// <summary>Siapa pemilik token yang sedang dipakai.</summary>
    /// <remarks>
    /// Dipanggil aplikasi saat dibuka kembali, ketika ia punya token tersimpan tapi belum
    /// tahu itu milik siapa. Sengaja tidak menerima id sebagai parameter: yang ditanyakan
    /// adalah pemilik token ini, dan menerima id berarti membuat endpoint yang bisa dipakai
    /// membaca data akun orang lain.
    ///
    /// Perannya dibaca ulang dari basis data, bukan dari klaim di dalam token, karena peran
    /// bisa berubah setelah tokennya terbit: seseorang yang baru diangkat jadi runner tidak
    /// perlu menunggu tokennya kedaluwarsa untuk melihat permukaan runner, dan yang baru
    /// dicabut perannya tidak boleh terus melihatnya.
    /// </remarks>
    [Authorize]
    [HttpGet("saya")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<UserResponse>> Saya(CancellationToken batal)
    {
        var user = await db.Users.SingleOrDefaultAsync(u => u.Id == User.Id(), batal);

        // Token yang sah untuk akun yang sudah tidak ada diperlakukan sebagai tidak berwenang,
        // bukan sebagai tidak ditemukan. Bagi aplikasi keduanya berujung sama, yaitu masuk
        // lagi, dan 401 adalah jawaban yang sudah ditangani lapisan HTTP-nya.
        return user is null ? Unauthorized() : Ok(UserResponse.Dari(user));
    }
}
