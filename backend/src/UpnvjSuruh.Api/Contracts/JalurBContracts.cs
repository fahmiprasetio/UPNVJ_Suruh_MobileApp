using System.ComponentModel.DataAnnotations;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Contracts;

/// <summary>
/// Permintaan Jalur B: klien menuliskan kebutuhannya, sekaligus mengusulkan harga.
///
/// <see cref="HargaUsulan"/> BUKAN harga order. Itu cuma titik awal tawar-menawar yang
/// dipajang ke runner yang menimbang permintaan ini, sama seperti mengetik "saya mau bayar
/// segini" di aplikasi ojek daring. Harga order sungguhan tetap hanya bisa datang dari
/// penawaran runner yang disetujui klien nantinya, bukan dari sini.
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

    [Range(1, 100_000_000)]
    public decimal HargaUsulan { get; init; }
}

/// <summary>
/// Penawaran seorang runner: menyanggupi harga usulan klien apa adanya, atau mengajukan
/// angkanya sendiri.
///
/// Id runnernya diambil dari token, tidak diterima di sini. Penawaran adalah dokumen yang
/// menyebut siapa yang menawarkan, dan penyebutan itu tidak boleh berasal dari pihak
/// yang menulisnya. Tidak ada bidang terpisah untuk "setuju harga klien": runner yang
/// setuju cukup mengirim penawaran dengan <see cref="Harga"/> yang sama dengan usulan
/// klien, itu tetap penawaran yang sah dan bisa langsung dipilih.
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

/// <summary>
/// Runner menarik kembali penawarannya sendiri, boleh disertai alasan.
/// </summary>
/// <remarks>
/// Alasannya opsional, dan itu perbedaan yang disengaja dari <c>LepasOrderRequest</c> maupun
/// <c>MintaBatalRequest</c>, yang keduanya mewajibkan. Yang dilepas di sana pekerjaan yang
/// sudah dibayar dan sudah ditunggu orang; yang ditarik di sini tawaran yang belum diterima
/// siapa pun, jadi belum ada komitmen yang dibatalkan. Mewajibkan alasan untuk kasus yang
/// paling sering terjadi — salah ketik angka — cuma memaksa orang mengetik "salah ketik".
///
/// Kalau diisi, kalimatnya masuk ke jalur obrolan pribadi runner itu dengan klien, ditulis
/// sebelum penawarannya dicabut: sesudah dicabut runner bukan pihak yang berkepentingan lagi
/// di order itu (<c>AksesOrder.MasihMenawar</c>), jadi inilah satu-satunya kesempatannya
/// menjelaskan.
/// </remarks>
public record CabutPenawaranRequest
{
    [MaxLength(BatasMasukan.PesanChat)]
    public string? Alasan { get; init; }
}

/// <summary>Klien meminta satu penawaran tertentu dihitung ulang, disertai alasannya.</summary>
public record NegoPenawaranRequest
{
    [Required(AllowEmptyStrings = false)]
    [MaxLength(BatasMasukan.PesanChat)]
    public string Alasan { get; init; } = string.Empty;
}

public record OrderOfferResponse(
    Guid Id,
    Guid OrderId,
    Guid RunnerId,
    /// <summary>
    /// Nama runner yang mengajukan penawaran ini, supaya klien tahu siapa yang ia pilih
    /// sebelum menyetujui, bukan cuma harga dan jadwalnya.
    /// </summary>
    string NamaRunner,
    string? NoHpRunner,
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
        offer.CreatedByRunnerId,
        offer.CreatedByRunner?.Name ?? "Runner",
        offer.CreatedByRunner?.Phone,
        offer.Price,
        (int)offer.EstimatedDuration.TotalMinutes,
        offer.ScheduledStart,
        offer.Status.ToString(),
        offer.Note,
        offer.CreatedAt,
        offer.RespondedAt);
}
