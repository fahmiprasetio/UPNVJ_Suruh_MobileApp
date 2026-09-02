import 'dart:async';

import '../../core/api/klien_api.dart';
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
/// ## Kenapa mengintip berkala, bukan menunggu dikabari
///
/// Kabar bahwa uang sudah masuk mendarat di server sebagai webhook. `OrderHub`
/// (lihat `OrderHubClient`) sekarang tersambung, tapi cuma menyiarkan ke grup
/// runner (order berbayar yang butuh diambil) — bukan ke klien yang sedang
/// menunggu tagihannya sendiri lunas, karena itu butuh saluran per-order yang
/// belum ada. Sampai itu ada, layar bayar menanyakan keadaannya berulang kali.
///
/// Jedanya lebih rapat daripada penyegaran daftar order, dan itu disengaja: di
/// layar ini pengguna sedang menatap layarnya sambil menunggu, jadi basi lima
/// belas detik terasa seperti aplikasi yang menggantung. Pengintipan berhenti
/// begitu statusnya final, jadi ia tidak berjalan sepanjang aplikasi terbuka.
class ApiPaymentGateway implements PaymentGateway {
  ApiPaymentGateway({required KlienApi klien, Duration? jedaIntip})
    : _klien = klien,
      _jedaIntip = jedaIntip ?? const Duration(seconds: 3);

  final KlienApi _klien;
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

    while (terakhir.menunggu) {
      await Future<void>.delayed(_jedaIntip);
      final sekarang = await _ambil(orderId);

      // Hanya perubahan yang diteruskan. Mengirim ulang keadaan yang sama tiap
      // beberapa detik akan membangunkan layarnya terus-menerus tanpa ada yang
      // berubah di sana.
      if (sekarang.status != terakhir.status || sekarang.id != terakhir.id) {
        yield sekarang;
      }
      terakhir = sekarang;
    }
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
