namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// One row per runner who accepted an order. Uniqueness on (OrderId, RunnerId) stops
/// a runner double-accepting; RequiredRunnerCount vs row count (checked inside a
/// transaction against Order.Version) stops two runners racing for the last slot.
/// </summary>
public class OrderRunnerAssignment
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required Guid OrderId { get; set; }
    public Order? Order { get; set; }

    public required Guid RunnerId { get; set; }
    public User? Runner { get; set; }

    public DateTime AcceptedAt { get; set; } = DateTime.UtcNow;
    public DateTime? MarkedDoneAt { get; set; }
    public string? CompletionPhotoUrl { get; set; }

    public decimal? PayoutAmount { get; set; }
    public bool PayoutSettled { get; set; }
}
