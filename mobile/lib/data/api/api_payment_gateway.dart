import 'dart:async';

import '../../core/api/klien_api.dart';
import '../../core/realtime/order_hub_client.dart';
import '../../domain/models/transaksi_pembayaran.dart';
import '../../domain/repositories/payment_gateway.dart';
import 'pemeta_transaksi.dart';

/// Pembayaran lewat API .NET.
///
/// Aplikasi tidak pernah menyentuh Midtrans atau Xendit langsung: ia meminta
/// tagihan ke servernya sendiri, dan servernya yang memegang Server Key serta
/// menerima webhook. Yang berubah nanti ketika mitra memilih gateway ada di sisi
/// server; kelas ini tidak perlu disentuh.
///
/// ## Mengintip berkala, dipercepat dengan kabar dari hub
///
/// Kabar bahwa uang sudah masuk mendarat di server sebagai webhook. `OrderHub`
/// sekarang punya grup per-order (rencana capstone bagian 41): begitu
/// [watchTransaksi] mulai, ia meminta [SaluranHubOrder] bergabung ke grup order
/// itu (`ikutiOrder`), dan setiap kabar yang lewat membuat putaran tunggunya
/// berhenti lebih awal alih-alih menunggu jeda intip penuh.
///
/// Pengintipan berkala TIDAK dihapus, cuma dipersingkat efeknya, mengikuti
/// alasan yang sama dengan `ApiOrderRepository` (bagian 37.3): koneksi hub bisa
/// putus sesaat (jaringan kampus yang goyah, tab yang lama tidak difokuskan),
/// dan pengintipan itu tetap menjaga layar ini tidak menunggu selamanya kalau
/// itu terjadi tepat saat pembayaran lunas.
///
/// Jedanya lebih rapat daripada penyegaran daftar order, dan itu disengaja: di
/// layar ini pengguna sedang menatap layarnya sambil menunggu, jadi basi lima
/// belas detik terasa seperti aplikasi yang menggantung — sekalipun sekarang
/// itu cuma jaring pengaman, bukan jalur utama saat koneksinya hidup.
/// Pengintipan berhenti begitu statusnya final, jadi ia tidak berjalan
/// sepanjang aplikasi terbuka.
class ApiPaymentGateway implements PaymentGateway {
  ApiPaymentGateway({required KlienApi klien, SaluranHubOrder? hub, Duration? jedaIntip})
    : _klien = klien,
      _hub = hub,
      _jedaIntip = jedaIntip ?? const Duration(seconds: 3);

  final KlienApi _klien;
  final SaluranHubOrder? _hub;
  final Duration _jedaIntip;

  @override
  Future<TransaksiPembayaran> buatTransaksi({required String orderId}) async {
    // Perhatikan tidak ada badan permintaan. Jumlahnya diambil server dari harga
    // ordernya, dan tidak ada tempat di sini untuk menyebutkannya.
    final jawaban = await _klien.post('/api/orders/$orderId/pembayaran');
    return PemetaTransaksi.transaksi(jawaban);
  }

  @override
  Stream<TransaksiPembayaran> watchTransaksi(String orderId) async* {
    var terakhir = await _ambil(orderId);
    yield terakhir;

    // Diminta sekali di sini, bukan di dalam gerbang gabungan yang dipakai
    // provider, karena kontrak inilah tempat pemanggil sungguh mulai
    // "mengamati" order ini. Ditinggalkan di finally, bukan begitu status
    // final tercapai, supaya layar yang ditutup di tengah menunggu (klien
    // berpindah layar sebelum sempat membayar) tidak meninggalkan langganan
    // yang menggantung di sisi soket selamanya.
    //
    // "Selamanya" di atas sengaja bukan "seketika". Generator async* ini
    // cuma menyimak pembatalan langganannya pada titik "yield" berikutnya,
    // bukan di tengah await yang sedang tertunda dan bukan pula pada
    // evaluasi ulang syarat "while". Kalau layar bayar ditutup persis
    // selagi menunggu di _tungguPerubahanAtauJeda, finally di bawah baru
    // jalan begitu satu "yield sekarang;" sungguh tereksekusi sesudahnya —
    // yaitu begitu statusnya sungguh berubah, bukan cuma begitu satu jeda
    // intip berlalu. Order yang macet Pending selamanya (kabar gateway
    // tidak pernah datang) berarti keanggotaan grupnya ikut tidak pernah
    // dibersihkan sampai order itu akhirnya kedaluwarsa dan status yang
    // dibaca berubah. Itu batas yang bisa diterima untuk sesuatu yang cuma
    // menahan satu baris keanggotaan grup di server, bukan sumber daya
    // yang mahal dibiarkan menganggur.
    _hub?.ikutiOrder(orderId);
    try {
      while (terakhir.menunggu) {
        await _tungguPerubahanAtauJeda();
        final sekarang = await _ambil(orderId);

        // Hanya perubahan yang diteruskan. Mengirim ulang keadaan yang sama
        // tiap beberapa detik akan membangunkan layarnya terus-menerus tanpa
        // ada yang berubah di sana.
        if (sekarang.status != terakhir.status || sekarang.id != terakhir.id) {
          yield sekarang;
        }
        terakhir = sekarang;
      }
    } finally {
      _hub?.berhentiIkutiOrder(orderId);
    }
  }

  /// Menunggu jeda intip penuh, KECUALI hub memberi kabar lebih dulu.
  ///
  /// `Future.any` dipilih di atas `StreamGroup` atau sejenisnya karena yang
  /// dibutuhkan cuma "yang mana pun duluan", bukan menggabungkan dua aliran
  /// jadi satu untuk dipakai berulang — putaran berikutnya memanggil ini lagi
  /// dan berlangganan [SaluranHubOrder.perubahan] dari awal.
  ///
  /// Tanpa hub yang tersambung ([_hub] null, atau hub ada tapi sedang
  /// terputus), ini berperilaku persis kode lama: menunggu jeda intip apa
  /// adanya.
  Future<void> _tungguPerubahanAtauJeda() {
    return Future.any<void>([
      Future<void>.delayed(_jedaIntip),
      ?_hub?.perubahan.first,
    ]);
  }

  @override
  Future<void> batalkanTransaksi(String orderId) async {
    await _klien.post('/api/orders/$orderId/pembayaran/batal');
  }

  /// Menandai tagihan order ini lunas lewat tiruan gateway di server.
  ///
  /// Alat penguji, padanan halaman simulator di sandbox Midtrans. Endpoint yang
  /// dipanggilnya hanya didaftarkan server saat berjalan di Development, jadi di
  /// produksi panggilan ini tidak menemukan apa-apa. Penjagaan keduanya ada di
  /// sisi aplikasi: penyedianya cuma memberikan fungsi ini di build debug.
  Future<void> simulasikanPembayaranMasuk(String orderId) async {
    await _klien.post('/api/dev/pembayaran/$orderId/lunas');
  }

  Future<TransaksiPembayaran> _ambil(String orderId) async {
    final jawaban = await _klien.get('/api/orders/$orderId/pembayaran');
    return PemetaTransaksi.transaksi(jawaban);
  }
}
