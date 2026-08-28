import '../models/transaksi_pembayaran.dart';

/// Kontrak ke payment gateway, lewat server sendiri.
///
/// Bentuknya mengikuti alur Midtrans/Xendit yang sebenarnya:
///
///   1. Aplikasi minta transaksi dibuat, dapat isi QR dan batas waktu.
///   2. Klien membayar lewat aplikasi bank/e-wallet-nya sendiri.
///   3. Gateway mengabarkan server bahwa uang sudah masuk.
///   4. Order maju sendiri ke tahap berikutnya.
///
/// Langkah 1 dan 3 wajib lewat server: langkah 1 memakai Server Key yang tidak
/// boleh ada di dalam aplikasi, dan langkah 3 datang sebagai webhook yang harus
/// punya alamat. Aplikasi tidak pernah bicara ke gateway secara langsung.
///
/// ## Kenapa semuanya bersumbu pada order, bukan pada id transaksi
///
/// Satu order boleh melahirkan beberapa transaksi: yang pertama hangus lewat
/// batas waktu, klien mencoba lagi. Yang selalu ingin diketahui layar adalah
/// "bagaimana keadaan pembayaran order ini sekarang", bukan "bagaimana keadaan
/// transaksi bernomor sekian". Kalau kuncinya id transaksi, layar harus
/// menyimpan sendiri transaksi mana yang sedang berlaku, dan menyimpan hal itu
/// di layar berarti membuka ulang layarnya menghilangkan jawabannya.
///
/// ## Jumlah tagihan tidak ada di sini
///
/// Sengaja, bukan kelupaan, dan sebabnya sama dengan hilangnya identitas
/// pemanggil dari kontrak order: apa pun yang boleh disebut aplikasi bisa
/// diganti aplikasi. Klien yang boleh menyebut jumlah yang ia bayar tinggal
/// membuat tagihan seribu rupiah untuk pekerjaan lima puluh ribu. Jumlahnya
/// diambil server dari harga ordernya.
abstract interface class PaymentGateway {
  /// Membuat tagihan untuk sebuah order, atau mengembalikan yang masih menunggu.
  ///
  /// Membuka ulang layar bayar tidak melahirkan QR baru. Dua QR untuk satu order
  /// berarti klien bisa membayar dua kali untuk pekerjaan yang sama, dan yang
  /// kedua harus dikembalikan.
  Future<TransaksiPembayaran> buatTransaksi({required String orderId});

  /// Keadaan pembayaran order itu, diamati terus-menerus.
  ///
  /// Inilah pengganti webhook di sisi aplikasi: aplikasi tidak pernah
  /// menyimpulkan sendiri bahwa pembayaran berhasil, ia hanya mendengarkan.
  Stream<TransaksiPembayaran> watchTransaksi(String orderId);

  /// Membatalkan tagihan yang masih menunggu.
  ///
  /// Bukan membatalkan ordernya. Ordernya tetap menunggu pembayaran, dan klien
  /// bisa minta tagihan baru.
  Future<void> batalkanTransaksi(String orderId);
}
