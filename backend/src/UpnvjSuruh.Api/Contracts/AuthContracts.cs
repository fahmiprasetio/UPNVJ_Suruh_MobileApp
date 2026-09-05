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
