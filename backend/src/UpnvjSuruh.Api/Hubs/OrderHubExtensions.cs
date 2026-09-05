using Microsoft.AspNetCore.SignalR;

namespace UpnvjSuruh.Api.Hubs;

/// <summary>
/// Satu titik panggil untuk memberi tahu semua yang berkepentingan bahwa status sebuah
/// order berubah: dashboard admin, dan siapa pun yang sedang membuka layar order itu.
/// </summary>
/// <remarks>
/// Ditulis sekali dan dipanggil dari sembilan tempat berbeda (order dibuat lewat Jalur A
/// atau Jalur B, penawaran Jalur B disetujui, pembayaran lunas di kedua jalur, runner
/// menerima, order selesai, order dibatalkan lewat dua jalur pembatalan yang berbeda),
/// karena kalau tiap tempat menyusun panggilannya sendiri, cepat atau lambat ada satu yang
/// lupa menyertakan grup yang benar atau mengetik nama kabar yang berbeda satu huruf.
///
/// Mengikuti pola yang sama dengan sisi mobile (rencana capstone bagian 37.2): kabar apa pun
/// dari hub cukup jadi sinyal "ada yang berubah, ambil ulang", bukan muatan yang harus
/// dipercaya isinya. Dashboard yang menerimanya memuat ulang daftarnya sendiri lewat endpoint
/// biasa, jadi tidak ada bentuk data di sini yang perlu dijaga tetap sama dengan
/// <c>OrderResponse</c> di dua tempat sekaligus.
///
/// <see cref="Guid"/> order tetap disertakan, sekadar sebagai petunjuk bagi siapa pun yang
/// membaca log jaringan saat menelusuri masalah, bukan sesuatu yang dibaca kode dashboard.
/// Mengirim id tanpa keterangan lain (nama klien, alamat) tidak membocorkan apa pun yang
/// belum boleh diketahui admin — admin sudah berhak melihat seluruh order lewat
/// <c>AdminOrderController</c>.
///
/// Sengaja dikirim untuk setiap perubahan status, bukan untuk setiap perubahan pada sebuah
/// order. Perubahan yang tidak menggeser status (klien menolak satu penawaran Jalur B,
/// runner mengirim penawaran baru, pembayaran yang jumlahnya tidak cocok) tidak akan terlihat
/// beda apa pun di layar Pantauan Order, yang menampilkan dan menyaring order menurut
/// statusnya; mengirim kabar untuk perubahan yang tidak kelihatan cuma membuat koneksi sibuk
/// tanpa ada yang berubah di layar.
/// </remarks>
public static class OrderHubExtensions
{
    /// <remarks>
    /// Dikirim ke dua grup sekaligus sejak rencana capstone bagian 43: grup admin, dan grup
    /// order itu sendiri. Grup admin saja tidak cukup — klien yang menatap layar detail
    /// ordernya menunggu kabar "sudah ada runner yang menerima", dan runner yang baru
    /// mengirim penawaran Jalur B menunggu kabar "penawaranmu dipilih". Keduanya perubahan
    /// yang sama, cuma dilihat dari sisi yang berbeda, dan sebelum ini keduanya baru muncul
    /// setelah pengambilan berkala lima belas detik berikutnya.
    ///
    /// Satu koneksi yang kebetulan ada di kedua grup (admin yang sedang membuka satu order)
    /// menerimanya dua kali. Itu dibiarkan: kabarnya cuma berarti "ambil ulang", dan sisi
    /// klien sudah menggabungkan permintaan yang datang beruntun jadi satu pengambilan
    /// (lihat penjaga <c>sedangAmbil</c>/<c>mintaLagi</c> di <c>ApiOrderRepository</c>).
    /// Menghindarinya butuh daftar koneksi yang harus dijaga sendiri, untuk menghemat satu
    /// pesan yang sudah tidak berakibat apa-apa.
    /// </remarks>
    public static Task BeriTahuPerubahanOrderAsync(
        this IHubContext<OrderHub> hub,
        Guid orderId,
        CancellationToken batal = default) =>
        hub.Clients
            .Groups(OrderHub.AdminsGroup, OrderHub.GrupOrder(orderId))
            .SendAsync("OrderChanged", new { OrderId = orderId }, batal);

    /// <summary>
    /// Memberi tahu klien yang sedang membuka layar bayar order ini bahwa tagihannya
    /// bergeser dari menunggu.
    /// </summary>
    /// <remarks>
    /// Dipanggil dari <c>PenyelesaiPembayaran</c> di setiap titik keluar sesudah
    /// <c>Payment.Menunggu</c> berhenti benar — lunas, gagal, kedaluwarsa lewat webhook,
    /// atau jumlahnya tidak cocok — bukan cuma saat lunas. Layar bayar sisi mobile
    /// menggambar keempat keadaan itu secara berbeda (lihat cabang <c>switch</c> di
    /// <c>PembayaranScreen</c>: berhasil, menunggu, atau keadaan akhir lainnya), jadi
    /// keempatnya sama-sama layak diberi tahu seketika, bukan cuma yang lunas.
    ///
    /// Grup yang dikirimi cuma diisi klien yang benar-benar pemilik order ini
    /// (<see cref="OrderHub.GabungOrder"/> memeriksa itu sebelum mengizinkan bergabung),
    /// jadi kabar ini tidak perlu menyaring lagi siapa yang boleh menerimanya.
    /// </remarks>
    public static Task BeriTahuKlienAsync(
        this IHubContext<OrderHub> hub,
        Guid orderId,
        CancellationToken batal = default) =>
        hub.Clients.Group(OrderHub.GrupOrder(orderId)).SendAsync("PaymentChanged", new { OrderId = orderId }, batal);

    /// <summary>
    /// Memberi tahu semua yang sedang membuka satu order bahwa ada pesan chat baru di sana.
    /// </summary>
    /// <remarks>
    /// Ini yang membuat chat berhenti terasa seperti surat: sebelumnya kedua belah pihak
    /// cuma mengambil ulang percakapan setiap lima belas detik, jadi jawaban tercepat pun
    /// baru muncul rata-rata tujuh detik setelah dikirim. Untuk fitur yang seluruh gunanya
    /// adalah menggantikan WhatsApp (rencana capstone bagian 4), jeda selama itu adalah
    /// alasan orang kembali ke WhatsApp.
    ///
    /// Dikirim ke seluruh grup order, termasuk koneksi pengirimnya sendiri.
    /// <c>IHubContext</c> di sisi controller tidak tahu koneksi mana yang barusan mengirim
    /// pesan lewat HTTP (permintaan HTTP dan koneksi hub adalah dua sambungan berbeda),
    /// jadi mengecualikan pengirim butuh id koneksi yang harus dikirim ikut permintaannya —
    /// bentuk permintaan yang lebih rumit demi menghindari satu pengambilan ulang yang
    /// hasilnya sudah dipegang layarnya. Tidak sepadan.
    ///
    /// Muatannya cuma id order, sama seperti dua kabar lain, dan bukan isi pesannya. Isi
    /// pesan lewat kabar hub berarti aturan siapa boleh melihat jalur obrolan mana
    /// (<c>PesanTerlihat</c>, jalur pribadi tiap runner yang menawar di Jalur B) harus
    /// ditegakkan dua kali di dua tempat berbeda. Cukup sekali, di endpoint yang diambil
    /// ulang sesudah kabar ini diterima.
    ///
    /// Akibat sampingannya disebut terang-terangan: pada order Jalur B dengan beberapa
    /// runner yang menawar, kabar ini sampai ke semuanya, jadi seorang runner bisa
    /// menyimpulkan "ada percakapan yang bergerak di order ini" tanpa tahu isinya, siapa
    /// yang menulis, atau di jalur siapa. Pengambilan ulang yang menyusul tetap cuma
    /// mengembalikan jalur obrolannya sendiri. Menyembunyikan itu pun butuh kabar yang
    /// ditujukan per jalur obrolan, yang berarti aturan <c>PesanTerlihat</c> harus ditulis
    /// ulang di sisi hub — persis duplikasi yang dihindari di paragraf sebelumnya, demi
    /// menutup sinyal yang tidak menyebut apa-apa.
    /// </remarks>
    public static Task BeriTahuPesanBaruAsync(
        this IHubContext<OrderHub> hub,
        Guid orderId,
        CancellationToken batal = default) =>
        hub.Clients.Group(OrderHub.GrupOrder(orderId)).SendAsync("MessageAdded", new { OrderId = orderId }, batal);
}
