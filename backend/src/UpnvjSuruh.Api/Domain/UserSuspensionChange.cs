namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Catatan setiap kali sebuah akun ditangguhkan atau dipulihkan kembali.
///
/// ## Kenapa tidak cukup kolom di akunnya
///
/// <see cref="User.SuspendedAt"/>, <see cref="User.SuspendedReason"/>, dan
/// <see cref="User.SuspendedByAdminId"/> menjawab "apakah akun ini sedang berhenti, kenapa,
/// dan oleh siapa" — tapi ketiganya menyimpan keadaan sekarang, bukan riwayatnya. Menangguhkan
/// ulang menimpa yang lama, dan memulihkan mengosongkan ketiganya sekaligus.
///
/// Akibatnya alasan memulihkan tidak tersimpan sama sekali. Ia diwajibkan diisi admin sejak
/// endpointnya dibuat, lalu cuma masuk ke log aplikasi — tempat yang bergilir, tidak ikut
/// cadangan basis data, dan tidak bisa ditanya dari layar mana pun. Alasan yang diminta lalu
/// dibuang bukan alasan yang diminta, cuma satu kolom isian yang menghalangi.
///
/// Dan pola yang paling ingin diketahui justru pola berulang: akun yang ditangguhkan lalu
/// dipulihkan tiga kali berbeda artinya dari akun yang baru sekali dihentikan, dan bedanya
/// tidak terbaca dari kolom yang cuma menyimpan yang terakhir.
///
/// ## Kenapa satu tabel untuk kedua arah
///
/// Ditangguhkan dan dipulihkan adalah dua keputusan pada hal yang sama, dan yang dicari orang
/// yang membacanya urutan bolak-baliknya, bukan salah satunya saja. Dua tabel terpisah berarti
/// menggabungkannya kembali terurut waktu setiap kali ada yang bertanya.
///
/// Isinya tidak pernah diubah maupun dihapus, sama seperti <see cref="UserRoleChange"/> dan
/// <see cref="OrderRelease"/>. Catatan yang bisa disunting bukan catatan.
/// </summary>
public class UserSuspensionChange
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Akun yang dihentikan atau dipulihkan.</summary>
    public required Guid UserId { get; set; }
    public User? User { get; set; }

    /// <summary>Admin yang memutuskannya.</summary>
    public required Guid ChangedByAdminId { get; set; }

    /// <summary>
    /// Benar kalau baris ini penangguhan, salah kalau pemulihan.
    /// </summary>
    /// <remarks>
    /// Boolean, bukan pasangan "sebelum/sesudah" seperti <see cref="UserRoleChange"/>: peran
    /// punya banyak nilai yang mungkin sehingga perubahannya perlu ditulis lengkap, sedangkan
    /// penangguhan cuma punya dua keadaan dan baris ini selalu berarti pindah dari yang satu
    /// ke yang lain.
    /// </remarks>
    public required bool Suspended { get; set; }

    /// <summary>Alasannya, wajib diisi di kedua arah.</summary>
    public required string Reason { get; set; }

    public DateTime ChangedAt { get; set; } = DateTime.UtcNow;
}
