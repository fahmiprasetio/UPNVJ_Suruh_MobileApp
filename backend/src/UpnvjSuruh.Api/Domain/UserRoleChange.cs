namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Catatan setiap kali peran seseorang diubah.
///
/// Ada karena pertanyaan "siapa yang mengangkat orang ini jadi runner, dan kapan" harus punya
/// jawaban. Runner dipercaya masuk ke kos orang dan memegang uang belanja; kalau ada yang
/// salah, yang pertama ditanyakan adalah siapa yang memberinya akses. Tanpa catatan ini,
/// jawabannya cuma bisa ditebak dari ingatan orang.
///
/// Isinya tidak pernah diubah maupun dihapus. Catatan yang bisa disunting bukan catatan.
/// </summary>
public class UserRoleChange
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Yang perannya berubah.</summary>
    public required Guid UserId { get; set; }
    public User? User { get; set; }

    /// <summary>Admin yang mengubahnya.</summary>
    public required Guid ChangedByAdminId { get; set; }

    public List<UserRole> RolesBefore { get; set; } = [];
    public List<UserRole> RolesAfter { get; set; } = [];

    /// <summary>
    /// Alasan perubahannya, diisi admin.
    ///
    /// Diwajibkan, bukan opsional. Catatan tanpa alasan cuma memberi tahu bahwa sesuatu
    /// terjadi, bukan kenapa, dan kenapa itulah yang dicari orang saat memeriksanya nanti.
    /// </summary>
    public required string Reason { get; set; }

    public DateTime ChangedAt { get; set; } = DateTime.UtcNow;
}
