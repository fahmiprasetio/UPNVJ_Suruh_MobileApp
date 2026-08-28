import 'package:image_picker/image_picker.dart';

import '../../core/api/klien_api.dart';
import '../../domain/repositories/foto_bukti_repository.dart';

/// Kamera perangkat, lalu unggah ke server.
///
/// Dua langkah di balik satu panggilan, karena dari sisi runner memang satu tindakan:
/// "ambil foto bukti". Yang dikembalikan URL, bukan berkas, jadi kalau ada nilainya
/// artinya fotonya sudah aman di server dan bisa dibuka klien maupun admin.
///
/// ## Kenapa kameranya dibatasi, bukan galeri
///
/// Sumbernya dikunci ke kamera, bukan dibiarkan memilih dari galeri. Foto bukti yang
/// boleh diambil dari galeri berarti runner bisa memakai foto lama, foto pekerjaan
/// lain, atau foto yang dikirim orang. Ini bukan penjagaan yang tidak bisa ditembus,
/// karena galeri masih bisa dijangkau lewat cara lain di perangkat yang sudah
/// disiapkan untuk itu, tapi ia membuat jalan mudahnya tertutup.
///
/// ## Ukuran dikecilkan di perangkat
///
/// Foto kamera ponsel sekarang bisa belasan megabita, dan server menolak yang lebih
/// dari delapan. Mengecilkannya di sini, bukan menaikkan batas di server: yang
/// dilihat orang di layar detail order adalah gambar selebar layar ponsel, jadi
/// piksel selebihnya cuma menghabiskan kuota runner yang mengunggahnya di lapangan.
class ApiFotoBuktiRepository implements FotoBuktiRepository {
  ApiFotoBuktiRepository({required KlienApi klien, ImagePicker? kamera})
    : _klien = klien,
      _kamera = kamera ?? ImagePicker();

  static const double _lebarMaks = 1600;
  static const int _mutu = 85;

  final KlienApi _klien;
  final ImagePicker _kamera;

  @override
  Future<String?> ambilDanUnggah({required String orderId}) async {
    final foto = await _kamera.pickImage(
      source: ImageSource.camera,
      maxWidth: _lebarMaks,
      imageQuality: _mutu,
    );

    // Runner menutup kamera tanpa memotret. Keadaan yang sah, bukan galat.
    if (foto == null) return null;

    final isi = await foto.readAsBytes();
    final jawaban = await _klien.postBerkas(
      '/api/orders/$orderId/foto-bukti',
      kolom: 'berkas',
      // Nama berkasnya tidak menentukan apa pun di server: nama yang dipakai di sana
      // dibuat server sendiri, dan jenis gambarnya ditentukan dari isi berkasnya.
      // Yang dikirim di sini cuma supaya bagian multipart-nya berbentuk lengkap.
      namaBerkas: foto.name,
      isi: isi,
    );

    final url = jawaban['url'];
    if (url is! String || url.isEmpty) {
      throw StateError('Server tidak mengembalikan alamat foto.');
    }
    return url;
  }
}
