namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Satu pemasangan aplikasi yang boleh dikirimi notifikasi push.
///
/// ## Kenapa perangkat, bukan kolom di akun
///
/// Yang dituju notifikasi push bukan orangnya, melainkan pemasangan aplikasinya. Firebase
/// menerbitkan tokennya per pemasangan, jadi satu orang yang memakai HP dan tablet punya
/// dua token yang sama-sama berlaku, dan mengirim ke salah satunya saja berarti separuh
/// kabar tidak pernah sampai. Kolom tunggal di tabel akun akan memaksa yang kedua menimpa
/// yang pertama.
///
/// ## Kenapa tokennya unik lintas akun, bukan cuma per akun
///
/// Token itu milik pemasangan, dan sebuah HP yang dipakai bergantian dua orang (klien lalu
/// runner, hal yang lumrah di lingkungan kos) akan menyodorkan token yang sama untuk akun
/// yang berbeda. Kalau barisnya cuma unik per akun, token itu berakhir tercatat di dua
/// akun sekaligus, dan kabar milik akun yang sudah keluar tetap sampai ke layar orang yang
/// sedang memakainya. Karena itu indeksnya unik pada tokennya saja: mendaftarkan ulang
/// token yang sudah dikenal berarti memindahkannya, bukan menambah baris.
/// </summary>
public class PerangkatNotifikasi
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Pemilik pemasangan ini, yaitu akun yang sedang masuk di sana.</summary>
    public required Guid UserId { get; set; }
    public User? User { get; set; }

    /// <summary>Token pendaftaran dari Firebase Cloud Messaging.</summary>
    public required string Token { get; set; }

    /// <summary>
    /// Kapan token ini terakhir didaftarkan ulang aplikasi.
    ///
    /// Firebase memutar tokennya sendiri sesekali, dan aplikasi mendaftarkan yang baru
    /// setiap kali ia berubah maupun setiap kali aplikasi dibuka. Yang lama berhenti
    /// dikenali Firebase, dan barisnya dibuang begitu pengiriman pertama ke sana dijawab
    /// "sudah tidak terdaftar" -- lihat <c>PengabarOrder</c>.
    /// </summary>
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
