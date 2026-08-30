using System.ComponentModel.DataAnnotations;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Contracts;

/// <summary>
/// Permintaan Jalur B: klien menuliskan kebutuhannya, harganya menyusul.
///
/// PERHATIKAN TIDAK ADA HARGA DI SINI, dan itu bukan kelupaan. Yang membedakan Jalur B
/// dari Jalur A justru tidak adanya harga di ujung form: pekerjaannya belum dilihat
/// siapa pun, jadi belum ada yang bisa menghitungnya. Angka baru muncul lewat penawaran
/// admin.
/// </summary>
public record BuatPermintaanJalurBRequest
{
    [Required]
    public ServiceType ServiceType { get; init; }

    [Required(AllowEmptyStrings = false)]
    [MaxLength(BatasMasukan.Deskripsi)]
    public string Deskripsi { get; init; } = string.Empty;

    [Required]
    [WaktuDiMasaDepan]
    public DateTime JadwalMulai { get; init; }

    [MaxLength(BatasMasukan.Alamat)]
    public string? AlamatTujuan { get; init; }

    [Range(1, 10)]
    public int JumlahRunnerDibutuhkan { get; init; } = 1;
}

/// <summary>
/// Penawaran admin.
///
/// Id adminnya diambil dari token, tidak diterima di sini. Penawaran adalah dokumen yang
/// menyebut siapa yang menawarkan, dan penyebutan itu tidak boleh berasal dari pihak
/// yang menulisnya.
/// </summary>
public record BuatPenawaranRequest
{
    [Range(1, 100_000_000)]
    public decimal Harga { get; init; }

    /// <summary>Perkiraan lama pengerjaan, dalam menit.</summary>
    [Range(1, 60 * 24 * 30)]
    public int EstimasiDurasiMenit { get; init; }

    [Required]
    [WaktuDiMasaDepan]
    public DateTime JadwalMulai { get; init; }

    [MaxLength(BatasMasukan.Deskripsi)]
    public string? Catatan { get; init; }
}

/// <summary>Klien meminta penawaran dihitung ulang, disertai alasannya.</summary>
public record NegoPenawaranRequest
{
    [Required(AllowEmptyStrings = false)]
    [MaxLength(BatasMasukan.PesanChat)]
    public string Alasan { get; init; } = string.Empty;
}

public record OrderOfferResponse(
    Guid Id,
    Guid OrderId,
    decimal Harga,
    int EstimasiDurasiMenit,
    DateTime JadwalMulai,
    string Status,
    string? Catatan,
    DateTime DibuatPada,
    DateTime? DijawabPada)
{
    public static OrderOfferResponse Dari(OrderOffer offer) => new(
        offer.Id,
        offer.OrderId,
        offer.Price,
        (int)offer.EstimatedDuration.TotalMinutes,
        offer.ScheduledStart,
        offer.Status.ToString(),
        offer.Note,
        offer.CreatedAt,
        offer.RespondedAt);
}
