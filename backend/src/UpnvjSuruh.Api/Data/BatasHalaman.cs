namespace UpnvjSuruh.Api.Data;

/// <summary>
/// Batas ukuran satu halaman daftar. Kembaran <see cref="BatasMasukan"/> untuk banyaknya
/// baris, bukan untuk panjang teks.
///
/// Ada karena endpoint yang mengembalikan daftar tanpa batas selalu terlihat baik-baik saja
/// di awal: pada basis data berisi belasan order, "kirim semuanya" dan "kirim dua puluh"
/// tidak ada bedanya. Bedanya baru muncul setelah aplikasinya dipakai sungguhan, yaitu saat
/// paling tidak enak untuk mengubah bentuk jawaban.
/// </summary>
public static class BatasHalaman
{
    /// <summary>Dipakai kalau pemanggil tidak menyebut ukuran.</summary>
    public const int Bawaan = 20;

    /// <summary>
    /// Ukuran terbesar yang boleh diminta.
    ///
    /// Ditolak, bukan dijepit diam-diam. Pemanggil yang meminta seribu baris lalu menerima
    /// seratus akan mengira ia sudah menerima semuanya, dan sembilan ratus sisanya hilang
    /// tanpa ada yang tahu. Galat yang menyebutkan batasnya jauh lebih murah daripada
    /// laporan yang diam-diam kurang.
    /// </summary>
    public const int Maksimal = 100;
}
