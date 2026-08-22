namespace UpnvjSuruh.Api.Domain;

public class OrderMessage
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required Guid OrderId { get; set; }
    public Order? Order { get; set; }

    public required Guid SenderId { get; set; }
    public string? Text { get; set; }
    public string? PhotoUrl { get; set; }
    public string? VoiceNoteUrl { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
