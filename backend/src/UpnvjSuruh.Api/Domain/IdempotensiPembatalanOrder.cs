namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Jejak pembatalan order yang berhasil agar retry klien tidak menggandakan status,
/// pembatalan payment pending, atau notifikasi.
/// </summary>
public class IdempotensiPembatalanOrder
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public required string Key { get; set; }
    public required Guid UserId { get; set; }
    public required Guid OrderId { get; set; }
    public required string RequestHash { get; set; }
    public required string ResponseJson { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
