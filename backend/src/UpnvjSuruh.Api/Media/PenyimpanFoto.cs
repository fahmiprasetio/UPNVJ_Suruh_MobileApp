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
    /// <summary>
    /// Jalur controller yang melayani berkasnya. Dipakai di <c>[Route]</c>, yang cuma
    /// menerima konstanta, dan sekaligus menyusun <see cref="Prefiks"/> supaya alamat yang
    /// disimpan di basis data tidak bisa berselisih dengan alamat yang benar-benar dilayani.
    /// </summary>
    public const string Rute = "media/bukti";

    /// <summary>Bagian URL yang menandai berkas media. Dipakai juga saat memeriksa keabsahan.</summary>
    public const string Prefiks = "/" + Rute + "/";

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

    /// <summary>
    /// Awalan nama berkas milik satu order.
    ///
    /// Ditulis sekali dan dipakai dua sisi: yang menyimpan dan yang memeriksa. Kalau
    /// masing-masing menyusun bentuknya sendiri, salah satu bisa diubah tanpa yang lain, dan
    /// yang terjadi adalah foto yang baru saja diunggah ditolak sebagai bukan miliknya.
    /// </summary>
    private static string Awalan(Guid orderId) => $"{orderId:N}-";

    /// <summary>Menyimpan satu foto, mengembalikan URL untuk membacanya.</summary>
    public async Task<string> SimpanAsync(Guid orderId, Stream isi, string ekstensi, CancellationToken batal)
    {
        Directory.CreateDirectory(Akar);

        // Namanya dibuat server dari id order ditambah nilai acak, tidak pernah memakai nama
        // berkas kiriman. Nama kiriman bisa berisi "..\" yang menuntun penulisan keluar dari
        // folder ini, dan bisa bertabrakan dengan berkas milik order lain.
        var nama = $"{Awalan(orderId)}{Guid.NewGuid():N}{ekstensi}";
        var jalur = Path.Combine(Akar, nama);

        await using var tujuan = File.Create(jalur);
        await isi.CopyToAsync(tujuan, batal);

        return Prefiks + nama;
    }

    /// <summary>
    /// Benar kalau URL itu menunjuk foto yang pernah disimpan server ini <em>untuk order
    /// tersebut</em>.
    /// </summary>
    /// <remarks>
    /// Endpoint penutupan order menerima URL foto sebagai teks, dan teks dari klien bisa
    /// berisi apa saja: tautan ke gambar orang lain, tautan ke situs mana pun, atau URL
    /// yang tidak menunjuk apa-apa. Tanpa pemeriksaan ini, "wajib ada foto bukti" cuma
    /// berarti "wajib ada tulisan di kolom foto".
    ///
    /// Ordernya ikut diperiksa, bukan cuma keberadaan berkasnya. Sebelumnya cukup berkas itu
    /// pernah diunggah ke server ini, siapa pun pemiliknya dan untuk order mana pun, sehingga
    /// runner yang memegang beberapa order bisa memotret sekali lalu menutup semuanya dengan
    /// foto yang sama. Bukti yang boleh dipakai ulang bukan bukti apa-apa: yang dibuktikan
    /// cuma bahwa satu pekerjaan pernah dikerjakan, bukan pekerjaan yang sedang ditutup ini.
    /// </remarks>
    public bool Sah(string? url, Guid orderId)
    {
        if (string.IsNullOrWhiteSpace(url) || !url.StartsWith(Prefiks, StringComparison.Ordinal))
        {
            return false;
        }

        var nama = url[Prefiks.Length..];

        // Diperiksa sebelum menyentuh cakram, karena ini pemeriksaan yang paling murah dan
        // paling sering menolak: nama yang tidak berawalan id order ini sudah pasti bukan
        // foto untuk order ini, ada atau tidak ada berkasnya.
        if (!nama.StartsWith(Awalan(orderId), StringComparison.Ordinal)) return false;

        return Jalur(nama) is not null;
    }

    /// <summary>
    /// Jalur berkas di cakram, atau <c>null</c> kalau namanya tidak aman atau berkasnya tidak
    /// ada. Kedua sebab itu sengaja tidak dibedakan: yang memanggil menjawab keduanya dengan
    /// 404 yang sama, dan membedakannya berarti memberi tahu penebak mana tebakan yang hampir
    /// benar.
    /// </summary>
    public string? Jalur(string nama)
    {
        // Nama yang mengandung pemisah jalur atau titik ganda bisa menuntun pembacaan ke luar
        // folder media. Ditolak sebelum menyentuh cakram.
        //
        // GetFileName dipakai sebagai penyaringnya, bukan daftar karakter terlarang yang
        // ditulis tangan: ia membuang segalanya sampai pemisah jalur terakhir, jadi nama
        // yang tidak berubah setelah melewatinya sudah pasti tidak memuat satu pun.
        if (nama.Length == 0 || Path.GetFileName(nama) != nama || nama.Contains("..")) return null;

        var jalur = Path.Combine(Akar, nama);
        return File.Exists(jalur) ? jalur : null;
    }

    /// <summary>
    /// Order pemilik berkas ini, dibaca dari namanya, atau <c>null</c> kalau namanya tidak
    /// berbentuk seperti yang dibuat <see cref="SimpanAsync"/>.
    ///
    /// Inilah yang membuat berkasnya bisa dijaga tanpa tabel tambahan: nama berkas dibuat
    /// server dan memuat id ordernya, jadi id itu bisa dibaca kembali dan dipakai memutuskan
    /// siapa yang boleh membukanya.
    /// </summary>
    public static Guid? OrderDari(string nama)
    {
        var pisah = nama.IndexOf('-', StringComparison.Ordinal);
        if (pisah < 0) return null;

        return Guid.TryParseExact(nama[..pisah], "N", out var id) ? id : null;
    }

    /// <summary>
    /// Tipe konten yang dilayani untuk nama berkas ini, atau <c>null</c> kalau bukan jenis
    /// yang pernah disimpan kelas ini.
    ///
    /// Ditentukan dari daftar yang ditulis di sini, bukan ditebak dari ekstensinya lewat
    /// pemetaan umum. Yang pernah masuk ke folder ini cuma dua jenis, karena endpoint
    /// unggahnya cuma menerima dua, dan daftar yang lebih panjang dari kenyataan cuma
    /// menambah jenis yang bisa dilayani kalau suatu hari ada berkas lain yang masuk.
    /// </summary>
    public static string? TipeKonten(string nama) => Path.GetExtension(nama) switch
    {
        ".jpg" => "image/jpeg",
        ".png" => "image/png",
        _ => null,
    };
}
