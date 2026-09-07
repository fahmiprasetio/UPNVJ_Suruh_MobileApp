namespace UpnvjSuruh.Api.Notifikasi;

/// <summary>
/// Isi satu notifikasi push, sebagaimana yang akan dibaca orang di layar kuncinya.
/// </summary>
/// <param name="Judul">Baris pertama, tebal. Sependek mungkin.</param>
/// <param name="Isi">Baris kedua. Cukup untuk memutuskan perlu dibuka sekarang atau tidak.</param>
/// <param name="OrderId">
/// Order yang dituju, dikirim sebagai data supaya ketukan pada notifikasinya bisa membuka
/// layar order yang benar alih-alih beranda.
/// </param>
public record PesanNotifikasi(string Judul, string Isi, Guid OrderId);

public interface IPengirimNotifikasi
{
    /// <summary>
    /// Mengirim satu pesan ke banyak perangkat sekaligus.
    /// </summary>
    /// <returns>
    /// Token yang ditolak penyedia karena pemasangannya sudah tidak ada -- aplikasi dicopot,
    /// data aplikasi dihapus, atau tokennya diputar. Pemanggil membuang barisnya.
    ///
    /// Dikembalikan, bukan dibereskan sendiri di dalam sini, karena yang tahu tabelnya
    /// adalah pemanggil, dan pengirim yang ikut memegang <c>DbContext</c> jadi punya dua
    /// pekerjaan sekaligus. Tanpa jalan pulang ini, token mati menumpuk selamanya dan
    /// setiap kabar berikutnya membayar ongkos kirim ke perangkat yang sudah tidak ada.
    /// </returns>
    Task<IReadOnlyCollection<string>> KirimAsync(
        IReadOnlyCollection<string> token,
        PesanNotifikasi pesan,
        CancellationToken batal = default);
}

/// <summary>
/// Pengirim notifikasi untuk masa pengembangan: pesannya ditulis ke log, bukan dikirim ke
/// mana pun.
///
/// Sepadan dengan <c>PengirimOtpLog</c>, dan ada alasan yang sama: memilih penyedia adalah
/// keputusan di luar kode, sementara seluruh sisa jalurnya -- siapa yang dikirimi, kalimat
/// apa, dan kapan -- bisa dibangun dan diuji tanpa menunggu keputusan itu. Bedanya, yang
/// bocor lewat log di sini cuma satu kalimat pemberitahuan, bukan kunci masuk akun, jadi ia
/// tidak berbahaya seperti OTP yang tertulis di log.
///
/// Tetap hanya didaftarkan di Development. Bukan karena bahaya, melainkan karena produksi
/// yang berjalan dengan pengirim ini akan terlihat sehat sepenuhnya sambil tidak pernah
/// mengirim satu notifikasi pun, dan itu persis kegagalan sunyi yang notifikasi ini ada
/// untuk mencegahnya.
/// </summary>
public class PengirimNotifikasiLog(ILogger<PengirimNotifikasiLog> log) : IPengirimNotifikasi
{
    public Task<IReadOnlyCollection<string>> KirimAsync(
        IReadOnlyCollection<string> token,
        PesanNotifikasi pesan,
        CancellationToken batal = default)
    {
        log.LogInformation(
            "[ALAT PENGUJI] Notifikasi untuk {Jumlah} perangkat, order {OrderId}: {Judul} -- {Isi}",
            token.Count,
            pesan.OrderId,
            pesan.Judul,
            pesan.Isi);

        return Task.FromResult<IReadOnlyCollection<string>>([]);
    }
}
