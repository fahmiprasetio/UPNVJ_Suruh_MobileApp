import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/klien_api.dart';
import '../../domain/repositories/foto_bukti_repository.dart';

/// Kamera perangkat (atau pemilih berkas di web), lalu unggah ke server.
///
/// Dua langkah di balik satu panggilan, karena dari sisi runner memang satu tindakan:
/// "ambil foto bukti". Yang dikembalikan URL, bukan berkas, jadi kalau ada nilainya
/// artinya fotonya sudah aman di server dan bisa dibuka klien maupun admin.
///
/// ## Kenapa kameranya dibatasi, bukan galeri
///
/// Di perangkat bergerak asli (Android/iOS), sumbernya dikunci ke kamera agar runner
/// mengambil foto di tempat kejadian. Namun di platform web (`kIsWeb`), browser desktop
/// tidak memiliki kamera langsung yang fleksibel dan atribut capture sering diblokir
/// oleh browser sandbox/iframe/Brave Shields. Karena itu pada web digunakan galeri/berkas.
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
      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
      maxWidth: _lebarMaks,
      imageQuality: _mutu,
    );

    // Runner menutup kamera/pemilih berkas tanpa memilih. Keadaan yang sah, bukan galat.
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

  @override
  Future<String> unggahFotoEstimasi({
    required String orderId,
    required String namaBerkas,
    required Uint8List isi,
  }) async {
    final jawaban = await _klien.postBerkas(
      '/api/orders/$orderId/foto-estimasi',
      kolom: 'berkas',
      namaBerkas: namaBerkas,
      isi: isi,
    );
    final url = jawaban['url'];
    if (url is! String || url.isEmpty) {
      throw StateError('Server tidak mengembalikan alamat foto.');
    }
    return url;
  }
}
