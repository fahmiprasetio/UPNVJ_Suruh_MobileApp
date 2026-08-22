namespace UpnvjSuruh.Api.Domain;

public class OrderOffer
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required Guid OrderId { get; set; }
    public Order? Order { get; set; }

    public required Guid CreatedByAdminId { get; set; }

    public decimal Price { get; set; }
    public TimeSpan EstimatedDuration { get; set; }
    public OfferStatus Status { get; set; } = OfferStatus.Pending;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? RespondedAt { get; set; }
}
