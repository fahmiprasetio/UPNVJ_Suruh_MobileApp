namespace UpnvjSuruh.Api.Domain;

public class Order
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required Guid ClientId { get; set; }
    public User? Client { get; set; }

    public OrderTrack Track { get; set; }
    public ServiceType ServiceType { get; set; }
    public OrderStatus Status { get; set; } = OrderStatus.Permintaan;

    public string? Description { get; set; }
    public string? PhotoUrl { get; set; }
    public string? VoiceNoteUrl { get; set; }

    public decimal? Price { get; set; }
    public TimeSpan? EstimatedDuration { get; set; }

    public int RequiredRunnerCount { get; set; } = 1;

    public string? HandoverNote { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? PaidAt { get; set; }
    public DateTime? CompletedAt { get; set; }

    public List<OrderOffer> Offers { get; set; } = [];
    public List<OrderMessage> Messages { get; set; } = [];
    public List<OrderRunnerAssignment> RunnerAssignments { get; set; } = [];
    public Payment? Payment { get; set; }
}
