using System.ComponentModel.DataAnnotations;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Contracts;

/// <summary>
/// Menetapkan peran seseorang.
/// </summary>
/// <remarks>
/// Menetapkan, bukan menambah atau mengurangi. Yang dikirim adalah daftar peran yang
/// seharusnya dipegang orang itu sesudahnya, dan itu disengaja: "tambah runner" tidak punya
/// arti yang jelas kalau dua admin melakukannya bersamaan, sementara "peran akhirnya begini"
/// selalu punya. Layar admin menampilkan keadaan sekarang lalu mengirim keadaan yang
/// diinginkan, jadi apa yang dilihat admin sama dengan apa yang ia kirim.
/// </remarks>
public record TetapkanPeranRequest
{
    [Required]
    [MinLength(1, ErrorMessage = "Peran tidak boleh kosong.")]
    public IReadOnlyList<UserRole> Roles { get; init; } = [];

    /// <summary>
    /// Kenapa perannya diubah. Wajib, karena catatan tanpa alasan cuma memberi tahu bahwa
    /// sesuatu terjadi, bukan kenapa, dan kenapa itulah yang dicari orang saat memeriksanya.
    /// </summary>
    [Required(AllowEmptyStrings = false)]
    [MaxLength(BatasMasukan.Deskripsi)]
    public string Alasan { get; init; } = string.Empty;
}

public record PerubahanPeranResponse(
    Guid Id,
    Guid UserId,
    Guid DiubahOlehAdminId,
    IReadOnlyList<string> Sebelum,
    IReadOnlyList<string> Sesudah,
    string Alasan,
    DateTime DiubahPada)
{
    public static PerubahanPeranResponse Dari(UserRoleChange p) => new(
        p.Id,
        p.UserId,
        p.ChangedByAdminId,
        [.. p.RolesBefore.Select(r => r.ToString())],
        [.. p.RolesAfter.Select(r => r.ToString())],
        p.Reason,
        p.ChangedAt);
}

/// <summary>
/// Penyaring dan halaman untuk daftar order admin.
/// </summary>
/// <remarks>
/// <see cref="Status"/> boleh kosong, dan itu bukan kelalaian: admin memakai daftar ini untuk
/// dua hal yang berbeda. Menyaring ke <c>Permintaan</c> memberinya antrean pekerjaan, yaitu
/// permintaan Jalur B yang menunggu ditawari. Tanpa penyaring, ia melihat seluruh order,
/// yang dibutuhkan saat menelusuri keluhan.
/// </remarks>
public record PermintaanDaftarOrder : PermintaanHalaman
{
    public OrderStatus? Status { get; init; }
}
