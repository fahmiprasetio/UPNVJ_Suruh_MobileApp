using System.ComponentModel.DataAnnotations;
using UpnvjSuruh.Api.Data;

namespace UpnvjSuruh.Api.Contracts;

/// <summary>
/// Permintaan menghapus akun sendiri, dibuktikan lewat kode OTP ke nomor akunnya.
/// </summary>
/// <remarks>
/// Nomor dan kode, bukan token. Bentuk yang sama dengan <see cref="MasukRequest"/> dipakai
/// dengan sengaja: yang membuktikan seseorang berhak atas akun ini adalah kemampuannya
/// menerima kode di nomor itu, sama seperti saat masuk. Karena tidak butuh token, jalur yang
/// sama bisa dipakai aplikasi (pengguna yang sedang masuk) maupun halaman publik penghapusan
/// akun (pengguna yang sudah tidak punya aplikasinya, atau tidak bisa masuk lagi) tanpa
/// membuat dua aturan yang bisa berbeda.
///
/// Tidak ada kolom alasan. Alasan orang pergi bukan data yang dibutuhkan untuk menghapus
/// akunnya, dan menyimpannya berarti menambah data pribadi justru pada permintaan yang
/// tujuannya mengurangi data pribadi.
/// </remarks>
public record HapusAkunRequest
{
    [Required(AllowEmptyStrings = false)]
    [MaxLength(BatasMasukan.NomorHp)]
    [NomorHp]
    public string NoHp { get; init; } = string.Empty;

    [Required(AllowEmptyStrings = false)]
    [RegularExpression(@"^\d{6}$", ErrorMessage = "Kode OTP terdiri dari 6 angka.")]
    public string Kode { get; init; } = string.Empty;
}

/// <summary>
/// Jawaban pemeriksaan awal: apakah akun ini boleh dihapus sekarang, dan kalau belum, kenapa.
/// </summary>
/// <param name="BisaDihapus">Benar kalau tidak ada satu pun penghalang.</param>
/// <param name="Penghalang">
/// Kalimat utuh yang siap ditampilkan apa adanya kepada pemiliknya, satu per penghalang.
/// Kosong kalau <paramref name="BisaDihapus"/> benar.
/// </param>
public record PraPenghapusanResponse(bool BisaDihapus, IReadOnlyList<string> Penghalang);
