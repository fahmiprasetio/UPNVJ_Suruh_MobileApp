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
    string KodeOrder,
    string ServiceType,
    string Track,
    string Status,
    Guid KlienId,
    string NamaKlien,
    decimal? Harga,
    decimal? HargaUsulan,
    string? Deskripsi,
    string? AlamatJemput,
    string? AlamatTujuan,
    double? JarakKm,
    int JumlahRunnerDibutuhkan,
    IReadOnlyList<Guid> RunnerIds,
    int? EstimasiDurasiMenit,
    DateTime? JadwalMulai,
    string? FotoBuktiUrl,
    string? CatatanSerahTerima,
    IReadOnlyList<OrderOfferResponse> Penawaran,
    /// <summary>
    /// Cukup jumlahnya, bukan isinya. Daftar order menampilkan penanda "ada 3 pesan", dan
    /// mengirim seluruh percakapan setiap order cuma untuk satu angka adalah pemborosan
    /// yang tumbuh seiring ramainya chat.
    /// </summary>
    int JumlahPesan,
    DateTime DibuatPada,
    DateTime? DibayarPada,
    DateTime? SelesaiPada,
    /// <summary>
    /// Terisi selama ada permintaan pembatalan dari klien yang belum dijawab admin. Dipakai
    /// dashboard untuk menandai order yang menunggu keputusan, dan dipakai aplikasi klien
    /// untuk menjelaskan bahwa permintaannya sudah sampai.
    /// </summary>
    DateTime? MintaBatalPada,
    /// <summary>
    /// Benar kalau order ini sudah terlalu lama menganggur di keadaan yang seharusnya cepat
    /// berlalu (<see cref="Domain.OrderMacet"/>).
    ///
    /// Dihitung server, bukan oleh yang membacanya. Sebelumnya dashboard menghitungnya
    /// sendiri dari waktu pembuatan order, yang berarti ambangnya hidup di dua tempat dan
    /// server tidak pernah bisa menyebut-nyebut order yang bermasalah.
    /// </summary>
    bool Macet)
{
    public static OrderResponse Dari(Order order, string namaKlien, int jumlahPesan = 0) => new(
        order.Id,
        order.OrderCode,
        order.ServiceType.ToString(),
        order.Track.ToString(),
        order.Status.ToString(),
        order.ClientId,
        namaKlien,
        order.Price,
        order.SuggestedPrice,
        order.Description,
        order.PickupAddress,
        order.DestinationAddress,
        order.DistanceKm,
        order.RequiredRunnerCount,
        [.. order.RunnerAssignments.Select(a => a.RunnerId)],
        order.EstimatedDuration is null ? null : (int)order.EstimatedDuration.Value.TotalMinutes,
        order.ScheduledStart,
        order.PhotoUrl,
        order.HandoverNote,
        // Penawaran ikut terkirim bersama ordernya, bukan lewat permintaan terpisah.
        // Layar yang menampilkan penawaran selalu menampilkan ordernya juga, jadi
        // memisahkannya cuma menambah satu permintaan yang selalu menyusul.
        [.. order.Offers.OrderBy(f => f.CreatedAt).Select(OrderOfferResponse.Dari)],
        jumlahPesan,
        order.CreatedAt,
        order.PaidAt,
        order.CompletedAt,
        order.CancellationRequestedAt,
        OrderMacet.Sedang(order, DateTime.UtcNow));
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
