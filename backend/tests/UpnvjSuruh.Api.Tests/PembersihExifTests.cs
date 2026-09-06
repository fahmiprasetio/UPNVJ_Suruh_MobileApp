using UpnvjSuruh.Api.Media;
using Xunit;

namespace UpnvjSuruh.Api.Tests;

public class PembersihExifTests
{
    /// <summary>Satu segmen JPEG lengkap: penanda, medan panjang, lalu isinya.</summary>
    private static byte[] Segmen(byte penanda, byte[] isi) =>
        [0xFF, penanda, (byte)((isi.Length + 2) >> 8), (byte)((isi.Length + 2) & 0xFF), .. isi];

    private static readonly byte[] Jfif = [0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00];
    private static readonly byte[] PayloadExif = [.. "Exif\0\0GPS_LOKASI_RAHASIA"u8];

    /// <summary>SOI, lalu segmen-segmen yang diberikan, lalu SOS dan data pemindaian pura-pura.</summary>
    private static byte[] Jpeg(params byte[][] segmen)
    {
        List<byte> hasil = [0xFF, 0xD8];
        foreach (var s in segmen) hasil.AddRange(s);
        hasil.AddRange([0xFF, 0xDA, 0x00, 0x02, 0x00, 0x01, 0x02, 0x03, 0xFF, 0xD9]);
        return [.. hasil];
    }

    [Fact]
    public void Membuang_segmen_APP1_yang_membawa_lokasi()
    {
        var asli = Jpeg(Segmen(0xE0, Jfif), Segmen(0xE1, PayloadExif));

        var hasil = PembersihExif.Buang(asli);

        var teks = System.Text.Encoding.ASCII.GetString(hasil);
        Assert.DoesNotContain("GPS_LOKASI_RAHASIA", teks);
        Assert.True(hasil.Length < asli.Length);
    }

    [Fact]
    public void Segmen_APP0_tetap_ada_setelah_APP1_dibuang()
    {
        var asli = Jpeg(Segmen(0xE0, Jfif), Segmen(0xE1, PayloadExif));

        var hasil = PembersihExif.Buang(asli);

        // APP0 (JFIF) disalin apa adanya: penanda FF E0 diikuti isi JFIF-nya persis.
        var indeksApp0 = IndeksSubUrutan(hasil, [0xFF, 0xE0]);
        Assert.True(indeksApp0 >= 0);
        Assert.Equal(Jfif, hasil[(indeksApp0 + 4)..(indeksApp0 + 4 + Jfif.Length)]);
    }

    [Fact]
    public void Data_pemindaian_setelah_SOS_tidak_ikut_diutak_atik()
    {
        var asli = Jpeg(Segmen(0xE1, PayloadExif));

        var hasil = PembersihExif.Buang(asli);

        // FF DA lalu empat byte data pemindaian pura-pura, lalu EOI -- persis seperti aslinya.
        Assert.Equal(
            (byte[])[0xFF, 0xDA, 0x00, 0x02, 0x00, 0x01, 0x02, 0x03, 0xFF, 0xD9],
            hasil[^10..]);
    }

    [Fact]
    public void Jpeg_tanpa_exif_kembali_persis_sama()
    {
        var asli = Jpeg(Segmen(0xE0, Jfif));

        var hasil = PembersihExif.Buang(asli);

        Assert.Equal(asli, hasil);
    }

    [Fact]
    public void Berkas_yang_bukan_JPEG_dikembalikan_apa_adanya()
    {
        byte[] bukanJpeg = [0x89, 0x50, 0x4E, 0x47, 0x00, 0x01, 0x02];

        var hasil = PembersihExif.Buang(bukanJpeg);

        Assert.Equal(bukanJpeg, hasil);
    }

    [Fact]
    public void Berkas_terpotong_di_tengah_segmen_dikembalikan_apa_adanya()
    {
        // Empat byte pertama yang sudah dipakai FotoBuktiTests untuk mewakili "JPEG
        // terkecil yang masih dikenali": SOI lalu awal penanda APP0 tanpa medan panjang.
        byte[] terpotong = [0xFF, 0xD8, 0xFF, 0xE0];

        var hasil = PembersihExif.Buang(terpotong);

        Assert.Equal(terpotong, hasil);
    }

    private static int IndeksSubUrutan(byte[] cari, byte[] pola)
    {
        for (var i = 0; i <= cari.Length - pola.Length; i++)
        {
            if (cari.Skip(i).Take(pola.Length).SequenceEqual(pola)) return i;
        }
        return -1;
    }
}
