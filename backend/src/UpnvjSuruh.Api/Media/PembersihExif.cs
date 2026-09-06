namespace UpnvjSuruh.Api.Media;

/// <summary>
/// Membuang metadata Exif dari foto JPEG, tanpa mengubah gambarnya.
/// </summary>
/// <remarks>
/// Foto bukti pekerjaan diambil kamera ponsel runner, dan kamera ponsel menulis lokasi GPS
/// ke Exif secara bawaan. Server ini menyimpan foto itu di URL yang bisa dibuka siapa pun
/// yang memegang tautannya (lihat <see cref="PenyimpanFoto"/>), jadi lokasi rumah atau kos
/// runner bisa bocor lewat foto yang ia kira cuma bukti pekerjaan.
///
/// JPEG dibongkar segmen demi segmen, bukan lewat pustaka pengolah gambar: menambah
/// pustaka gambar untuk sekadar membuang satu jenis segmen jauh lebih besar daripada
/// masalahnya, mengikuti alasan yang sama dengan <see cref="JenisGambar"/>. Segmen APP1
/// (penanda Exif) dilompati, seluruh segmen lain -- termasuk data gambarnya sendiri --
/// disalin apa adanya, jadi gambarnya tidak pernah dienkode ulang.
///
/// Apa pun yang tidak dikenali bentuknya (bukan JPEG, atau strukturnya berhenti di tengah
/// jalan) dikembalikan apa adanya. Fungsi ini cuma boleh membuang metadata, tidak boleh
/// merusak berkas yang tidak sepenuhnya dipahaminya.
///
/// ponytail: hanya JPEG. PNG diabaikan -- kamera ponsel praktis selalu menulis JPEG, dan
/// PNG dari aplikasi ini cuma datang dari tangkapan layar yang tidak membawa GPS. Kalau
/// nanti PNG ber-Exif ternyata masuk, tambahkan penanganan chunk `eXIf` di sini.
/// </remarks>
public static class PembersihExif
{
    private const byte PenandaAwal = 0xFF;
    private const byte Soi = 0xD8;
    private const byte Eoi = 0xD9;
    private const byte Sos = 0xDA;
    private const byte App1 = 0xE1;

    public static byte[] Buang(byte[] jpeg)
    {
        if (jpeg.Length < 2 || jpeg[0] != PenandaAwal || jpeg[1] != Soi)
        {
            return jpeg;
        }

        var hasil = new List<byte>(jpeg.Length) { jpeg[0], jpeg[1] };
        var pos = 2;

        while (pos + 1 < jpeg.Length)
        {
            if (jpeg[pos] != PenandaAwal)
            {
                // Bentuknya tidak seperti yang diharapkan di titik ini. Berhenti membaca
                // sebagai segmen dan salin sisanya utuh daripada menebak strukturnya.
                hasil.AddRange(jpeg[pos..]);
                return [.. hasil];
            }

            var penanda = jpeg[pos + 1];

            // SOS: sisa berkas adalah data gambar terkompresi (plus marker restart dan EOI
            // di dalamnya), disalin utuh tanpa dibaca lagi sebagai segmen bertanda-panjang.
            if (penanda == Sos)
            {
                hasil.AddRange(jpeg[pos..]);
                return [.. hasil];
            }

            // Penanda tanpa isi: SOI, EOI, dan RST0-RST7 cuma dua byte, tanpa medan panjang.
            if (penanda is Soi or Eoi or (>= 0xD0 and <= 0xD7))
            {
                hasil.Add(jpeg[pos]);
                hasil.Add(jpeg[pos + 1]);
                pos += 2;
                continue;
            }

            if (pos + 3 >= jpeg.Length)
            {
                hasil.AddRange(jpeg[pos..]);
                return [.. hasil];
            }

            var panjang = (jpeg[pos + 2] << 8) | jpeg[pos + 3];
            var akhirSegmen = pos + 2 + panjang;
            if (panjang < 2 || akhirSegmen > jpeg.Length)
            {
                hasil.AddRange(jpeg[pos..]);
                return [.. hasil];
            }

            if (penanda != App1)
            {
                hasil.AddRange(jpeg[pos..akhirSegmen]);
            }

            pos = akhirSegmen;
        }

        if (pos < jpeg.Length)
        {
            hasil.AddRange(jpeg[pos..]);
        }

        return [.. hasil];
    }
}
