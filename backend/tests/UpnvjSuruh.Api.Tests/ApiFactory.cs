using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using UpnvjSuruh.Api.Auth;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Menyalakan API sungguhan di dalam proses tes, lengkap dengan pipeline autentikasinya.
///
/// Rahasianya diisi di sini, bukan diambil dari user-secrets mesin yang menjalankan,
/// supaya tes memberi hasil yang sama di laptop siapa pun dan di CI yang tidak punya
/// rahasia apa-apa. Tidak ada kueri yang menyentuh basis data di tes ini, jadi connection
/// string cukup diisi sesuatu yang berbentuk benar.
/// </summary>
public class ApiFactory : WebApplicationFactory<Program>
{
    public const string SigningKey = "kunci-uji-yang-cukup-panjang-untuk-hmac-sha256";
    public const string Issuer = "UpnvjSuruh.Api";
    public const string Audience = "UpnvjSuruh.Mobile";
    public const string WebhookSecret = "rahasia-webhook-uji-yang-cukup-panjang-sekali";

    /// <summary>
    /// Connection string yang dipakai. Tes yang benar-benar menyentuh basis data
    /// menimpanya lewat sini, bukan lewat UseSetting, karena konfigurasi host yang
    /// dipasang di bawah menang atas setelan web host.
    /// </summary>
    protected virtual string ConnectionString => "Host=localhost;Database=upnvj_suruh_test";

    /// <summary>
    /// Folder foto bukti untuk satu pabrik, sekali pakai.
    ///
    /// Diarahkan keluar dari pohon sumber dengan sengaja. Bawaan <c>PenyimpanFoto</c> adalah
    /// folder di dalam proyek API, dan tes yang benar-benar mengunggah akan meninggalkan
    /// berkas di sana: ikut terbawa ke commit berikutnya kalau ada yang lupa, dan bocor dari
    /// satu jalannya tes ke jalan berikutnya sehingga tes bisa lulus karena berkas yang
    /// ditinggalkan tes sebelumnya.
    /// </summary>
    public string FolderMedia { get; } = Path.Combine(
        Path.GetTempPath(), "upnvj-uji-media", Guid.NewGuid().ToString("N"));

    protected override IHost CreateHost(IHostBuilder builder)
    {
        builder.ConfigureHostConfiguration(config =>
        {
            config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Jwt:SigningKey"] = SigningKey,
                ["Jwt:Issuer"] = Issuer,
                ["Jwt:Audience"] = Audience,
                ["Jwt:MasaBerlakuMenit"] = "60",
                ["Webhook:Secret"] = WebhookSecret,
                // Bawaannya sengaja tanpa kredensial: tes yang cuma memeriksa pipeline
                // tidak menjalankan kueri apa pun, jadi yang dibutuhkan hanya string yang
                // bentuknya sah supaya DbContext bisa dibangun. Menaruh password sungguhan
                // di sini membuat pemindai rahasia berbunyi setiap kali, dan pemindai yang
                // selalu berbunyi akan diabaikan justru saat menemukan yang asli.
                ["ConnectionStrings:Default"] = ConnectionString,
                // Dikosongkan, bukan dibiarkan tidak disebut.
                //
                // WebApplicationFactory menyalakan aplikasi sebagai Development, dan
                // Development ikut membaca user-secrets proyek API. Sejak nomor admin
                // pertama disimpan di sana, seluruh tes mulai menyalakan AdminAwal, yang
                // menanyakan tabel Users sebelum migrasi dijalankan, dan gagal dengan
                // "relation Users does not exist" yang tidak menyebut-nyebut sebabnya.
                //
                // Yang lebih penting daripada gagalnya: hasil tes jadi bergantung pada isi
                // user-secrets mesin yang menjalankannya. Tes yang lulus di laptop yang
                // belum memasang nomor admin dan gagal di laptop yang sudah bukan tes yang
                // mengukur kode.
                [AdminAwal.KunciKonfigurasi] = string.Empty,
                ["Media:Folder"] = FolderMedia,
            });
        });

        return base.CreateHost(builder);
    }

    /// <summary>
    /// Membuang folder medianya bersama pabriknya.
    ///
    /// Dibungkus try karena kegagalan membersihkan bukan kegagalan tes: berkas sementara yang
    /// tertinggal di folder temp mesin adalah kerapian, sedangkan tes yang dilaporkan gagal
    /// karena penghapusan berkas akan mengirim orang menelusuri kode yang sebenarnya benar.
    /// </summary>
    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);

        if (!disposing) return;

        try
        {
            if (Directory.Exists(FolderMedia)) Directory.Delete(FolderMedia, recursive: true);
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }
    }
}
