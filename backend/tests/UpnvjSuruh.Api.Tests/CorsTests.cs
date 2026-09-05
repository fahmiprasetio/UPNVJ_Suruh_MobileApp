using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Siapa yang boleh memanggil API ini dari dalam peramban.
///
/// Dulu kebijakannya cuma didaftarkan di Development, dan itu benar selama satu-satunya
/// pemakai peramban adalah aplikasi Flutter versi web saat mengembangkan. Sejak dashboard
/// admin ada, tidak lagi: ia seluruhnya berjalan di peramban, dan tanpa kebijakan produksi
/// ia akan gagal memanggil API begitu dipasang di server sungguhan — kegagalan yang muncul
/// persis di menit terakhir, dan yang perbaikan tercepatnya `AllowAnyOrigin`.
///
/// Yang dijaga tes ini justru batas-batasnya, bukan jalur yang berhasil: asal yang tidak
/// terdaftar tetap ditolak, dan tidak ada jawaban yang mengizinkan kredensial peramban ikut.
/// </summary>
public class CorsTests(ApiFactory pabrik) : IClassFixture<ApiFactory>
{
    private const string AsalTerdaftar = "https://admin.upnvjsuruh.example";

    /// <summary>
    /// Satu permintaan preflight, persis seperti yang dikirim peramban sebelum permintaan
    /// sesungguhnya berangkat.
    /// </summary>
    private static async Task<HttpResponseMessage> PreflightAsync(HttpClient klien, string asal)
    {
        var permintaan = new HttpRequestMessage(HttpMethod.Options, "/api/orders/saya");
        permintaan.Headers.Add("Origin", asal);
        permintaan.Headers.Add("Access-Control-Request-Method", "GET");
        permintaan.Headers.Add("Access-Control-Request-Headers", "authorization");
        return await klien.SendAsync(permintaan);
    }

    private static bool Mengizinkan(HttpResponseMessage jawaban) =>
        jawaban.Headers.Contains("Access-Control-Allow-Origin");

    /// <summary>
    /// Inti penjagaannya. Konfigurasi yang kosong berarti tidak ada asal luar yang
    /// diizinkan, bukan semua diizinkan.
    /// </summary>
    [Fact]
    public async Task AsalYangTidakTerdaftarTidakDiizinkan()
    {
        var jawaban = await PreflightAsync(pabrik.CreateClient(), "https://jahat.example");

        Assert.False(Mengizinkan(jawaban));
    }

    /// <summary>
    /// Loopback diizinkan saat mengembangkan, karena aplikasi versi web dan dashboard
    /// dijalankan dari sana. Pabrik uji menyalakan aplikasi sebagai Development.
    /// </summary>
    [Fact]
    public async Task AsalLoopbackDiizinkanSaatMengembangkan()
    {
        var jawaban = await PreflightAsync(pabrik.CreateClient(), "http://localhost:5173");

        Assert.True(Mengizinkan(jawaban));
    }

    /// <summary>
    /// Yang paling penting tidak ada.
    ///
    /// Tanpa `AllowCredentials`, kesalahan konfigurasi asal yang paling berbahaya —
    /// halaman mana pun memanggil API ini membawa sesi korban — tidak mungkin terjadi,
    /// karena peramban tidak akan mengirimkan apa pun milik korban ke sini. Yang dibawa
    /// dashboard maupun aplikasi adalah header Authorization, bukan cookie, jadi tidak ada
    /// yang hilang karenanya.
    /// </summary>
    [Fact]
    public async Task JawabanCorsTidakPernahMengizinkanKredensialPeramban()
    {
        var jawaban = await PreflightAsync(pabrik.CreateClient(), "http://localhost:5173");

        Assert.True(Mengizinkan(jawaban), "asal ini seharusnya diizinkan");
        Assert.False(jawaban.Headers.Contains("Access-Control-Allow-Credentials"));
    }

    /// <summary>
    /// Jalur produksinya: asal disebutkan satu per satu di konfigurasi, tidak pernah
    /// ditebak dan tidak punya nilai bawaan.
    /// </summary>
    [Fact]
    public async Task AsalYangDisebutkanKonfigurasiDiizinkan()
    {
        using var berkonfigurasi = new PabrikBerkonfigurasi();

        var jawaban = await PreflightAsync(berkonfigurasi.CreateClient(), AsalTerdaftar);

        Assert.True(Mengizinkan(jawaban));
    }

    /// <summary>
    /// Dan asal lain tetap ditolak walau daftarnya sudah berisi: yang diizinkan yang
    /// disebutkan, bukan "ada daftarnya berarti terbuka". Asal di tes ini sengaja dipilih
    /// yang berawalan sama persis dengan yang terdaftar, karena pencocokan yang keliru
    /// ditulis sebagai "diawali" alih-alih "sama dengan" adalah kesalahan yang lolos dari
    /// mata dan meloloskan seluruh subdomain milik penyerang.
    /// </summary>
    [Fact]
    public async Task AsalLainTetapDitolakWalauDaftarnyaBerisi()
    {
        using var berkonfigurasi = new PabrikBerkonfigurasi();

        var jawaban = await PreflightAsync(
            berkonfigurasi.CreateClient(), AsalTerdaftar + ".jahat.example");

        Assert.False(Mengizinkan(jawaban));
    }

    /// <summary>
    /// Pabrik uji dengan satu asal produksi terdaftar.
    ///
    /// Konfigurasinya ditambahkan lewat <c>ConfigureHostConfiguration</c>, bukan lewat
    /// <c>WithWebHostBuilder</c>: di model minimal hosting, <c>builder.Configuration</c>
    /// sudah final ketika kode di Program.cs membacanya, jadi konfigurasi web host yang
    /// ditambahkan belakangan tidak pernah terlihat oleh kebijakan CORS yang dibangun di
    /// sana. Percobaan pertama memakai cara itu dan tesnya gagal, bukan kodenya.
    /// </summary>
    private sealed class PabrikBerkonfigurasi : ApiFactory
    {
        protected override IHost CreateHost(IHostBuilder builder)
        {
            builder.ConfigureHostConfiguration(konfigurasi =>
                konfigurasi.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["Cors:AsalDiizinkan:0"] = AsalTerdaftar,
                }));

            return base.CreateHost(builder);
        }
    }
}
