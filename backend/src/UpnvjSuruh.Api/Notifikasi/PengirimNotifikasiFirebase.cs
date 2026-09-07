using FirebaseAdmin;
using FirebaseAdmin.Messaging;

namespace UpnvjSuruh.Api.Notifikasi;

/// <summary>
/// Pengiriman sungguhan lewat Firebase Cloud Messaging.
///
/// ## Kenapa lewat paket resminya, bukan HTTP biasa
///
/// FCM versi sekarang menuntut token OAuth2 yang ditandatangani RS256 dengan kunci privat
/// akun layanan, diperbarui tiap jam. Menulisnya sendiri berarti menulis penandatangan JWT,
/// penyimpan token beserta pembaruannya, dan pemetaan kode galatnya -- untuk sesuatu yang
/// sudah dikerjakan paket resmi Google. Ini kebalikan dari keputusan <c>PembersihExif</c>,
/// yang menolak menambah pustaka gambar demi melompati satu segmen JPEG: di sana pustakanya
/// jauh lebih besar daripada masalahnya, di sini masalahnya (kriptografi dan pembaruan
/// kredensial) justru yang tidak layak ditulis sendiri.
///
/// ## Prioritas tinggi, dan kenapa itu inti persoalannya
///
/// Rencana capstone bagian 9 menyebut notifikasi yang tidak sampai sebagai risiko paling
/// kritis versi mobile: penghemat baterai bawaan Xiaomi, Oppo, dan Vivo membunuh notifikasi
/// aplikasi yang jarang dibuka tanpa memberi tahu siapa pun. <c>Priority.High</c> adalah
/// satu-satunya tuas sisi server terhadap itu -- pesan berprioritas tinggi membangunkan
/// perangkat yang sedang mengantuk, sedangkan yang normal boleh ditahan sistem sampai
/// perangkatnya terbangun sendiri, yang bisa berarti berjam-jam. Ia tidak menyelesaikan
/// seluruh masalahnya (pembunuh proses yang agresif tetap menang), dan sisanya memang tidak
/// bisa diselesaikan dari sini: itulah kenapa jalur cadangan WhatsApp tetap ada di rencana.
/// </summary>
public class PengirimNotifikasiFirebase : IPengirimNotifikasi
{
    /// <summary>
    /// Batas satu panggilan multicast di FCM. Bukan angka pilihan sendiri.
    ///
    /// ponytail: siaran ke seluruh runner dipotong pada angka ini di <c>PengabarOrder</c>.
    /// Kalau runner mitra suatu saat lebih dari itu, yang dipasang perulangan per potongan
    /// 500 di sini, bukan angka yang dinaikkan.
    /// </summary>
    public const int BatasSatuKirim = 500;

    private readonly FirebaseMessaging _messaging;
    private readonly ILogger<PengirimNotifikasiFirebase> _log;

    public PengirimNotifikasiFirebase(FirebaseApp app, ILogger<PengirimNotifikasiFirebase> log)
    {
        _messaging = FirebaseMessaging.GetMessaging(app);
        _log = log;
    }

    public async Task<IReadOnlyCollection<string>> KirimAsync(
        IReadOnlyCollection<string> token,
        PesanNotifikasi pesan,
        CancellationToken batal = default)
    {
        if (token.Count == 0) return [];

        var daftar = token.Take(BatasSatuKirim).ToList();

        // Tokens sudah ditandai usang paket ini, yang menyarankan Fids (Firebase
        // Installation ID). Sengaja tetap Tokens: yang diserahkan aplikasi lewat
        // firebase_messaging adalah token pendaftaran, dan itu memang isi kolom ini.
        // Menaruh token pendaftaran di kolom yang menuntut installation ID adalah
        // penggantian yang tidak bisa dibuktikan benar dari sini, dan kegagalannya berbentuk
        // notifikasi yang diam-diam tidak sampai -- persis kegagalan yang seluruh fitur ini
        // ada untuk mencegahnya. Diganti kalau nanti terbukti di perangkat sungguhan.
#pragma warning disable CS0618
        var jawaban = await _messaging.SendEachForMulticastAsync(
            new MulticastMessage
            {
                Tokens = daftar,
                Notification = new Notification { Title = pesan.Judul, Body = pesan.Isi },
                // Dibaca aplikasi saat notifikasinya diketuk, supaya yang terbuka layar
                // ordernya, bukan beranda. Nilainya string karena FCM cuma mengangkut
                // string di sini.
                Data = new Dictionary<string, string> { ["orderId"] = pesan.OrderId.ToString() },
                Android = new AndroidConfig { Priority = Priority.High },
            },
            batal);
#pragma warning restore CS0618

        var mati = new List<string>();
        for (var i = 0; i < jawaban.Responses.Count; i++)
        {
            var satu = jawaban.Responses[i];
            if (satu.IsSuccess) continue;

            var kode = satu.Exception?.MessagingErrorCode;

            // Dua kode ini berarti tokennya memang sudah tidak menunjuk pemasangan mana pun,
            // dan barisnya layak dibuang. Sisanya (kuota, gangguan jaringan, galat server
            // Firebase) adalah kegagalan sementara: membuang token karenanya berarti
            // memutus perangkat yang sehat gara-gara Firebase sedang sibuk.
            if (kode is MessagingErrorCode.Unregistered or MessagingErrorCode.SenderIdMismatch)
            {
                mati.Add(daftar[i]);
                continue;
            }

            _log.LogWarning(
                satu.Exception,
                "Notifikasi order {OrderId} gagal ke satu perangkat, kode {Kode}.",
                pesan.OrderId,
                kode);
        }

        return mati;
    }
}
