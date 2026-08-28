using System.Text.RegularExpressions;
using UpnvjSuruh.Api.Pricing;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Tarif sekarang hidup di dua bahasa: server yang menghitung dan mengikat, aplikasi yang
/// menampilkan rinciannya sebelum klien memesan. Dua salinan angka yang sama adalah dua
/// tempat yang bisa berselisih, dan selisihnya muncul sebagai harga di layar yang berbeda
/// dari harga yang ditagih. Itu jenis bug yang membuat pengguna berhenti percaya.
///
/// Tes ini membaca berkas Dart-nya apa adanya. Kalau salah satu diubah tanpa yang lain,
/// yang berbunyi adalah tes, bukan pelanggan.
/// </summary>
public partial class TarifSelarasDenganMobileTests
{
    [GeneratedRegex(@"static const (?:int|double) (\w+)\s*=\s*([\d.]+)\s*;")]
    private static partial Regex PolaKonstanta();

    private static Dictionary<string, decimal> TarifMobile()
    {
        var berkas = CariBerkasDart();
        var isi = File.ReadAllText(berkas);

        return PolaKonstanta()
            .Matches(isi)
            .ToDictionary(
                m => m.Groups[1].Value,
                m => decimal.Parse(m.Groups[2].Value, System.Globalization.CultureInfo.InvariantCulture));
    }

    private static string CariBerkasDart()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var kandidat = Path.Combine(dir.FullName, "mobile", "lib", "core", "config", "tarif_config.dart");
            if (File.Exists(kandidat)) return kandidat;
            dir = dir.Parent;
        }

        throw new FileNotFoundException(
            "tarif_config.dart tidak ketemu. Kalau berkasnya memang dipindah, perbarui tes ini, " +
            "jangan hapus: tanpa tes ini tarif server dan tarif aplikasi bisa berselisih diam-diam.");
    }

    [Fact]
    public void AngkaTarifServerSamaDenganAplikasi()
    {
        var mobile = TarifMobile();

        Assert.Equal(TarifConfig.AnjemTarifDasar, mobile["anjemTarifDasar"]);
        Assert.Equal(TarifConfig.AnjemTarifPerKm, mobile["anjemTarifPerKm"]);
        Assert.Equal((decimal)TarifConfig.AnjemJarakMinimalKm, mobile["anjemJarakMinimalKm"]);
        Assert.Equal((decimal)TarifConfig.AnjemJarakMaksimalKm, mobile["anjemJarakMaksimalKm"]);
        Assert.Equal(TarifConfig.JastipMakananFee, mobile["jastipMakananFee"]);
        Assert.Equal(TarifConfig.JastipBarangFee, mobile["jastipBarangFee"]);
        Assert.Equal(TarifConfig.JastipBarangTarifPerKm, mobile["jastipBarangTarifPerKm"]);
    }

    [Fact]
    public void SemuaTarifDiAplikasiPunyaPadananDiServer()
    {
        // Menambah tarif baru di aplikasi tanpa menambahkannya di server akan lolos dari tes
        // di atas, karena tes itu cuma memeriksa yang sudah disebut. Yang ini menutupnya.
        var mobile = TarifMobile();
        var dikenal = new[]
        {
            "anjemTarifDasar", "anjemTarifPerKm", "anjemJarakMinimalKm", "anjemJarakMaksimalKm",
            "jastipMakananFee", "jastipBarangFee", "jastipBarangTarifPerKm",
        };

        var belumDikenal = mobile.Keys.Except(dikenal).ToArray();

        Assert.True(
            belumDikenal.Length == 0,
            $"Tarif ini ada di aplikasi tapi belum ada di server: {string.Join(", ", belumDikenal)}");
    }
}
