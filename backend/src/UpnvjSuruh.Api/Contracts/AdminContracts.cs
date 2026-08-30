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
/// Satu halaman dari sebuah daftar, beserta keterangan secukupnya untuk mengambil sisanya.
/// </summary>
/// <remarks>
/// Daftar yang dikirim sebagai larik telanjang tidak punya tempat menaruh <c>Total</c>, dan
/// tanpa angka itu yang membacanya tidak bisa membedakan "ini memang semuanya" dari "ini
/// baru sebagian". Dashboard yang menampilkan "menunggu penawaran: 20" padahal ada 63 akan
/// terbaca sebagai kabar baik.
///
/// Untuk sekarang hanya daftar order admin yang memakainya, jadi ia tinggal di berkas ini.
/// Begitu endpoint kedua ikut berhalaman, tempatnya pindah ke berkas sendiri.
/// </remarks>
/// <param name="Isi">Baris pada halaman ini.</param>
/// <param name="Total">Seluruh baris yang cocok dengan penyaringnya, bukan cuma yang terkirim.</param>
/// <param name="Halaman">Nomor halaman ini, dimulai dari satu.</param>
/// <param name="UkuranHalaman">Banyak baris terbanyak dalam satu halaman.</param>
public record HalamanResponse<T>(
    IReadOnlyList<T> Isi,
    int Total,
    int Halaman,
    int UkuranHalaman)
{
    /// <summary>
    /// Banyak halaman seluruhnya. Bisa dihitung sendiri oleh yang membacanya, dan justru
    /// karena itu ditulis di sini: pembulatan ke atas yang dikerjakan ulang di setiap klien
    /// adalah tempat yang sama untuk membuat kesalahan yang sama berkali-kali.
    /// </summary>
    public int TotalHalaman => UkuranHalaman <= 0 ? 0 : (int)Math.Ceiling((double)Total / UkuranHalaman);
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
public record PermintaanDaftarOrder
{
    public OrderStatus? Status { get; init; }

    [Range(1, int.MaxValue, ErrorMessage = "Nomor halaman dimulai dari 1.")]
    public int Halaman { get; init; } = 1;

    [Range(1, BatasHalaman.Maksimal, ErrorMessage = "Ukuran halaman paling banyak 100.")]
    public int Ukuran { get; init; } = BatasHalaman.Bawaan;
}
