namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Jejak command admin yang sudah berhasil agar retry setelah timeout tidak mengulangi
/// pembukuan, status, atau catatan audit.
/// </summary>
public class IdempotensiAksiAdmin
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public required string Key { get; set; }
    public required Guid AdminId { get; set; }
    public required string Operation { get; set; }
    public required string RequestHash { get; set; }
    public required string ResponseJson { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
