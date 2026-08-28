namespace UpnvjSuruh.Api.Media;

/// <summary>
/// Tempat foto bukti pekerjaan disimpan.
/// </summary>
/// <remarks>
/// Untuk sekarang berkasnya ditaruh di cakram server sendiri. Itu cukup untuk satu server
/// dan untuk sidang, dan sengaja tidak dibuat lebih pintar daripada itu: penyimpanan objek
/// (S3, Supabase Storage, Cloudinary) baru punya arti ketika servernya lebih dari satu, dan
/// menambahkannya sekarang berarti menanggung akun, kunci, dan tagihan pihak ketiga untuk
/// masalah yang belum ada.
///
/// Yang penting sudah dipisahkan di sini, jadi pindah ke penyimpanan objek nanti mengganti
/// isi kelas ini saja: nama berkas dibuat server, bukan diterima dari pengunggah, dan yang
/// dikembalikan adalah URL, bukan jalur berkas.
/// </remarks>
public class PenyimpanFoto(IWebHostEnvironment lingkungan, IConfiguration konfigurasi)
{
    /// <summary>Bagian URL yang menandai berkas media. Dipakai juga saat memeriksa keabsahan.</summary>
    public const string Prefiks = "/media/bukti/";

    /// <summary>Batas ukuran satu foto.</summary>
    /// <remarks>
    /// Foto kamera ponsel sekarang jarang lebih dari lima megabita. Batas ini bukan soal
    /// cakram penuh melainkan soal satu permintaan yang bisa menahan memori server selama
    /// pengunggahannya, dan tanpa batas, satu orang cukup mengirim berkas raksasa berulang
    /// kali untuk membuat server berhenti melayani yang lain.
    /// </remarks>
    public const long BatasUkuranByte = 8 * 1024 * 1024;

    private string Akar => konfigurasi["Media:Folder"]
                           ?? Path.Combine(lingkungan.ContentRootPath, "berkas", "bukti");

    /// <summary>Menyimpan satu foto, mengembalikan URL untuk membacanya.</summary>
    public async Task<string> SimpanAsync(Guid orderId, Stream isi, string ekstensi, CancellationToken batal)
    {
        Directory.CreateDirectory(Akar);

        // Namanya dibuat server dari id order ditambah nilai acak, tidak pernah memakai nama
        // berkas kiriman. Nama kiriman bisa berisi "..\" yang menuntun penulisan keluar dari
        // folder ini, dan bisa bertabrakan dengan berkas milik order lain.
        var nama = $"{orderId:N}-{Guid.NewGuid():N}{ekstensi}";
        var jalur = Path.Combine(Akar, nama);

        await using var tujuan = File.Create(jalur);
        await isi.CopyToAsync(tujuan, batal);

        return Prefiks + nama;
    }

    /// <summary>
    /// Benar kalau URL itu benar-benar menunjuk foto yang pernah disimpan server ini.
    /// </summary>
    /// <remarks>
    /// Endpoint penutupan order menerima URL foto sebagai teks, dan teks dari klien bisa
    /// berisi apa saja: tautan ke gambar orang lain, tautan ke situs mana pun, atau URL
    /// yang tidak menunjuk apa-apa. Tanpa pemeriksaan ini, "wajib ada foto bukti" cuma
    /// berarti "wajib ada tulisan di kolom foto".
    /// </remarks>
    public bool Sah(string? url)
    {
        if (string.IsNullOrWhiteSpace(url) || !url.StartsWith(Prefiks, StringComparison.Ordinal))
        {
            return false;
        }

        var nama = url[Prefiks.Length..];

        // Nama yang mengandung pemisah jalur atau titik ganda bisa menuntun pemeriksaan
        // keberadaan berkas ke luar folder media. Ditolak sebelum menyentuh cakram.
        //
        // GetFileName dipakai sebagai penyaringnya, bukan daftar karakter terlarang yang
        // ditulis tangan: ia membuang segalanya sampai pemisah jalur terakhir, jadi nama
        // yang tidak berubah setelah melewatinya sudah pasti tidak memuat satu pun.
        if (nama.Length == 0 || Path.GetFileName(nama) != nama || nama.Contains(".."))
        {
            return false;
        }

        return File.Exists(Path.Combine(Akar, nama));
    }

    /// <summary>Folder tempat berkas dilayani, dibuat kalau belum ada.</summary>
    public string FolderSiap()
    {
        Directory.CreateDirectory(Akar);
        return Akar;
    }
}
