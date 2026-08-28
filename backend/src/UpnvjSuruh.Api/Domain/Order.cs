namespace UpnvjSuruh.Api.Domain;

public class Order
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required Guid ClientId { get; set; }
    public User? Client { get; set; }

    public ServiceType ServiceType { get; set; }

    /// <summary>
    /// Jalur ditentukan jenis layanannya, jadi diturunkan, bukan disimpan. Kolom tersendiri
    /// membuka kemungkinan keduanya berselisih, dan order yang mengaku Jalur A sambil
    /// menunggu penawaran adalah keadaan yang tidak punya arti.
    /// </summary>
    public OrderTrack Track => ServiceType.Track();
    public OrderStatus Status { get; set; } = OrderStatus.Permintaan;

    public string? Description { get; set; }
    public string? PhotoUrl { get; set; }
    public string? VoiceNoteUrl { get; set; }

    public string? PickupAddress { get; set; }
    public string? DestinationAddress { get; set; }

    /// <summary>
    /// Perkiraan jarak yang diisi klien, dipakai menghitung harga Jalur A. Disimpan apa
    /// adanya supaya kalau harga dipertanyakan, angka yang dipakai saat itu masih ada.
    /// Harga yang tidak bisa ditelusuri ulang tidak bisa dibela.
    /// </summary>
    public double? DistanceKm { get; set; }

    /// <summary>Jadwal mulai untuk Jalur B, dan untuk Jalur A tetap null.</summary>
    public DateTime? ScheduledStart { get; set; }

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
