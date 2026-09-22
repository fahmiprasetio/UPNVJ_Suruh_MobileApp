namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Jejak aksi penawaran yang berhasil agar retry tidak menggandakan status atau pesan.
/// Key terikat pada pengguna, bukan pada peran, karena akun dapat berganti konteks klien/runner.
/// </summary>
public class IdempotensiAksiPenawaran
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public required string Key { get; set; }
    public required Guid UserId { get; set; }
    public required Guid OrderId { get; set; }
    public required Guid OfferId { get; set; }
    public required string RequestHash { get; set; }
    public required string ResponseJson { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
