using System.ComponentModel.DataAnnotations;
using System.Text.RegularExpressions;

namespace UpnvjSuruh.Api.Contracts;

/// <summary>
/// Menolak nomor HP yang bentuknya salah.
/// </summary>
/// <remarks>
/// Polanya sama persis dengan yang dipakai sisi mobile untuk validasi lokal sebelum
/// terkirim (lihat komentar di sana): diawali "08", diikuti 8 sampai 13 angka lagi. Kalau
/// keduanya berbeda, ada nomor yang lolos di satu sisi lalu ditolak di sisi lain, dan
/// pengguna melihat penolakan tanpa tahu bagian mana yang salah.
///
/// Ditulis sebagai atribut sendiri, bukan <c>[RegularExpression]</c> yang polanya diketik
/// ulang di setiap DTO, karena pola dan pesannya sebelum ini disalin empat kali: sekali
/// salah ketik di salah satunya berarti nomor yang ditolak di satu endpoint diam-diam
/// diterima di endpoint lain.
/// </remarks>
[AttributeUsage(AttributeTargets.Property, AllowMultiple = false)]
public sealed partial class NomorHpAttribute : ValidationAttribute
{
    public override bool IsValid(object? nilai)
    {
        // Kosong bukan urusan atribut ini. Yang wajib diisi ditandai [Required], dan atribut
        // yang ikut-ikutan menolak kosong akan menghasilkan dua pesan galat untuk satu
        // kesalahan yang sama.
        if (nilai is null) return true;
        return nilai is string teks && Pola().IsMatch(teks);
    }

    public override string FormatErrorMessage(string nama) =>
        "Nomor HP harus diawali 08 dan berisi 10 sampai 15 angka.";

    [GeneratedRegex(@"^08\d{8,13}$")]
    private static partial Regex Pola();
}
