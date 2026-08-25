import '../models/transaksi_pembayaran.dart';

/// Kontrak ke payment gateway.
///
/// Bentuknya sengaja dibuat sama dengan alur Midtrans/Xendit yang sebenarnya,
/// supaya penggantian nanti tidak menyentuh satu layar pun:
///
///   1. Aplikasi minta transaksi dibuat → dapat isi QR dan batas waktu.
///   2. Klien membayar lewat aplikasi bank/e-wallet-nya sendiri.
///   3. Gateway memberi tahu bahwa uang sudah masuk.
///   4. Order maju sendiri ke tahap berikutnya.
///
/// Langkah 1 dan 3 **wajib** lewat server: langkah 1 memakai Server Key yang
/// tidak boleh ada di dalam aplikasi, dan langkah 3 datang sebagai webhook
/// yang harus ada alamatnya. Karena backend UPNVJ Suruh belum diputuskan
/// (.NET atau Supabase, rencana capstone bagian 14.4), implementasi yang hidup
/// sekarang adalah tiruan. Yang ditiru cuma pengirim konfirmasinya — bentuk
/// alurnya sudah yang sebenarnya.
abstract interface class PaymentGateway {
  /// Membuat transaksi baru untuk sebuah order.
  ///
  /// Kalau order itu sudah punya transaksi yang masih menunggu, transaksi lama
  /// yang dikembalikan — bukan bikin QR baru tiap layar dibuka.
  Future<TransaksiPembayaran> buatTransaksi({
    required String orderId,
    required int jumlah,
  });

  /// Status transaksi, diamati terus-menerus.
  ///
  /// Inilah pengganti webhook di sisi aplikasi: aplikasi tidak pernah
  /// menyimpulkan sendiri bahwa pembayaran berhasil, ia hanya mendengarkan.
  Stream<TransaksiPembayaran> watchTransaksi(String transaksiId);

  /// Membatalkan transaksi yang masih menunggu.
  Future<void> batalkanTransaksi(String transaksiId);
}
