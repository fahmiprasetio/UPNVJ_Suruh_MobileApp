using System.ComponentModel.DataAnnotations;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Contracts;

/// <summary>
/// Permintaan mendaftar.
///
/// PERHATIKAN APA YANG TIDAK ADA DI SINI: tidak ada field peran, dan itu disengaja. Peran
/// runner dan admin hanya boleh diberikan admin lewat dashboard, tidak pernah atas
/// permintaan sendiri. Runner adalah pegawai mitra yang dipercaya masuk ke kos orang dan
/// memegang uang belanja.
///
/// Jangan menambahkan field peran di sini "supaya fleksibel lalu diabaikan saja". Field yang
/// ada tapi diabaikan hari ini akan diam-diam mulai dibaca oleh versi berikutnya, dan sejak
/// saat itu semua pemeriksaan peran di sistem ini kehilangan artinya. Aturan yang sama
/// ditulis di kontrak <c>AuthRepository</c> sisi mobile.
/// </summary>
public record DaftarRequest
{
    [Required(AllowEmptyStrings = false)]
    [MaxLength(BatasMasukan.Nama)]
    public string Nama { get; init; } = string.Empty;

    [Required(AllowEmptyStrings = false)]
    [MaxLength(BatasMasukan.NomorHp)]
    [RegularExpression(@"^08\d{8,13}$", ErrorMessage = "Nomor HP harus diawali 08 dan berisi 10 sampai 15 angka.")]
    public string NoHp { get; init; } = string.Empty;
}

public record MintaKodeRequest
{
    [Required(AllowEmptyStrings = false)]
    [MaxLength(BatasMasukan.NomorHp)]
    [RegularExpression(@"^08\d{8,13}$", ErrorMessage = "Nomor HP harus diawali 08 dan berisi 10 sampai 15 angka.")]
    public string NoHp { get; init; } = string.Empty;
}

public record MasukRequest
{
    [Required(AllowEmptyStrings = false)]
    [MaxLength(BatasMasukan.NomorHp)]
    public string NoHp { get; init; } = string.Empty;

    [Required(AllowEmptyStrings = false)]
    [RegularExpression(@"^\d{6}$", ErrorMessage = "Kode OTP terdiri dari 6 angka.")]
    public string Kode { get; init; } = string.Empty;
}

/// <summary>
/// Menyunting profil sendiri.
///
/// PERHATIKAN APA YANG TIDAK ADA DI SINI, sama seperti <see cref="DaftarRequest"/>: tidak
/// ada field peran, dan tidak ada nomor HP. Peran karena alasan yang sama persis. Nomor HP
/// karena ia identitas masuk: ia yang menerima kode OTP, jadi mengubahnya lewat endpoint
/// yang cuma menerima teks berarti siapa pun yang memegang token sesaat bisa memindahkan
/// akunnya ke nomor lain, dan pemilik aslinya terkunci di luar. Menggantinya menuntut
/// verifikasi kode ke nomor barunya, lewat <see cref="MintaKodeGantiNomorRequest"/> dan
/// <see cref="KonfirmasiGantiNomorRequest"/> di bawah, bukan lewat satu field di sini.
/// </summary>
public record PerbaruiProfilRequest
{
    [Required(AllowEmptyStrings = false)]
    [MaxLength(BatasMasukan.Nama)]
    public string Nama { get; init; } = string.Empty;

    /// <summary>
    /// Alamat bawaan, boleh dikosongkan. Bukan alamat order: order membawa alamatnya
    /// sendiri, karena satu orang memesan dari tempat yang berbeda-beda. Yang ini cuma
    /// jawaban yang paling sering ia ketik, disimpan supaya tidak diketik ulang.
    /// </summary>
    [MaxLength(BatasMasukan.Alamat)]
    public string? Alamat { get; init; }
}

/// <summary>
/// Langkah pertama mengganti nomor HP sendiri: minta kode dikirim ke nomor yang BARU.
/// </summary>
/// <remarks>
/// Bukan nomor yang sedang dipakai. Yang harus dibuktikan di sini kepemilikan nomor
/// barunya; kepemilikan nomor lama sudah terbukti lewat token yang sedang dipegang, dan
/// itulah yang membuat endpoint ini boleh menuntut lebih sedikit daripada <see
/// cref="MintaKodeRequest"/>: ia tidak perlu berpura-pura sama untuk semua nomor, karena
/// pemanggilnya sudah masuk, bukan tamu yang bisa mencoba nomor siapa saja tanpa modal.
///
/// Dua langkah, bukan satu langkah nomor+kode langsung: kodenya belum ada sampai
/// permintaan ini terkirim, sama seperti alur masuk yang juga dua langkah untuk alasan
/// yang sama persis.
/// </remarks>
public record MintaKodeGantiNomorRequest
{
    [Required(AllowEmptyStrings = false)]
    [MaxLength(BatasMasukan.NomorHp)]
    [RegularExpression(@"^08\d{8,13}$", ErrorMessage = "Nomor HP harus diawali 08 dan berisi 10 sampai 15 angka.")]
    public string NoHpBaru { get; init; } = string.Empty;
}

/// <summary>Langkah kedua: menukar kode yang benar dengan nomor HP yang baru.</summary>
public record KonfirmasiGantiNomorRequest
{
    [Required(AllowEmptyStrings = false)]
    [MaxLength(BatasMasukan.NomorHp)]
    [RegularExpression(@"^08\d{8,13}$", ErrorMessage = "Nomor HP harus diawali 08 dan berisi 10 sampai 15 angka.")]
    public string NoHpBaru { get; init; } = string.Empty;

    [Required(AllowEmptyStrings = false)]
    [RegularExpression(@"^\d{6}$", ErrorMessage = "Kode OTP terdiri dari 6 angka.")]
    public string Kode { get; init; } = string.Empty;
}

public record UserResponse(
    Guid Id,
    string Nama,
    string NoHp,
    string? Alamat,
    IReadOnlyList<string> Roles,
    /// <summary>
    /// Terisi selama akun ini ditangguhkan. Dipakai dashboard untuk menandai dan
    /// menjelaskan; aplikasi sendiri tidak pernah menerimanya, karena akun yang
    /// ditangguhkan tidak bisa melewati validasi token sama sekali.
    /// </summary>
    DateTime? DitangguhkanPada = null,
    string? AlasanPenangguhan = null)
{
    public static UserResponse Dari(User user) =>
        new(
            user.Id,
            user.Name,
            user.Phone,
            user.Address,
            [.. user.Roles.Select(r => r.ToString())],
            user.SuspendedAt,
            user.SuspendedReason);
}

public record MasukResponse(string Token, DateTime KedaluwarsaPada, UserResponse User);
