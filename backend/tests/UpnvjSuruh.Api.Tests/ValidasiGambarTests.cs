using UpnvjSuruh.Api.Media;
using Xunit;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Inti yang dijaga berkas ini: berkas yang cuma diawali penanda JPEG/PNG asli lalu
/// ditambahi apa saja di belakangnya (berkas polyglot) harus ditolak, bukan cuma berkas
/// yang penandanya salah dari awal.
/// </summary>
public class ValidasiGambarTests
{
    private static readonly byte[] JpegMinimal = [0xFF, 0xD8, 0xFF, 0xDA, 0x00, 0x02, 0xFF, 0xD9];

    /// <summary>Satu segmen JPEG lengkap: penanda, medan panjang, lalu isinya.</summary>
    private static byte[] Segmen(byte penanda, byte[] isi) =>
        [0xFF, penanda, (byte)((isi.Length + 2) >> 8), (byte)((isi.Length + 2) & 0xFF), .. isi];

    [Fact]
    public void Jpeg_minimal_yang_sah_diterima()
    {
        Assert.True(ValidasiGambar.SahJpeg(JpegMinimal));
    }

    [Fact]
    public void Jpeg_dengan_segmen_APP0_diterima()
    {
        byte[] jfif = [0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00];
        byte[] jpeg = [0xFF, 0xD8, .. Segmen(0xE0, jfif), 0xFF, 0xDA, 0x00, 0x02, 0xFF, 0xD9];

        Assert.True(ValidasiGambar.SahJpeg(jpeg));
    }

    [Fact]
    public void Jpeg_dengan_sisa_berkas_sesudah_EOI_ditolak()
    {
        // Inilah berkas polyglot: gambar sungguhan yang sah di depan, apa saja di belakangnya.
        byte[] jpeg = [.. JpegMinimal, .. "<?php system($_GET['c']); ?>"u8];

        Assert.False(ValidasiGambar.SahJpeg(jpeg));
    }

    [Fact]
    public void Jpeg_yang_terpotong_sebelum_EOI_ditolak()
    {
        byte[] terpotong = JpegMinimal[..^1];

        Assert.False(ValidasiGambar.SahJpeg(terpotong));
    }

    [Fact]
    public void Byte_stuffing_dalam_data_pemindaian_tidak_disalahartikan_sebagai_EOI()
    {
        // 0xFF 0x00 di tengah data terkompresi adalah byte 0xFF harfiah (byte-stuffing),
        // bukan awal penanda. EOI sungguhan cuma yang persis di akhir berkas.
        byte[] jpeg = [0xFF, 0xD8, 0xFF, 0xDA, 0x00, 0x02, 0x12, 0xFF, 0x00, 0x34, 0xFF, 0xD9];

        Assert.True(ValidasiGambar.SahJpeg(jpeg));
    }

    [Fact]
    public void Berkas_yang_bukan_JPEG_ditolak()
    {
        Assert.False(ValidasiGambar.SahJpeg([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    }

    // --- PNG ---

    private static readonly byte[] TandaPng = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

    private static byte[] Chunk(string jenis, byte[] data)
    {
        var panjang = data.Length;
        byte[] medanPanjang = [(byte)(panjang >> 24), (byte)(panjang >> 16), (byte)(panjang >> 8), (byte)panjang];
        return [.. medanPanjang, .. System.Text.Encoding.ASCII.GetBytes(jenis), .. data, 0, 0, 0, 0];
    }

    private static byte[] Png() => [.. TandaPng, .. Chunk("IHDR", new byte[13]), .. Chunk("IEND", [])];

    [Fact]
    public void Png_minimal_yang_sah_diterima()
    {
        Assert.True(ValidasiGambar.SahPng(Png()));
    }

    [Fact]
    public void Png_dengan_sisa_berkas_sesudah_IEND_ditolak()
    {
        byte[] png = [.. Png(), .. "<?php system($_GET['c']); ?>"u8];

        Assert.False(ValidasiGambar.SahPng(png));
    }

    [Fact]
    public void Png_yang_terpotong_sebelum_IEND_ditolak()
    {
        var utuh = Png();
        var terpotong = utuh[..^4]; // IEND-nya sendiri masih ada, CRC-nya yang hilang

        Assert.False(ValidasiGambar.SahPng(terpotong));
    }

    [Fact]
    public void Png_dengan_tanda_tangan_salah_ditolak()
    {
        Assert.False(ValidasiGambar.SahPng([0, 1, 2, 3, 4, 5, 6, 7, .. Chunk("IEND", [])]));
    }
}
