namespace UpnvjSuruh.Api.Media;

/// <summary>
/// Memeriksa bahwa seluruh berkas benar-benar berbentuk JPEG/PNG yang sah, bukan cuma
/// diawali penanda yang benar.
/// </summary>
/// <remarks>
/// <see cref="JenisGambar"/> di <c>FotoBuktiController</c> cuma melihat empat byte pertama.
/// Itu cukup untuk menolak berkas yang jelas bukan gambar, tapi tidak menolak berkas
/// polyglot: gambar sungguhan yang sah di depan, diikuti apa saja di belakangnya (skrip,
/// berkas lain, apa pun) sesudah data gambarnya berakhir. Kelas ini menuntaskan pertanyaan
/// yang ditinggalkan pemeriksaan byte pertama: apakah berkasnya berhenti persis di tempat
/// format itu seharusnya berhenti, tanpa sisa.
///
/// Ditulis tangan tanpa pustaka pengolah gambar, mengikuti alasan yang sama dengan
/// <see cref="JenisGambar"/> dan <see cref="PembersihExif"/>: menambah pustaka gambar untuk
/// sekadar memeriksa struktur jauh lebih besar daripada masalahnya.
/// </remarks>
public static class ValidasiGambar
{
    /// <summary>
    /// Benar kalau seluruh berkas adalah satu struktur JPEG yang sah dari awal (SOI) sampai
    /// akhir (EOI), tanpa satu byte pun tersisa sesudahnya.
    /// </summary>
    public static bool SahJpeg(byte[] d)
    {
        if (d.Length < 4 || d[0] != 0xFF || d[1] != 0xD8) return false;

        var p = 2;
        while (p < d.Length)
        {
            if (d[p] != 0xFF) return false;

            // Byte 0xFF berulang sebelum penanda adalah pengisi yang sah menurut spesifikasi.
            while (p < d.Length && d[p] == 0xFF) p++;
            if (p >= d.Length) return false;

            var penanda = d[p];
            p++;

            if (penanda == 0xD9) return p == d.Length; // EOI: tidak boleh ada sisa sesudahnya

            if (penanda == 0xD8 || (penanda >= 0xD0 && penanda <= 0xD7)) continue; // tanpa isi

            if (p + 1 >= d.Length) return false;
            var panjang = (d[p] << 8) | d[p + 1];
            if (panjang < 2) return false;

            var akhirSegmen = p + panjang;
            if (akhirSegmen > d.Length) return false;

            if (penanda == 0xDA) // SOS: data terkompresi menyusul, bukan segmen biasa
            {
                p = LewatiDataScan(d, akhirSegmen);
                if (p < 0) return false;
                continue;
            }

            p = akhirSegmen;
        }

        return false; // habis tanpa pernah menemukan EOI
    }

    /// <summary>
    /// Melompati data terkompresi sesudah SOS sampai menemukan penanda sungguhan berikutnya
    /// (biasanya EOI), sambil menghormati byte-stuffing: <c>0xFF 0x00</c> di dalam data
    /// terkompresi adalah byte 0xFF harfiah, bukan awal penanda, dan penanda mulai-ulang
    /// (RST0-RST7) juga masih bagian dari data, bukan akhir gambar.
    /// </summary>
    private static int LewatiDataScan(byte[] d, int p)
    {
        while (p < d.Length)
        {
            if (d[p] == 0xFF)
            {
                if (p + 1 >= d.Length) return -1;

                var berikutnya = d[p + 1];
                if (berikutnya == 0x00 || (berikutnya >= 0xD0 && berikutnya <= 0xD7))
                {
                    p += 2;
                    continue;
                }

                return p; // penanda sungguhan: EOI, atau SOS berikutnya untuk JPEG progresif
            }

            p++;
        }

        return -1;
    }

    /// <summary>
    /// Benar kalau seluruh berkas adalah satu struktur PNG yang sah: tanda tangan lalu
    /// deretan chunk yang panjangnya konsisten, diakhiri <c>IEND</c> tanpa satu byte pun
    /// tersisa sesudahnya.
    /// </summary>
    public static bool SahPng(byte[] d)
    {
        ReadOnlySpan<byte> tandaTangan = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
        if (d.Length < 8 || !d.AsSpan(0, 8).SequenceEqual(tandaTangan)) return false;

        var p = 8;
        while (p < d.Length)
        {
            if (p + 8 > d.Length) return false; // medan panjang (4) + jenis chunk (4)

            var panjang = (d[p] << 24) | (d[p + 1] << 16) | (d[p + 2] << 8) | d[p + 3];
            if (panjang < 0) return false; // medan panjang PNG tidak pernah negatif

            var jenis = System.Text.Encoding.ASCII.GetString(d, p + 4, 4);
            var akhirChunk = p + 8L + panjang + 4; // + CRC empat byte
            if (akhirChunk > d.Length) return false;

            if (jenis == "IEND") return akhirChunk == d.Length;

            p = (int)akhirChunk;
        }

        return false; // habis tanpa pernah menemukan IEND
    }
}
