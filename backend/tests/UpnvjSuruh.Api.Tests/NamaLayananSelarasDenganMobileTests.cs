using System.Text.RegularExpressions;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Nama layanan hidup di dua tempat sejak notifikasi push ada, dan dua tempat itu harus
/// berbunyi sama.
///
/// Katalog di sisi mobile adalah pemiliknya: dari sanalah nama layanan muncul di setiap
/// layar. Sisi server perlu satu salinan karena notifikasi push adalah satu-satunya kalimat
/// yang disusun server dan dibaca langsung orang, tanpa pernah melewati layar yang bisa
/// menerjemahkannya. Salinan yang tidak dijaga akan menyimpang, dan hasilnya bentuk
/// kebingungan yang sulit dilaporkan: notifikasi menyebut "Bersih Kos" sementara aplikasi
/// yang dibuka orangnya menyebut "Bersih-Bersih Kos".
///
/// Mengikuti pola <see cref="EnumSelarasDenganMobileTests"/> dan
/// <see cref="TarifSelarasDenganMobileTests"/>: berkas Dart-nya dibaca apa adanya, dan yang
/// berbunyi kalau salah satu sisi berubah sendiri adalah tes, bukan pengguna.
/// </summary>
public partial class NamaLayananSelarasDenganMobileTests
{
    /// <summary>Satu entri katalog: jenis layanannya, lalu namanya.</summary>
    [GeneratedRegex(@"type:\s*ServiceType\.(\w+),\s*nama:\s*'([^']+)'")]
    private static partial Regex PolaEntri();

    private static string BerkasDart()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var kandidat = Path.Combine(dir.FullName, "mobile", "lib", "domain", "service_catalog.dart");
            if (File.Exists(kandidat)) return kandidat;
            dir = dir.Parent;
        }

        throw new FileNotFoundException(
            "service_catalog.dart tidak ketemu. Kalau berkasnya memang dipindah, perbarui " +
            "tes ini, jangan hapus: tanpa tes ini notifikasi push bisa menyebut nama layanan " +
            "yang berbeda dari yang tertulis di layar aplikasi.");
    }

    [Fact]
    public void SetiapLayananPunyaNamaYangSamaDenganKatalogMobile()
    {
        var katalog = PolaEntri()
            .Matches(File.ReadAllText(BerkasDart()))
            .ToDictionary(
                cocok => cocok.Groups[1].Value.ToLowerInvariant(),
                cocok => cocok.Groups[2].Value);

        Assert.Equal(Enum.GetValues<ServiceType>().Length, katalog.Count);

        foreach (var layanan in Enum.GetValues<ServiceType>())
        {
            var namaMobile = Assert.Contains(layanan.ToString().ToLowerInvariant(), katalog);
            Assert.Equal(namaMobile, layanan.NamaTampilan());
        }
    }
}
