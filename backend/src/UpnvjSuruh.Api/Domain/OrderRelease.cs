namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Catatan setiap kali seorang runner melepas order yang sudah dipegangnya.
///
/// ## Kenapa tabel tersendiri, bukan kolom di penugasan
///
/// Melepas order menghapus barisnya di <see cref="OrderRunnerAssignment"/>, dan itu keputusan
/// yang benar: menandainya sebagai "sudah dilepas" alih-alih menghapusnya berarti setiap
/// tempat yang bertanya "siapa runner order ini" harus ikut menyaring yang sudah pergi —
/// <c>AksesOrder</c>, dua daftar order runner, siaran, perhitungan payout. Satu saja yang lupa
/// menyaring dan runner yang sudah pergi tetap terhitung sebagai pemegangnya, atau tetap bisa
/// membaca alamat rumah pelanggan.
///
/// Tapi menghapusnya berarti tidak ada jejak sama sekali. Runner yang menerima lalu melepas
/// sepuluh order berturut-turut meninggalkan basis data yang bentuknya persis sama dengan
/// runner yang tidak pernah melakukannya. Sejak akun bisa ditangguhkan, itu jadi lubang yang
/// nyata dan bukan sekadar kerapian: admin punya kekuasaan menghentikan akun, tapi tidak punya
/// satu pun angka untuk memutuskan apakah pantas.
///
/// Tabel tersendiri menutup keduanya. Penugasannya tetap dihapus, jadi tidak ada satu pun
/// kueri yang perlu berubah; jejaknya tinggal di sini, tempat yang tidak pernah ditanya
/// "siapa yang memegang order ini".
///
/// Isinya tidak pernah diubah maupun dihapus, sama seperti <see cref="UserRoleChange"/>.
/// Catatan yang bisa disunting bukan catatan.
/// </summary>
public class OrderRelease
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Order yang dilepas.</summary>
    public required Guid OrderId { get; set; }
    public Order? Order { get; set; }

    /// <summary>Runner yang melepasnya.</summary>
    public required Guid RunnerId { get; set; }
    public User? Runner { get; set; }

    /// <summary>
    /// Alasan yang ditulis runner, dan sudah wajib diisi sejak endpoint melepas dibuat.
    ///
    /// Disalin ke sini, bukan ditunjuk ke pesan chatnya. Alasannya memang juga masuk ke
    /// percakapan order supaya klien bisa membacanya, tapi percakapan bisa panjang dan
    /// pesan bisa hilang di antaranya; catatan yang mengharuskan orang mencari sendiri
    /// sebabnya di tempat lain adalah catatan yang tidak akan dibaca.
    /// </summary>
    public required string Reason { get; set; }

    public DateTime ReleasedAt { get; set; } = DateTime.UtcNow;
}
