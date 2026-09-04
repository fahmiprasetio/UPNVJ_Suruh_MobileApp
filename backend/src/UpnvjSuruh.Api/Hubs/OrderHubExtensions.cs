using Microsoft.AspNetCore.SignalR;

namespace UpnvjSuruh.Api.Hubs;

/// <summary>
/// Satu titik panggil untuk memberi tahu dashboard admin bahwa status sebuah order berubah.
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
    public static Task BeriTahuAdminAsync(
        this IHubContext<OrderHub> hub,
        Guid orderId,
        CancellationToken batal = default) =>
        hub.Clients.Group(OrderHub.AdminsGroup).SendAsync("OrderChanged", new { OrderId = orderId }, batal);

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
}
