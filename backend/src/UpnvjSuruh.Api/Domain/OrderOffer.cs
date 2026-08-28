namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Penawaran harga dari admin untuk order Jalur B.
///
/// Penawaran adalah usulan, bukan keputusan. Selama statusnya <see cref="OfferStatus.Pending"/>,
/// angka di dalamnya belum boleh dianggap harga order: harga baru pindah ke ordernya ketika
/// klien menyetujuinya. Order yang memajang harga yang belum disepakati akan terbaca sebagai
/// tagihan, dan itu janji yang belum tentu ditepati.
/// </summary>
public class OrderOffer
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required Guid OrderId { get; set; }
    public Order? Order { get; set; }

    public required Guid CreatedByAdminId { get; set; }

    public decimal Price { get; set; }
    public TimeSpan EstimatedDuration { get; set; }

    /// <summary>
    /// Kapan pekerjaannya dimulai menurut admin.
    ///
    /// Bisa berbeda dari waktu yang diminta klien, misalnya karena tim sedang penuh di
    /// jam itu. Perbedaannya bukan kesalahan, tapi harus ikut ke layar klien sebelum ia
    /// menyetujui, jadi disimpan di penawaran, bukan diam-diam menimpa jadwal ordernya.
    /// </summary>
    public DateTime ScheduledStart { get; set; }

    public string? Note { get; set; }

    public OfferStatus Status { get; set; } = OfferStatus.Pending;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? RespondedAt { get; set; }
}
