namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Jejak pelepasan order yang berhasil agar retry jaringan tidak menggandakan audit dan chat.
/// </summary>
public class IdempotensiLepasOrder
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public required string Key { get; set; }
    public required Guid RunnerId { get; set; }
    public required Guid OrderId { get; set; }
    public required string RequestHash { get; set; }
    public required string ResponseJson { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
