namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Jejak keberhasilan runner menerima order agar retry jaringan tidak membuat efek ganda.
/// </summary>
public class IdempotensiTerimaOrder
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public required string Key { get; set; }
    public required Guid RunnerId { get; set; }
    public required Guid OrderId { get; set; }
    public required string RequestHash { get; set; }
    public required string ResponseJson { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
