using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Media;

namespace UpnvjSuruh.Api.Perawatan;

/// <summary>Apa saja yang dibereskan satu kali sapuan.</summary>
/// <param name="PembayaranKedaluwarsa">Transaksi menunggu yang batas waktunya sudah lewat.</param>
/// <param name="BerkasYatim">Foto yang tidak pernah dipakai menutup order mana pun.</param>
public readonly record struct HasilSapuan(int PembayaranKedaluwarsa, int BerkasYatim);

/// <summary>
/// Merapikan hal-hal yang tidak dirapikan siapa pun karena tidak ada yang menanyakannya.
/// </summary>
/// <remarks>
/// Sebelum ini tidak ada satu pun pekerja latar di server ini, dan akibatnya menumpuk
/// diam-diam. Keduanya jenis kegagalan yang tidak pernah dilaporkan orang, karena dari luar
/// tidak ada yang terlihat rusak:
///
///   - Transaksi pembayaran yang lewat batas waktunya baru ditandai kedaluwarsa kalau ada
///     yang membuka layar bayarnya lagi. Yang ditinggalkan begitu saja, dan itu justru yang
///     paling mungkin ditinggalkan, tetap berstatus menunggu selamanya. Laporan "berapa
///     transaksi yang sedang menunggu" karena itu tidak pernah benar.
///
///   - Foto yang diunggah runner lalu tidak jadi dipakai menutup order tidak pernah dihapus.
///     Batas laju membatasi lajunya, bukan totalnya, jadi cakramnya cuma bisa bertambah
///     penuh sepanjang aplikasinya dipakai.
///
/// Yang TIDAK dikerjakan di sini: membatalkan order yang lama menunggu pembayaran. Itu
/// keputusan produk, bukan kerapian, karena yang dibatalkan adalah pesanan orang. Berapa lama
/// dianggap ditinggalkan, dan apakah pantas dibatalkan sendiri tanpa ada yang memberi tahu,
/// harus dijawab mitra lebih dulu.
///
/// Terpisah dari penjadwalnya supaya bisa diuji dengan memanggilnya langsung. Pekerja latar
/// yang logikanya menempel pada pewaktu cuma bisa diuji dengan menunggu, dan yang seperti itu
/// berakhir tidak diuji sama sekali.
/// </remarks>
public class Penyapu(AppDbContext db, PenyimpanFoto penyimpan, ILogger<Penyapu> log)
{
    /// <summary>
    /// Umur berkas sebelum ia boleh dianggap yatim.
    ///
    /// Longgar dengan sengaja. Runner memotret lebih dulu, melihat hasilnya, mungkin
    /// mengulang, dan baru menekan selesai; jeda antara mengunggah dan menutup order wajar
    /// terjadi, dan pada order terjadwal jeda itu bisa berhari-hari. Berkas yang terhapus
    /// terlalu cepat berarti runner menekan selesai lalu ditolak karena foto yang barusan ia
    /// unggah sudah tidak ada, dan itu kerusakan yang jauh lebih mahal daripada beberapa
    /// megabita yang tertinggal seminggu lebih lama.
    /// </summary>
    public static readonly TimeSpan UmurBerkasYatim = TimeSpan.FromDays(7);

    public async Task<HasilSapuan> SapuAsync(CancellationToken batal = default)
    {
        var sekarang = DateTime.UtcNow;

        return new HasilSapuan(
            await KedaluwarsakanPembayaranAsync(sekarang, batal),
            await HapusBerkasYatimAsync(sekarang, batal));
    }

    /// <summary>
    /// Menandai transaksi menunggu yang batas waktunya sudah lewat.
    /// </summary>
    /// <remarks>
    /// Aturannya sama persis dengan yang sudah dijalankan endpoint status pembayaran saat
    /// ditanya. Yang ditambahkan di sini cuma satu hal: ia dijalankan juga untuk transaksi
    /// yang tidak ada yang menanyakannya.
    /// </remarks>
    private async Task<int> KedaluwarsakanPembayaranAsync(DateTime sekarang, CancellationToken batal)
    {
        var jumlah = await db.Payments
            .Where(p => p.Status == PaymentStatus.Pending && p.ExpiresAt <= sekarang)
            .ExecuteUpdateAsync(p => p.SetProperty(x => x.Status, PaymentStatus.Kedaluwarsa), batal);

        if (jumlah > 0) log.LogInformation("{Jumlah} transaksi ditandai kedaluwarsa.", jumlah);

        return jumlah;
    }

    /// <summary>
    /// Menghapus foto yang tidak pernah dipakai menutup order mana pun.
    /// </summary>
    /// <remarks>
    /// Penghapusan berkas adalah tindakan yang tidak bisa ditarik kembali, dan yang dihapus di
    /// sini adalah bukti pekerjaan orang. Karena itu tiga syarat harus terpenuhi sekaligus,
    /// dan yang manapun gagal berarti berkasnya dibiarkan:
    ///
    ///   1. Namanya tidak muncul di satu pun kolom foto, baik pada order maupun pada penugasan
    ///      runner. Daftar itu dibaca dari basis data setiap sapuan, bukan disimpan.
    ///   2. Umurnya lebih dari <see cref="UmurBerkasYatim"/>.
    ///   3. Berkasnya berada di dalam folder media, yang dijamin karena daftarnya memang
    ///      dibaca dari folder itu.
    ///
    /// Kegagalan menghapus satu berkas tidak menghentikan sisanya dan tidak menggagalkan
    /// sapuan. Berkas yang sedang dibaca orang lain akan terkunci di Windows, dan itu keadaan
    /// yang wajar berulang: sapuan berikutnya akan menemuinya lagi.
    /// </remarks>
    private async Task<int> HapusBerkasYatimAsync(DateTime sekarang, CancellationToken batal)
    {
        var berkas = penyimpan.DaftarBerkas();
        if (berkas.Count == 0) return 0;

        var dipakai = await DipakaiAsync(batal);
        var batasUmur = sekarang - UmurBerkasYatim;
        var terhapus = 0;

        foreach (var (nama, ditulisPada) in berkas)
        {
            batal.ThrowIfCancellationRequested();

            if (dipakai.Contains(nama) || ditulisPada > batasUmur) continue;
            if (penyimpan.Hapus(nama)) terhapus++;
        }

        if (terhapus > 0) log.LogInformation("{Jumlah} foto yatim dihapus.", terhapus);

        return terhapus;
    }

    /// <summary>Nama berkas yang tercatat sebagai bukti pekerjaan di suatu tempat.</summary>
    private async Task<HashSet<string>> DipakaiAsync(CancellationToken batal)
    {
        var dariOrder = await db.Orders
            .Where(o => o.PhotoUrl != null)
            .Select(o => o.PhotoUrl!)
            .ToListAsync(batal);

        var dariPenugasan = await db.OrderRunnerAssignments
            .Where(a => a.CompletionPhotoUrl != null)
            .Select(a => a.CompletionPhotoUrl!)
            .ToListAsync(batal);

        return [.. dariOrder
            .Concat(dariPenugasan)
            .Select(PenyimpanFoto.NamaDari)
            .OfType<string>()];
    }
}
