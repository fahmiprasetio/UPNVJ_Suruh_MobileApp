using System.ComponentModel.DataAnnotations;
using UpnvjSuruh.Api.Data;

namespace UpnvjSuruh.Api.Contracts;

/// <summary>
/// Satu halaman dari sebuah daftar, beserta keterangan secukupnya untuk mengambil sisanya.
/// </summary>
/// <remarks>
/// Daftar yang dikirim sebagai larik telanjang tidak punya tempat menaruh <c>Total</c>, dan
/// tanpa angka itu yang membacanya tidak bisa membedakan "ini memang semuanya" dari "ini
/// baru sebagian". Layar yang menampilkan dua puluh order padahal ada enam puluh tidak
/// terlihat seperti bug; ia terlihat seperti riwayat yang memang segitu.
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
/// Halaman yang diminta pemanggil.
/// </summary>
/// <remarks>
/// Keduanya punya nilai bawaan, jadi pemanggil yang tidak menyebut apa-apa tetap menerima
/// jawaban yang berbatas. Itu bagian yang paling penting: endpoint yang baru berbatas kalau
/// diminta akan tetap tidak berbatas bagi setiap pemanggil yang lupa memintanya, dan yang
/// paling mungkin lupa adalah kode yang ditulis paling belakangan.
/// </remarks>
public record PermintaanHalaman
{
    [Range(1, int.MaxValue, ErrorMessage = "Nomor halaman dimulai dari 1.")]
    public int Halaman { get; init; } = 1;

    [Range(1, BatasHalaman.Maksimal, ErrorMessage = "Ukuran halaman paling banyak 100.")]
    public int Ukuran { get; init; } = BatasHalaman.Bawaan;

    /// <summary>Baris yang dilewati untuk sampai ke halaman ini.</summary>
    public int Dilewati => (Halaman - 1) * Ukuran;
}
