namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Jejak penyelesaian order yang berhasil agar retry tidak menggandakan status dan payout.
/// </summary>
public class IdempotensiSelesaikanOrder
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public required string Key { get; set; }
    public required Guid RunnerId { get; set; }
    public required Guid OrderId { get; set; }
    public required string RequestHash { get; set; }
    public required string ResponseJson { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
