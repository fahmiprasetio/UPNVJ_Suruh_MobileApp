using System.ComponentModel.DataAnnotations;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Pricing;

namespace UpnvjSuruh.Api.Contracts;

/// <summary>
/// Permintaan membuat order Jalur A.
///
/// PERHATIKAN APA YANG TIDAK ADA DI SINI: tidak ada harga, dan tidak ada id klien.
///
/// Harga dihitung server dari <see cref="ServiceType"/> dan <see cref="JarakKm"/>. Endpoint
/// yang menerima harga jadi membuat siapa pun bisa memesan seharga satu rupiah, dan itu
/// tidak ketahuan sampai uangnya dihitung.
///
/// Id klien diambil dari token. Menerimanya di sini berarti siapa pun bisa membuat order
/// atas nama orang lain.
/// </summary>
public record BuatOrderJalurARequest
{
    [Required]
    public ServiceType ServiceType { get; init; }

    /// <summary>
    /// Perkiraan jarak yang diisi klien. Wajib untuk anter jemput dan jastip barang, dan
    /// diabaikan untuk jastip makanan. Nilainya dijepit server ke rentang yang wajar.
    /// </summary>
    [Range(0, 1000)]
    public double? JarakKm { get; init; }

    [MaxLength(BatasMasukan.Deskripsi)]
    public string? Deskripsi { get; init; }

    [MaxLength(BatasMasukan.Alamat)]
    public string? AlamatJemput { get; init; }

    [MaxLength(BatasMasukan.Alamat)]
    public string? AlamatTujuan { get; init; }
}

public record RincianTarifResponse(string Label, decimal Nominal)
{
    public static RincianTarifResponse Dari(RincianTarif r) => new(r.Label, r.Nominal);
}

public record OrderResponse(
    Guid Id,
    string ServiceType,
    string Track,
    string Status,
    Guid KlienId,
    string NamaKlien,
    decimal? Harga,
    string? Deskripsi,
    string? AlamatJemput,
    string? AlamatTujuan,
    double? JarakKm,
    int JumlahRunnerDibutuhkan,
    IReadOnlyList<Guid> RunnerIds,
    DateTime DibuatPada,
    DateTime? DibayarPada,
    DateTime? SelesaiPada)
{
    public static OrderResponse Dari(Order order, string namaKlien) => new(
        order.Id,
        order.ServiceType.ToString(),
        order.Track.ToString(),
        order.Status.ToString(),
        order.ClientId,
        namaKlien,
        order.Price,
        order.Description,
        order.PickupAddress,
        order.DestinationAddress,
        order.DistanceKm,
        order.RequiredRunnerCount,
        [.. order.RunnerAssignments.Select(a => a.RunnerId)],
        order.CreatedAt,
        order.PaidAt,
        order.CompletedAt);
}

public record BuatOrderResponse(OrderResponse Order, IReadOnlyList<RincianTarifResponse> Rincian);

/// <summary>Hasil runner menekan TERIMA.</summary>
public record TerimaOrderResponse(bool Dapat, string Keterangan);

/// <summary>
/// Kabar dari gateway pembayaran.
///
/// PERHATIKAN: tidak ada yang menyebut "sudah lunas" selain gateway. Klien tidak punya
/// satu pun endpoint untuk menyatakan dirinya sudah membayar, dan itu sengaja.
/// </summary>
public record WebhookPembayaranRequest
{
    [Required]
    public Guid OrderId { get; init; }

    [Required(AllowEmptyStrings = false)]
    [MaxLength(BatasMasukan.ReferensiGateway)]
    public string ReferensiGateway { get; init; } = string.Empty;

    [Required]
    public PaymentStatus Status { get; init; }

    [Range(0, double.MaxValue)]
    public decimal Jumlah { get; init; }
}
