using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;

namespace UpnvjSuruh.Api.Auth;

/// <summary>
/// Batas laju permintaan. Kembaran <see cref="Data.BatasMasukan"/> untuk waktu, bukan untuk
/// panjang teks: yang satu menjaga besarnya satu permintaan, yang ini menjaga banyaknya.
///
/// Angkanya ditulis di satu tempat karena ia dipakai di dua lapis yang berbeda, yaitu
/// middleware pembatas laju di <c>Program.cs</c> dan <see cref="PembatasOtp"/>, dan angka
/// yang tersebar akan berbeda-beda setelah salah satunya disetel dan yang lain tidak.
///
/// ## Kenapa dua lapis, bukan cukup middleware saja
///
/// Middleware hanya tahu alamat IP pemanggil dan siapa pemilik tokennya. Untuk endpoint
/// yang mengirim SMS, keduanya bukan yang perlu dijaga: yang perlu dijaga adalah nomor HP
/// yang disebut di badan permintaan, karena itulah yang menerima SMS-nya dan itulah yang
/// menagih biaya ke mitra. Penyerang yang berganti IP tetap bisa membanjiri satu korban
/// kalau batasnya cuma per IP.
///
/// ## Kenapa batas per IP dibuat longgar
///
/// Penggunanya mahasiswa satu kampus, dan jaringan kampus menaruh ratusan orang di balik
/// satu alamat IP. Batas per IP yang ketat akan mengunci seisi gedung karena ulah satu
/// orang. Karena itu penjagaan yang ketat ditaruh di kunci yang benar-benar menunjuk satu
/// orang, yaitu nomor HP dan id pengguna, dan batas per IP dibiarkan sebagai jaring kasar
/// terhadap banjir mentah.
/// </summary>
public static class BatasLaju
{
    // --- Nama kebijakan, dipakai di [EnableRateLimiting(...)] yang cuma menerima string ---

    /// <summary>Endpoint yang boleh dipanggil tanpa token: daftar, minta kode, masuk.</summary>
    public const string KebijakanTamu = "tamu";

    /// <summary>Endpoint yang menulis data atas nama pengguna yang sudah masuk.</summary>
    public const string KebijakanTulis = "tulis";

    /// <summary>Unggahan berkas, yang satu permintaannya jauh lebih mahal dari yang lain.</summary>
    public const string KebijakanUnggah = "unggah";

    // --- Per nomor HP ---

    /// <summary>
    /// Berapa kali satu nomor boleh diminta dikirimi kode dalam satu jendela.
    ///
    /// Lima cukup untuk orang yang SMS-nya benar-benar tidak sampai lalu mencoba lagi
    /// beberapa kali. Di atas itu bukan lagi orang yang sedang berusaha masuk.
    /// </summary>
    public const int OtpPerNomor = 5;

    public static readonly TimeSpan JendelaOtp = TimeSpan.FromHours(1);

    /// <summary>
    /// Jarak minimal antara dua permintaan kode untuk nomor yang sama.
    ///
    /// Ini yang menahan pengiriman beruntun. Tanpa jeda, jatah satu jendela habis dalam
    /// satu detik dan korban tetap menerima lima SMS sekaligus.
    /// </summary>
    public static readonly TimeSpan JedaAntarOtp = TimeSpan.FromSeconds(60);

    // --- Per alamat IP ---

    /// <summary>Jatah endpoint tanpa token untuk satu alamat, per <see cref="JendelaTamu"/>.</summary>
    public const int TamuPerJendela = 100;

    public static readonly TimeSpan JendelaTamu = TimeSpan.FromMinutes(5);

    // --- Per pengguna ---

    /// <summary>Penulisan data per menit: kirim pesan, buat order, jawab penawaran.</summary>
    public const int TulisPerMenit = 30;

    /// <summary>
    /// Unggahan foto per jam. Satu berkas boleh sampai delapan megabita
    /// (<see cref="Media.PenyimpanFoto.BatasUkuranByte"/>), dan berkas yang sudah
    /// tersimpan belum pernah dihapus siapa pun, jadi angka ini yang menentukan berapa
    /// banyak cakram bisa dihabiskan satu akun dalam sejam.
    /// </summary>
    public const int UnggahPerJam = 20;

    // --- Jaring terakhir, berlaku untuk semua permintaan termasuk berkas statis ---

    public const int UmumPerMenit = 300;

    public static readonly TimeSpan JendelaUmum = TimeSpan.FromMinutes(1);

    /// <summary>
    /// Kunci yang memisahkan jatah satu pemanggil dari pemanggil lain.
    ///
    /// Id pengguna dipakai lebih dulu, dan alamat IP hanya untuk yang belum masuk. Urutan
    /// ini yang membuat batas per pengguna tetap berarti di jaringan kampus: seluruh
    /// gedung berbagi satu alamat IP, jadi kalau kuncinya alamat, satu orang yang berulah
    /// akan mengunci semua orang yang kebetulan memakai wifi yang sama.
    ///
    /// Klaimnya dibaca langsung, tidak lewat <see cref="PenggunaSaatIni.Id"/>, karena yang
    /// itu melempar untuk token tanpa klaim <c>sub</c> yang sah. Lemparan di dalam pembatas
    /// laju akan muncul sebagai galat server pada permintaan yang seharusnya cuma dijawab
    /// 401, dan pembatas laju bukan tempat memutuskan sah tidaknya sebuah token.
    /// </summary>
    public static string Pemanggil(HttpContext konteks)
    {
        var sub = konteks.User.FindFirst(JwtRegisteredClaimNames.Sub)?.Value
                  ?? konteks.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        if (!string.IsNullOrEmpty(sub)) return $"pengguna:{sub}";

        return $"alamat:{konteks.Connection.RemoteIpAddress?.ToString() ?? "tak-diketahui"}";
    }
}
