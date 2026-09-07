using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Data;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Notifikasi;

/// <summary>
/// Satu titik panggil untuk mengirim notifikasi push atas satu perpindahan status order.
///
/// ## Kenapa ada di samping kabar hub, bukan menggantikannya
///
/// <c>OrderHubExtensions</c> memberi tahu layar yang sedang terbuka; ini memberi tahu orang
/// yang aplikasinya tertutup di sakunya. Keduanya menjawab pertanyaan yang berbeda, dan
/// justru yang kedua yang disebut rencana capstone bagian 9 sebagai risiko paling kritis
/// versi mobile: order mendesak masuk, tidak ada runner yang melihatnya, order mati
/// diam-diam. Kabar hub tidak menutup itu sama sekali -- ia cuma sampai ke aplikasi yang
/// sedang terbuka dan tersambung.
///
/// ## Kenapa masuknya baris jejak status, bukan ordernya
///
/// <see cref="OrderStatusChange"/> sudah memuat persis empat hal yang dibutuhkan: ordernya,
/// status asal, status tujuan, dan siapa pemicunya. Pemanggil sudah membuatnya (sejak
/// rencana capstone bagian 71.6, kedelapan tempat status berubah melewati
/// <see cref="OrderStatusChange.Catat"/>), jadi menerima barisnya berarti tidak ada
/// pemanggil yang bisa keliru menyebutkan status asal yang sudah terlanjur tertimpa.
///
/// ## Kegagalannya sengaja ditelan
///
/// Dipanggil sesudah perubahannya tersimpan dan uangnya, kalau ada, sudah berpindah.
/// Melempar dari sini berarti menjawab 500 untuk tindakan yang sudah benar-benar terjadi,
/// dan pemanggilnya akan mengulang tindakan yang tidak perlu diulang. Notifikasi yang tidak
/// terkirim adalah kehilangan yang nyata, tapi jawabannya baris log yang bisa ditelusuri,
/// bukan membatalkan pekerjaan yang sudah selesai.
///
/// ponytail: pengirimannya ditunggu di dalam permintaan HTTP yang memicunya, jadi satu
/// perjalanan ke Firebase (ratusan milidetik) ikut menambah waktu jawabannya. Kalau nanti
/// terasa, yang dipasang antrean latar beserta tabel outbox-nya, bukan pemanggilan yang
/// dilepas tanpa ditunggu -- <c>DbContext</c> di sini bernaung pada permintaan yang sedang
/// berjalan dan sudah dibuang sebelum pengiriman yang dilepas itu selesai.
/// </summary>
public class PengabarOrder(
    AppDbContext db,
    IPengirimNotifikasi pengirim,
    ILogger<PengabarOrder> log)
{
    public async Task KabarkanAsync(OrderStatusChange perpindahan, CancellationToken batal = default)
    {
        try
        {
            await KirimAsync(perpindahan, batal);
        }
        catch (Exception galat)
        {
            log.LogError(
                galat,
                "Notifikasi untuk perpindahan order {OrderId} ke {Status} gagal dikirim.",
                perpindahan.OrderId,
                perpindahan.ToStatus);
        }
    }

    private async Task KirimAsync(OrderStatusChange perpindahan, CancellationToken batal)
    {
        var order = await db.Orders
            .AsNoTracking()
            .Include(o => o.Offers)
            .Include(o => o.RunnerAssignments)
            .SingleOrDefaultAsync(o => o.Id == perpindahan.OrderId, batal);

        if (order is null) return;

        var daftar = KabarOrder.Susun(order, perpindahan.FromStatus, perpindahan.ChangedByUserId);
        if (daftar.Count == 0) return;

        var mati = new List<string>();

        foreach (var kabar in daftar)
        {
            var token = await TokenAsync(kabar.Sasaran, order, perpindahan.ChangedByUserId, batal);
            if (token.Count == 0) continue;

            mati.AddRange(await pengirim.KirimAsync(token, kabar.Pesan, batal));
        }

        if (mati.Count == 0) return;

        // Token yang sudah tidak menunjuk pemasangan mana pun dibuang begitu ketahuan.
        // Dihapus lewat ExecuteDelete, bukan lewat pelacak perubahan, supaya penghapusan ini
        // tidak ikut menyimpan apa pun yang kebetulan masih tertunda di DbContext pemanggil.
        await db.PerangkatNotifikasi
            .Where(p => mati.Contains(p.Token))
            .ExecuteDeleteAsync(batal);
    }

    private Task<List<string>> TokenAsync(
        SasaranKabar sasaran,
        Order order,
        Guid? aktor,
        CancellationToken batal)
    {
        if (!sasaran.SemuaRunner)
        {
            var id = sasaran.UserId.ToArray();
            return db.PerangkatNotifikasi
                .Where(p => id.Contains(p.UserId))
                .Select(p => p.Token)
                .ToListAsync(batal);
        }

        // Guid.Empty, bukan null, dan ini bukan kerapian: pembandingan dengan NULL di SQL
        // tidak pernah bernilai benar, jadi `p.UserId != aktor` dengan aktor null akan
        // menyaring habis seluruh barisnya. Siaran order baru justru selalu lahir dari
        // webhook pembayaran, yang tidak punya aktor sama sekali.
        var pemicu = aktor ?? Guid.Empty;

        return db.PerangkatNotifikasi
            // Pemicunya sendiri dilewati (runner yang barusan melepas order tidak perlu
            // ditawari order yang baru saja ia lepas), begitu juga pemesannya, yang bisa
            // saja kebetulan memegang peran runner juga.
            .Where(p => p.UserId != pemicu && p.UserId != order.ClientId)
            .Where(p => db.Users.Any(u =>
                u.Id == p.UserId &&
                u.SuspendedAt == null &&
                u.Roles.Contains(UserRole.Runner)))
            .Select(p => p.Token)
            .Take(PengirimNotifikasiFirebase.BatasSatuKirim)
            .ToListAsync(batal);
    }
}
