using System.ComponentModel.DataAnnotations;

namespace UpnvjSuruh.Api.Contracts;

/// <summary>
/// Menolak waktu yang sudah lewat.
/// </summary>
/// <remarks>
/// Dipakai untuk jadwal mulai pekerjaan, baik yang diminta klien maupun yang ditawarkan
/// admin. Jadwal di masa lalu bukan sekadar aneh: order Jalur B disusun mengelilingi
/// jadwalnya, dan yang jadwalnya sudah lewat akan tampil sebagai pekerjaan yang terlambat
/// sejak detik ia dibuat, padahal tidak ada yang terlambat.
///
/// Toleransinya ada dengan sengaja. Waktu di sini berasal dari jam perangkat pengguna,
/// yang boleh meleset beberapa menit dari jam server, dan orang butuh waktu antara memilih
/// jadwal dan menekan kirim. Tanpa toleransi, memilih "sekarang" lalu mengisi sisa formulir
/// akan ditolak karena beberapa menit sudah berlalu, dan penolakan itu terbaca sebagai
/// aplikasi yang rusak.
///
/// Batas atas sengaja tidak ada. Order untuk tahun depan memang tidak masuk akal, tapi yang
/// menilainya admin saat membaca permintaannya, bukan aturan yang harus menebak berapa jauh
/// ke depan yang masih wajar.
/// </remarks>
[AttributeUsage(AttributeTargets.Property, AllowMultiple = false)]
public sealed class WaktuDiMasaDepanAttribute : ValidationAttribute
{
    /// <summary>Seberapa jauh ke belakang masih diterima.</summary>
    public const int ToleransiMenit = 5;

    public override bool IsValid(object? nilai)
    {
        // Kosong bukan urusan atribut ini. Yang wajib diisi ditandai [Required], dan atribut
        // yang ikut-ikutan menolak kosong akan menghasilkan dua pesan galat untuk satu
        // kesalahan yang sama.
        if (nilai is null) return true;
        if (nilai is not DateTime waktu) return false;

        return waktu.ToUniversalTime()
               >= DateTime.UtcNow.AddMinutes(-ToleransiMenit);
    }

    public override string FormatErrorMessage(string nama) =>
        "Jadwal mulai tidak boleh di waktu yang sudah lewat.";
}
