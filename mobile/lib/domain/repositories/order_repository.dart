import '../enums.dart';
import '../models/order.dart';

/// Kontrak akses data order.
///
/// Seluruh UI bicara ke antarmuka ini, tidak pernah langsung ke server. Selama
/// pilihan stack backend belum dikunci (rencana capstone bagian 14.4),
/// implementasinya adalah data palsu di memori. Ketika stack dipilih, cukup
/// tulis satu implementasi baru — `ApiOrderRepository` untuk .NET atau
/// `SupabaseOrderRepository` — dan tukar di provider. Tidak ada layar yang
/// perlu diubah.
abstract interface class OrderRepository {
  /// Order milik satu klien, terbaru di atas.
  Stream<List<Order>> watchOrderKlien(String klienId);

  /// Order yang sedang disiarkan dan masih punya sisa kuota runner.
  Stream<List<Order>> watchOrderTersiar();

  /// Order yang sedang dipegang satu runner.
  Stream<List<Order>> watchOrderRunner(String runnerId);

  Stream<Order?> watchOrder(String orderId);

  Future<Order?> getOrder(String orderId);

  /// Jalur A: harga sudah diketahui saat order dibuat, jadi order langsung
  /// masuk status [OrderStatus.menungguPembayaran].
  Future<Order> buatOrderJalurA({
    required String klienId,
    required ServiceType serviceType,
    required int harga,
    String? deskripsi,
    String? alamatJemput,
    String? alamatTujuan,
  });

  /// Jalur B: harga belum ada. Order lahir sebagai [OrderStatus.permintaan]
  /// dan menunggu admin membuat penawaran.
  Future<Order> buatPermintaanJalurB({
    required String klienId,
    required ServiceType serviceType,
    required String deskripsi,
    String? alamatTujuan,
    int jumlahRunnerDibutuhkan = 1,
  });

  /// Menandai pembayaran berhasil dan menyiarkan order ke runner.
  Future<Order> tandaiSudahDibayar(String orderId);

  /// Runner menekan TERIMA.
  ///
  /// Mengembalikan `true` kalau runner ini berhasil mendapat slot, `false`
  /// kalau kuota sudah keburu penuh diambil runner lain. Inti teknis proyek —
  /// implementasi sesungguhnya harus atomik di level basis data, bukan cuma di
  /// tampilan (bagian 14.5).
  Future<bool> terimaOrder({required String orderId, required String runnerId});

  /// Runner menandai pekerjaannya selesai.
  ///
  /// [runnerId] wajib karena yang berhak menutup order hanya runner yang
  /// memegangnya. Pemeriksaan itu tempatnya di sini, bukan di layar: tombol
  /// yang disembunyikan tidak menghentikan siapa pun yang memanggil langsung.
  ///
  /// Foto bukti wajib ada — itu yang membedakan pekerjaan selesai dari
  /// pengakuan selesai.
  Future<Order> selesaikanOrder({
    required String orderId,
    required String runnerId,
    required String fotoBuktiUrl,
    String? catatanSerahTerima,
  });

  Future<Order> batalkanOrder(String orderId);
}
