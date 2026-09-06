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
    IPengirimOtp pengirimOtp,
    ILogger<AuthController> log) : ControllerBase
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
            return TerlaluSeringMintaKode(
                izin.TungguLagi,
                "Kode masuk sudah dikirim beberapa kali ke nomor ini. "
                + "Tunggu sebentar sebelum meminta lagi.");
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

        // Akun yang ditangguhkan disebut apa adanya di sini, tidak disamarkan jadi "nomor
        // atau kode tidak cocok" seperti dua penolakan di atas.
        //
        // Bedanya bukan kelalaian. Dua penolakan itu disamarkan supaya endpoint ini tidak
        // bisa dipakai memeriksa nomor siapa saja yang punya akun. Di titik ini
        // penyamaran itu sudah tidak menjaga apa pun: kodenya sudah benar, jadi yang
        // bertanya sudah membuktikan memegang nomor itu. Yang tersisa cuma satu orang yang
        // berhak tahu kenapa ia tidak bisa masuk — dan tanpa kalimat ini ia akan meminta
        // kode berulang kali, yang setiap kalinya berbiaya SMS bagi mitra.
        if (user.Ditangguhkan)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new ProblemDetails
            {
                Title = "Akun ini sedang ditangguhkan",
                Detail = user.SuspendedReason is { Length: > 0 } alasan
                    ? $"Alasannya: {alasan}. Hubungi admin kalau menurutmu ini keliru."
                    : "Hubungi admin kalau menurutmu ini keliru.",
                Status = StatusCodes.Status403Forbidden,
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

    /// <summary>Menyunting profil sendiri: nama, dan alamat bawaan.</summary>
    /// <remarks>
    /// Sebelum ini tidak ada cara mengubah apa pun tentang akun sendiri. Nama yang salah
    /// ketik saat mendaftar melekat selamanya, dan nama itu bukan urusan pribadi: ia yang
    /// dilihat runner saat menerima order, dan yang dilihat klien saat runner datang.
    ///
    /// Kolom alamat sendiri sudah ada sejak skema pertama dan tidak pernah ditulis satu
    /// baris pun. Ia ikut di setiap <see cref="UserResponse"/>, ikut di model mobile,
    /// lengkap dengan tempatnya di <c>copyWith</c> dan perbandingannya — dan isinya selalu
    /// null. Endpoint ini yang membuatnya berarti: alamat yang disimpan sekali lalu
    /// mengisi sendiri kolom yang paling sering diketik ulang di formulir order.
    ///
    /// Bukan alamat order. Order membawa alamatnya sendiri, karena satu orang memesan dari
    /// tempat yang berbeda-beda dan ke tempat yang berbeda-beda; menautkan order ke alamat
    /// akun berarti alamat order lama ikut berubah saat orangnya pindah kos, dan riwayat
    /// order yang berubah sendiri adalah riwayat yang tidak bisa dipakai menengahi apa pun.
    ///
    /// Nomor HP sengaja tidak ikut, lihat <see cref="PerbaruiProfilRequest"/>.
    /// </remarks>
    [Authorize]
    [EnableRateLimiting(BatasLaju.KebijakanTulis)]
    [HttpPut("saya")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<UserResponse>> PerbaruiSaya(
        PerbaruiProfilRequest permintaan,
        CancellationToken batal)
    {
        var user = await db.Users.SingleOrDefaultAsync(u => u.Id == User.Id(), batal);
        if (user is null) return Unauthorized();

        var nama = permintaan.Nama.Trim();
        if (nama.Length == 0)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Nama tidak boleh kosong",
                Detail = "Isi namamu, itu yang dilihat runner saat menerima ordermu.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        user.Name = nama;

        // Alamat kosong disimpan sebagai null, bukan sebagai string kosong. Keduanya
        // berarti "tidak ada", dan dua cara menuliskan hal yang sama berarti setiap
        // pembacanya harus memeriksa dua-duanya — termasuk pengisi otomatis di formulir
        // order, yang kalau lupa akan mengisinya dengan spasi.
        var alamat = permintaan.Alamat?.Trim();
        user.Address = string.IsNullOrEmpty(alamat) ? null : alamat;

        await db.SaveChangesAsync(batal);

        return Ok(UserResponse.Dari(user));
    }

    /// <summary>Langkah pertama mengganti nomor HP sendiri: kirim kode ke nomor barunya.</summary>
    /// <remarks>
    /// Sebelum ini, mengganti nomor menuntut menghubungi admin (lihat <see
    /// cref="PerbaruiProfilRequest"/> untuk alasan kenapa <see cref="PerbaruiSaya"/> sendiri
    /// tidak bisa dipakai): pemiliknya tidak bisa membuktikan kepemilikan nomor barunya lewat
    /// satu kolom isian, dan admin pun belum punya endpoint untuk itu.
    ///
    /// Dikirim ke nomor BARU, bukan nomor lama. Kepemilikan nomor lama sudah terbukti lewat
    /// token yang sedang dipegang; yang belum terbukti justru nomor barunya, dan itulah yang
    /// harus dibuktikan sebelum ia menggantikan yang lama.
    ///
    /// Berbeda dari <see cref="MintaKode"/>, jawabannya TIDAK disamarkan sama untuk semua
    /// keadaan. Penyamaran di sana ada supaya endpoint tanpa token itu tidak bisa dipakai
    /// memeriksa siapa saja yang punya akun; endpoint ini menuntut token yang sah lebih
    /// dulu, jadi pemanggilnya sudah bukan tamu yang bisa mencoba nomor siapa saja tanpa
    /// modal. Menyamarkan "nomor ini sudah dipakai akun lain" di sini cuma membuat kode yang
    /// tidak akan pernah datang, dan pemiliknya menduga aplikasinya rusak, bukan bahwa
    /// nomornya keliru.
    /// </remarks>
    [Authorize]
    [EnableRateLimiting(BatasLaju.KebijakanTulis)]
    [HttpPost("saya/nomor-hp/minta-kode")]
    [ProducesResponseType(StatusCodes.Status202Accepted)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status429TooManyRequests)]
    public async Task<IActionResult> MintaKodeGantiNomor(
        MintaKodeGantiNomorRequest permintaan,
        CancellationToken batal)
    {
        var user = await db.Users.SingleOrDefaultAsync(u => u.Id == User.Id(), batal);
        if (user is null) return Unauthorized();

        var noHpBaru = permintaan.NoHpBaru.Trim();

        if (noHpBaru == user.Phone)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Ini nomor yang sama dengan sekarang",
                Detail = "Tidak ada yang perlu diganti.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        // Diperiksa SEBELUM menyentuh pembatas laju, bukan sesudahnya. Pembatasnya
        // dikunci per nomor HP dan dibagi dengan alur masuk (lihat di bawah), jadi
        // permintaan yang sudah pasti gagal di sini tidak boleh ikut membakar jatah nomor
        // itu — kalau tidak, siapa pun yang tahu sebuah nomor terdaftar bisa mengirim lima
        // permintaan ganti-nomor ke nomor itu tanpa satu SMS pun benar-benar terkirim, dan
        // pemilik nomornya kehabisan jatah minta kode masuk tanpa pernah tahu kenapa.
        if (await db.Users.AnyAsync(u => u.Phone == noHpBaru && u.Id != user.Id, batal))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Nomor ini sudah dipakai akun lain",
                Detail = "Pastikan nomornya benar, atau hubungi admin kalau menurutmu ini keliru.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        // Kunci yang sama dengan pembatas di MintaKode: nomor HP, bukan pemanggilnya.
        // Endpoint ini yang membuat SMS terkirim, dan nomor barunya boleh saja bukan milik
        // pemanggil sendiri kalau ia salah ketik — orang lain yang ponselnya berdering
        // karenanya tetap harus dilindungi dari banjir kode.
        var izin = pembatasOtp.Catat(noHpBaru);
        if (!izin.Boleh)
        {
            return TerlaluSeringMintaKode(
                izin.TungguLagi,
                "Kode verifikasi sudah dikirim beberapa kali ke nomor ini. "
                + "Tunggu sebentar sebelum meminta lagi.");
        }

        var kode = pembuatKode.Buat();
        penyimpanOtp.Simpan(noHpBaru, kode);
        await pengirimOtp.KirimAsync(noHpBaru, kode, batal);

        return Accepted();
    }

    /// <summary>Langkah kedua: menukar kode yang benar dengan nomor HP yang baru.</summary>
    /// <remarks>
    /// Token yang sedang dipegang tetap berlaku sesudah ini, tidak diterbitkan ulang. Ia
    /// cuma membawa id akun, nama, dan peran (lihat <see cref="TokenService"/>) — tidak ada
    /// klaim nomor HP di dalamnya yang perlu disegarkan, persis seperti mengganti nama di
    /// <see cref="PerbaruiSaya"/> juga tidak menuntut token baru.
    /// </remarks>
    [Authorize]
    [EnableRateLimiting(BatasLaju.KebijakanTulis)]
    [HttpPost("saya/nomor-hp/konfirmasi")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<UserResponse>> KonfirmasiGantiNomor(
        KonfirmasiGantiNomorRequest permintaan,
        CancellationToken batal)
    {
        var user = await db.Users.SingleOrDefaultAsync(u => u.Id == User.Id(), batal);
        if (user is null) return Unauthorized();

        var noHpBaru = permintaan.NoHpBaru.Trim();

        if (!penyimpanOtp.Pakai(noHpBaru, permintaan.Kode))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Kode salah atau sudah kedaluwarsa",
                Detail = "Minta kode baru kalau sudah lewat lima menit sejak dikirim.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        // Diperiksa lagi di sini, bukan cuma di langkah minta-kode. Jendela lima menit di
        // antara keduanya cukup lama bagi nomor yang sama diklaim akun lain, dan index unik
        // di bawah cuma menjaga dari tabrakan yang benar-benar bersamaan, bukan yang
        // berjarak beberapa menit seperti ini.
        if (await db.Users.AnyAsync(u => u.Phone == noHpBaru && u.Id != user.Id, batal))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Nomor ini sudah dipakai akun lain",
                Detail = "Nomor ini terlanjur dipakai akun lain sebelum verifikasimu selesai.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        var lama = user.Phone;
        user.Phone = noHpBaru;

        try
        {
            await db.SaveChangesAsync(batal);
        }
        catch (DbUpdateException galat) when (GalatDb.Bentrok(galat))
        {
            // Kalah cepat dengan orang lain yang mengklaim nomor yang sama tepat di celah
            // antara pemeriksaan di atas dan penyimpanan ini. Jarang, tapi index unik di
            // kolom Phone tetap satu-satunya penjaga yang benar-benar tidak bisa dilewati.
            return BadRequest(new ProblemDetails
            {
                Title = "Nomor ini sudah dipakai akun lain",
                Detail = "Nomor ini terlanjur dipakai akun lain sebelum verifikasimu selesai.",
                Status = StatusCodes.Status400BadRequest,
            });
        }

        log.LogWarning(
            "Nomor HP akun {UserId} diganti dari {NomorLama} ke {NomorBaru}.",
            user.Id, lama, user.Phone);

        return Ok(UserResponse.Dari(user));
    }

    /// <summary>
    /// Jawaban 429 untuk endpoint yang mengirim kode, dipakai <see cref="MintaKode"/> dan
    /// <see cref="MintaKodeGantiNomor"/> -- keduanya mengirim SMS dan keduanya dijaga
    /// <see cref="IPembatasOtp"/> yang sama.
    /// </summary>
    /// <param name="detail">
    /// Kalimatnya sengaja tidak disamakan sepenuhnya di kedua pemanggil: yang satu bicara
    /// soal kode masuk, yang satu soal kode verifikasi nomor baru, dan pemanggilnya sudah
    /// tahu konteks mana yang sedang berjalan sedangkan pengguna belum tentu.
    /// </param>
    private ObjectResult TerlaluSeringMintaKode(TimeSpan tungguLagi, string detail)
    {
        // Invariant, bukan budaya mesin. Nilai header HTTP bukan teks untuk dibaca orang,
        // dan budaya yang memakai pemisah lain akan menghasilkan header yang tidak bisa
        // diurai klien mana pun.
        Response.Headers.RetryAfter = ((int)Math.Ceiling(tungguLagi.TotalSeconds))
            .ToString(CultureInfo.InvariantCulture);

        return StatusCode(StatusCodes.Status429TooManyRequests, new ProblemDetails
        {
            Title = "Terlalu sering meminta kode",
            Detail = detail,
            Status = StatusCodes.Status429TooManyRequests,
        });
    }
}
