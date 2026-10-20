using System.Net;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;
using UpnvjSuruh.Api.Publik;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Halaman publik: kebijakan privasi, syarat layanan, dan penghapusan akun.
///
/// Yang diuji bukan tampilannya, melainkan janjinya. Google Play dan pengguna membaca halaman
/// ini sebagai pernyataan tentang data, jadi tiap jenis data yang benar-benar dikumpulkan dan
/// tiap pihak yang benar-benar menerimanya harus tertulis, dan tidak boleh ada nama penyedia
/// yang belum aktif. Tidak butuh basis data: halaman ini tidak menyentuhnya.
/// </summary>
public class HalamanPublikTests(ApiFactory pabrik) : IClassFixture<ApiFactory>
{
    private static async Task<(HttpResponseMessage Jawaban, string Isi)> BacaAsync(HttpClient klien, string jalur)
    {
        var jawaban = await klien.GetAsync(jalur);
        return (jawaban, await jawaban.Content.ReadAsStringAsync());
    }

    [Theory]
    [InlineData("/kebijakan-privasi")]
    [InlineData("/syarat-ketentuan")]
    [InlineData("/hapus-akun")]
    public async Task HalamanTerbukaTanpaMasukDanBerupaHtml(string jalur)
    {
        // Klien tanpa token sama sekali: ini yang dibuka petugas Google Play dan orang yang
        // sudah tidak punya aplikasinya.
        var (jawaban, isi) = await BacaAsync(pabrik.CreateClient(), jalur);

        Assert.Equal(HttpStatusCode.OK, jawaban.StatusCode);
        Assert.Equal("text/html", jawaban.Content.Headers.ContentType?.MediaType);
        Assert.Contains("<html lang=\"id\">", isi);

        // Dua dokumen kebijakan memuat tanggal pembaruannya; halaman penghapusan akun adalah
        // formulir, bukan dokumen kebijakan.
        if (jalur != "/hapus-akun")
        {
            Assert.Contains(HalamanPublik.DiperbaruiPada, isi, StringComparison.Ordinal);
        }
    }

    [Fact]
    public async Task KebijakanPrivasiMenyebutSetiapJenisDataYangDikumpulkan()
    {
        var (_, isi) = await BacaAsync(pabrik.CreateClient(), "/kebijakan-privasi");

        // Sama dengan yang dikumpulkan kode: akun, pesanan, percakapan, foto bukti,
        // pembayaran, lokasi, dan token perangkat.
        foreach (var kata in new[]
                 {
                     "nomor HP", "alamat", "foto", "Percakapan", "Pembayaran", "Lokasi",
                     "token notifikasi", "EXIF",
                 })
        {
            Assert.Contains(kata, isi, StringComparison.OrdinalIgnoreCase);
        }
    }

    /// <summary>
    /// Aplikasi belum bisa merekam atau melampirkan pesan suara (kolomnya ada di basis data,
    /// layarnya belum ada), dan klien belum bisa melampirkan foto ke pesanan atau chat. Kebijakan
    /// yang menyebut data yang tidak pernah dikumpulkan sama salahnya dengan yang menyembunyikan
    /// data yang dikumpulkan.
    /// </summary>
    [Fact]
    public async Task KebijakanPrivasiTidakMengklaimDataYangBelumDikumpulkanAplikasi()
    {
        var (_, isi) = await BacaAsync(pabrik.CreateClient(), "/kebijakan-privasi");

        Assert.DoesNotContain("pesan suara", isi, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("foto atau pesan", isi, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task KebijakanPrivasiMenyebutSetiapPihakYangMenerimaData()
    {
        var (_, isi) = await BacaAsync(pabrik.CreateClient(), "/kebijakan-privasi");

        // Penyedia yang benar-benar dipanggil kode: pembayaran, notifikasi, dan peta.
        foreach (var pihak in new[] { "Midtrans", "Firebase", "OpenStreetMap", "Runner", "Admin" })
        {
            Assert.Contains(pihak, isi, StringComparison.OrdinalIgnoreCase);
        }
    }

    /// <summary>
    /// Penyedia pengirim OTP belum diputuskan mitra (Meta atau Twilio, dua-duanya belum aktif).
    /// Menyebut namanya di halaman publik adalah klaim yang belum benar.
    /// </summary>
    [Theory]
    [InlineData("/kebijakan-privasi")]
    [InlineData("/syarat-ketentuan")]
    [InlineData("/hapus-akun")]
    public async Task TidakAdaKlaimPenyediaOtpYangBelumAktif(string jalur)
    {
        var (_, isi) = await BacaAsync(pabrik.CreateClient(), jalur);

        Assert.DoesNotContain("WhatsApp", isi, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("Twilio", isi, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("Meta", isi, StringComparison.Ordinal);
    }

    [Fact]
    public async Task KebijakanPrivasiMenjelaskanApaYangDihapusDanApaYangDipertahankan()
    {
        var (_, isi) = await BacaAsync(pabrik.CreateClient(), "/kebijakan-privasi");

        Assert.Contains("id=\"hapus\"", isi);
        Assert.Contains("Yang dihapus", isi);
        Assert.Contains("Yang dipertahankan", isi);
        Assert.Contains("Akun dihapus", isi);

        // Janji penolakan yang sama dengan yang ditegakkan AkunController.
        Assert.Contains("pesanan yang berjalan", isi);
        Assert.Contains("bayaran yang belum dicairkan", isi);

        // Tidak ada angka lama penyimpanan: belum ada yang menegakkannya di kode.
        Assert.DoesNotMatch(@"\d+\s*(tahun|bulan)", isi);
    }

    /// <summary>
    /// Layar aplikasi (<c>KebijakanPrivasiScreen</c>) memuat bagian yang sama dengan halaman ini,
    /// dengan judul dan urutan yang sama. Daftar ini ada juga di
    /// <c>legal_konsistensi_test.dart</c>; kalau salah satunya diubah, ubah keduanya.
    /// </summary>
    [Fact]
    public async Task KebijakanPrivasiMemuatBagianYangSamaDenganAplikasi()
    {
        var (_, isi) = await BacaAsync(pabrik.CreateClient(), "/kebijakan-privasi");

        Assert.Equal(
            [
                "1. Data yang kami kumpulkan",
                "2. Untuk apa data dipakai",
                "3. Dengan siapa data dibagikan",
                "4. Keamanan",
                "5. Menghapus akun dan data",
                "6. Hakmu",
                "7. Anak-anak",
                "8. Perubahan dan kontak",
            ],
            JudulBagian(isi));
    }

    /// <summary>
    /// Sama seperti kebijakan privasi: pasal di <c>SyaratKetentuanScreen</c> harus sama dengan
    /// halaman ini. Daftarnya ada juga di <c>legal_konsistensi_test.dart</c>.
    /// </summary>
    [Fact]
    public async Task SyaratMemuatPasalYangSamaDenganAplikasi()
    {
        var (_, isi) = await BacaAsync(pabrik.CreateClient(), "/syarat-ketentuan");

        Assert.Equal(
            [
                "1. Ketentuan umum",
                "2. Pemesanan dan pembayaran",
                "3. Larangan dan batasan jasa",
                "4. Pelaksanaan dan bukti selesai",
                "5. Pembatalan dan pengembalian dana",
                "6. Akun",
                "7. Kontak",
            ],
            JudulBagian(isi));
    }

    private static List<string> JudulBagian(string html) =>
        [.. Regex.Matches(html, "<h2[^>]*>(.*?)</h2>").Select(m => WebUtility.HtmlDecode(m.Groups[1].Value))];

    [Fact]
    public async Task HalamanHapusAkunMemanggilEndpointYangAdaDanMemintaPersetujuan()
    {
        var (_, isi) = await BacaAsync(pabrik.CreateClient(), "/hapus-akun");

        // Dua endpoint yang benar-benar ada: kode lewat alur masuk, penghapusan lewat AkunController.
        Assert.Contains("/api/auth/minta-kode", isi);
        Assert.Contains("/api/akun/hapus", isi);
        Assert.Contains("type=\"checkbox\"", isi);
        Assert.Contains("tidak bisa dikembalikan", isi);
        Assert.Contains("href=\"/kebijakan-privasi#hapus\"", isi);
    }

    [Fact]
    public async Task KontakDibacaDariKonfigurasiDanDiloloskanDariHtml()
    {
        using var pabrikKontak = new PabrikDenganKontak("WhatsApp admin <b>0812</b>");

        var (_, isi) = await BacaAsync(pabrikKontak.CreateClient(), "/kebijakan-privasi");

        Assert.Contains("WhatsApp admin &lt;b&gt;0812&lt;/b&gt;", isi);
        Assert.DoesNotContain("<b>0812</b>", isi);
    }

    [Fact]
    public async Task TanpaKonfigurasiKontakMengarahKeKanalYangPastiAda()
    {
        var (_, isi) = await BacaAsync(pabrik.CreateClient(), "/kebijakan-privasi");

        Assert.Contains("menu Pusat Bantuan di aplikasi", isi);
    }

    private sealed class PabrikDenganKontak(string kontak) : ApiFactory
    {
        protected override IHost CreateHost(IHostBuilder builder)
        {
            builder.ConfigureHostConfiguration(config =>
                config.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    ["Publik:KontakBantuan"] = kontak,
                }));
            return base.CreateHost(builder);
        }
    }
}
