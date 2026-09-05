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

/// <param name="NamaAdmin">
/// Nama admin yang mengubahnya, atau <c>-</c> kalau akunnya sudah tidak ada.
///
/// Ikut dibawa karena pertanyaan yang melahirkan catatan ini "siapa yang mengangkat orang ini
/// jadi runner", dan deretan UUID bukan jawaban atas pertanyaan yang memakai kata "siapa".
/// Idnya tetap dikirim di samping namanya: nama bisa sama antara dua orang dan bisa disunting
/// pemiliknya sendiri sejak bagian 52, sedangkan yang harus tetap bisa ditunjuk oleh catatan
/// audit adalah akunnya.
/// </param>
public record PerubahanPeranResponse(
    Guid Id,
    Guid UserId,
    Guid DiubahOlehAdminId,
    string NamaAdmin,
    IReadOnlyList<string> Sebelum,
    IReadOnlyList<string> Sesudah,
    string Alasan,
    DateTime DiubahPada)
{
    public static PerubahanPeranResponse Dari(UserRoleChange p, string? namaAdmin = null) => new(
        p.Id,
        p.UserId,
        p.ChangedByAdminId,
        namaAdmin ?? "-",
        [.. p.RolesBefore.Select(r => r.ToString())],
        [.. p.RolesAfter.Select(r => r.ToString())],
        p.Reason,
        p.ChangedAt);
}

/// <summary>Satu kali sebuah akun ditangguhkan, atau dipulihkan kembali.</summary>
/// <remarks>
/// <see cref="Ditangguhkan"/> menyebut arah keputusannya, bukan keadaan akun sesudahnya, dan
/// keduanya kebetulan sama nilainya: baris ini selalu berarti pindah dari satu keadaan ke
/// keadaan lain, jadi tidak ada arah ketiga yang perlu dibedakan.
/// </remarks>
public record PerubahanPenangguhanResponse(
    Guid Id,
    Guid UserId,
    Guid DiubahOlehAdminId,
    string NamaAdmin,
    bool Ditangguhkan,
    string Alasan,
    DateTime DiubahPada)
{
    public static PerubahanPenangguhanResponse Dari(
        UserSuspensionChange p, string? namaAdmin = null) => new(
        p.Id,
        p.UserId,
        p.ChangedByAdminId,
        namaAdmin ?? "-",
        p.Suspended,
        p.Reason,
        p.ChangedAt);
}

/// <summary>Satu kali seorang runner melepas order yang sudah dipegangnya.</summary>
/// <remarks>
/// Membawa kode ordernya, bukan cuma idnya. Yang membacanya sedang menimbang apakah sebuah
/// akun pantas dihentikan, dan deretan id tanpa kode berarti ia harus membuka satu per satu
/// untuk tahu order mana saja yang dimaksud.
/// </remarks>
public record PelepasanOrderResponse(
    Guid Id,
    Guid OrderId,
    string KodeOrder,
    Guid RunnerId,
    string Alasan,
    DateTime DilepasPada)
{
    public static PelepasanOrderResponse Dari(OrderRelease p) => new(
        p.Id,
        p.OrderId,
        p.Order?.OrderCode ?? "-",
        p.RunnerId,
        p.Reason,
        p.ReleasedAt);
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

    /// <summary>
    /// Kalau benar, cuma order yang sedang menunggu keputusan pembatalan yang dikembalikan.
    /// </summary>
    /// <remarks>
    /// Penyaring tersendiri, bukan salah satu nilai <see cref="Status"/>, karena menunggu
    /// keputusan pembatalan bukan status order: ordernya tetap MencariRunner atau Dikerjakan
    /// sementara permintaannya menunggu, dan runner yang memegangnya tetap harus melihatnya
    /// di daftar pekerjaannya sampai admin memutuskan. Menjadikannya status berarti satu
    /// order harus punya dua status sekaligus.
    ///
    /// Boleh dipakai bersama <see cref="Status"/>, dan keduanya menyempit bersama.
    /// </remarks>
    public bool? MintaBatal { get; init; }

    /// <summary>
    /// Kalau benar, cuma order yang sedang macet yang dikembalikan
    /// (<see cref="Domain.OrderMacet"/>).
    /// </summary>
    /// <remarks>
    /// Penyaring tersendiri dengan alasan yang sama seperti <see cref="MintaBatal"/>: macet
    /// bukan status order melainkan berapa lama ia sudah berada di statusnya. Sebelum ada
    /// penyaring ini, order yang macet cuma "ada" selama seseorang kebetulan menatap halaman
    /// tabel yang memuatnya, karena yang menandainya perhitungan di layar.
    /// </remarks>
    public bool? Macet { get; init; }
}

/// <summary>
/// Admin membatalkan order yang sudah dibayar.
/// </summary>
/// <remarks>
/// Alasan wajib diisi, mengikuti pola yang sama dengan <see cref="TetapkanPeranRequest"/>:
/// catatan tanpa alasan cuma memberi tahu bahwa sesuatu terjadi, bukan kenapa, dan uang yang
/// dikembalikan tanpa alasan tercatat adalah pertanyaan yang menunggu ditanyakan belakangan.
/// </remarks>
public record BatalkanOrderRequest
{
    [Required(AllowEmptyStrings = false)]
    [MaxLength(BatasMasukan.Deskripsi)]
    public string Alasan { get; init; } = string.Empty;
}

/// <summary>
/// Admin menangguhkan sebuah akun, atau memulihkannya kembali.
/// </summary>
/// <remarks>
/// Alasan wajib di kedua arah, mengikuti aturan yang sama dengan perubahan peran. Yang
/// dihentikan di sini kemampuan seseorang memakai aplikasi sama sekali, dan tindakan
/// sebesar itu tanpa sebab tercatat adalah pertanyaan yang menunggu ditanyakan belakangan —
/// biasanya oleh orang yang akunnya dihentikan.
/// </remarks>
public record TangguhkanAkunRequest
{
    [Required(AllowEmptyStrings = false)]
    [MaxLength(BatasMasukan.Deskripsi)]
    public string Alasan { get; init; } = string.Empty;
}
