import '../../domain/repositories/foto_bukti_repository.dart';

/// Tiruan kamera + penyimpanan foto.
///
/// Kamera sungguhan belum dipasang bukan karena sulit, tapi karena separuh
/// pekerjaannya belum punya tempat: foto harus diunggah ke suatu penyimpanan,
/// dan penyimpanan itu ikut menunggu pilihan stack (bagian 14.4). Memasang
/// kamera lebih dulu berarti punya berkas yang tidak bisa dikirim ke mana pun.
///
/// URL yang dikembalikan sengaja berskema `fake://` supaya tidak pernah bisa
/// disangka tautan sungguhan — sama alasannya dengan payload QR palsu di layar
/// pembayaran yang sengaja dibuat gagal dipindai.
class FakeFotoBuktiRepository implements FotoBuktiRepository {
  /// Sepadan dengan waktu membuka kamera, memotret, lalu mengunggah.
  static const Duration _jedaUnggah = Duration(milliseconds: 600);

  @override
  Future<String?> ambilDanUnggah({required String orderId}) async {
    await Future<void>.delayed(_jedaUnggah);
    return 'fake://bukti/$orderId-${DateTime.now().millisecondsSinceEpoch}.jpg';
  }
}
