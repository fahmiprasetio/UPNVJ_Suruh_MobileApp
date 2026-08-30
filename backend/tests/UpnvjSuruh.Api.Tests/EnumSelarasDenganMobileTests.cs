using System.Text.RegularExpressions;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Nama anggota enum hidup di dua bahasa, dan penerjemahannya cuma mencocokkan nama.
///
/// Aplikasi menolak nilai yang tidak dikenal, bukan diam-diam jatuh ke anggota pertama, dan
/// itu keputusan yang benar: status yang salah baca membuat layar menawarkan tombol yang
/// tidak seharusnya ada. Harganya adalah anggota yang lahir di server tapi lupa ditambahkan
/// di aplikasi akan muncul sebagai layar yang gagal memuat, di perangkat pengguna, pada
/// order yang kebetulan berstatus itu.
///
/// Kejadian nyata yang melahirkan tes ini: <c>PaymentStatus.JumlahTidakCocok</c> ditambahkan
/// di server saat pemeriksaan jumlah pembayaran dipasang. Anggota itu wajib punya padanan di
/// Dart, dan yang mengingatkannya harus tes, bukan ingatan orang.
///
/// Sama seperti <see cref="TarifSelarasDenganMobileTests"/>, berkas Dart-nya dibaca apa
/// adanya. Kalau salah satu sisi diubah tanpa yang lain, yang berbunyi tes, bukan pengguna.
/// </summary>
public partial class EnumSelarasDenganMobileTests
{
    [GeneratedRegex(@"enum\s+(\w+)\s*\{")]
    private static partial Regex PolaEnum();

    /// <summary>Baris komentar Dart, dibuang sebelum anggotanya dibaca.</summary>
    [GeneratedRegex(@"//[^\n]*")]
    private static partial Regex PolaKomentar();

    /// <summary>
    /// Anggota di awal sebuah potongan, dengan argumen konstruktornya kalau ada.
    /// <c>ServiceType</c> menulis anggotanya sebagai <c>anterJemput(OrderTrack.jalurA)</c>.
    /// </summary>
    [GeneratedRegex(@"^\s*([a-z][A-Za-z0-9_]*)")]
    private static partial Regex PolaAnggota();

    private static string BerkasDart()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var kandidat = Path.Combine(dir.FullName, "mobile", "lib", "domain", "enums.dart");
            if (File.Exists(kandidat)) return kandidat;
            dir = dir.Parent;
        }

        throw new FileNotFoundException(
            "enums.dart tidak ketemu. Kalau berkasnya memang dipindah, perbarui tes ini, " +
            "jangan hapus: tanpa tes ini anggota enum yang lahir di server tanpa padanan di " +
            "aplikasi baru ketahuan sebagai layar yang gagal muat di perangkat pengguna.");
    }

    /// <summary>Nama anggota setiap enum di berkas Dart, apa adanya.</summary>
    private static Dictionary<string, List<string>> EnumMobile()
    {
        var isi = PolaKomentar().Replace(File.ReadAllText(BerkasDart()), string.Empty);
        var hasil = new Dictionary<string, List<string>>();

        foreach (Match cocok in PolaEnum().Matches(isi))
        {
            var nama = cocok.Groups[1].Value;
            var mulai = cocok.Index + cocok.Length;

            // Daftar anggotanya berakhir di titik koma kalau enum-nya punya method atau
            // field, dan di kurung tutup kalau tidak. Yang lebih dulu ketemu yang dipakai.
            var titikKoma = isi.IndexOf(';', mulai);
            var tutup = isi.IndexOf('}', mulai);
            var akhir = titikKoma >= 0 && titikKoma < tutup ? titikKoma : tutup;

            hasil[nama] = isi[mulai..akhir]
                .Split(',')
                .Select(bagian => PolaAnggota().Match(bagian))
                .Where(m => m.Success)
                .Select(m => m.Groups[1].Value)
                .ToList();
        }

        return hasil;
    }

    /// <summary>
    /// Server menulis PascalCase, Dart camelCase. Hanya huruf pertama yang berbeda, dan itu
    /// memang satu-satunya perbedaan yang diabaikan pemeta di sisi aplikasi.
    /// </summary>
    private static string Camel(string pascal) =>
        char.ToLowerInvariant(pascal[0]) + pascal[1..];

    public static TheoryData<string, string[]> EnumServer() => new()
    {
        { nameof(UserRole), Enum.GetNames<UserRole>() },
        { nameof(OrderTrack), Enum.GetNames<OrderTrack>() },
        { nameof(ServiceType), Enum.GetNames<ServiceType>() },
        { nameof(OrderStatus), Enum.GetNames<OrderStatus>() },
        { nameof(OfferStatus), Enum.GetNames<OfferStatus>() },
        { nameof(PaymentStatus), Enum.GetNames<PaymentStatus>() },
    };

    [Theory]
    [MemberData(nameof(EnumServer))]
    public void SetiapAnggotaEnumServerPunyaPadananDiAplikasi(string nama, string[] anggotaServer)
    {
        var mobile = EnumMobile();

        Assert.True(mobile.ContainsKey(nama), $"enum {nama} tidak ada di enums.dart.");

        var kurang = anggotaServer.Select(Camel).Except(mobile[nama]).ToArray();

        Assert.True(
            kurang.Length == 0,
            $"Anggota {nama} ini ada di server tapi belum ada di aplikasi: "
            + $"{string.Join(", ", kurang)}. Tanpa padanannya, layar yang menerima nilai itu "
            + "gagal memuat, karena pemeta di aplikasi melempar untuk nilai yang tidak dikenal.");
    }

    [Theory]
    [MemberData(nameof(EnumServer))]
    public void UrutanAnggotanyaJugaSama(string nama, string[] anggotaServer)
    {
        // Bukan sekadar kelengkapan, tapi urutannya juga. Peran disimpan sebagai integer[] di
        // Postgres, jadi angka itulah yang tersimpan di basis data; anggota yang disisipkan di
        // tengah pada salah satu sisi mengubah arti setiap baris yang sudah ada tanpa ada yang
        // menyentuhnya, dan order lama berubah jenis layanannya sendiri.
        var mobile = EnumMobile();

        Assert.Equal(anggotaServer.Select(Camel).ToArray(), mobile[nama].ToArray());
    }
}
