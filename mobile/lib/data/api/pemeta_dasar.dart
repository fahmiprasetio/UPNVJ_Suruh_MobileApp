import '../../core/api/galat_api.dart';
import '../../domain/models/halaman.dart';

/// Potongan pembacaan JSON yang dipakai lebih dari satu pemeta.
///
/// Dipisahkan ketika pemeta kedua lahir, bukan disiapkan sejak awal. Yang
/// dijaga di sini bukan kerapian melainkan satu perilaku: field yang bentuknya
/// tidak sesuai harus melempar, bukan jadi `null`. Salinan kedua dari aturan itu
/// akan pelan-pelan menyimpang, dan yang paling mungkin disimpangkan adalah
/// pemeriksaannya, karena itulah bagian yang menyusahkan saat menulis tes.
class PemetaDasar {
  const PemetaDasar._();

  static String teks(Map<String, dynamic> isi, String kunci) {
    final nilai = isi[kunci];
    if (nilai is! String || nilai.isEmpty) {
      throw GalatServer('Jawaban server tidak memuat $kunci.');
    }
    return nilai;
  }

  /// Rupiah penuh. Server mengirimnya sebagai angka desimal, tapi rupiah tidak
  /// punya sen, dan `double` untuk uang adalah sumber galat pembulatan.
  static int? rupiah(dynamic nilai) =>
      nilai == null ? null : (nilai as num).round();

  /// Waktu dari server selalu UTC, dan selalu diubah ke waktu perangkat.
  ///
  /// Kalau tidak, jadwal "besok jam 9" akan tampil tujuh jam meleset di layar,
  /// dan yang seperti itu tidak terlihat seperti bug, cuma terlihat seperti
  /// jadwal yang salah.
  static DateTime? waktu(Map<String, dynamic> isi, String kunci) {
    final nilai = isi[kunci];
    if (nilai == null) return null;
    final hasil = DateTime.tryParse(nilai.toString());
    if (hasil == null) {
      throw GalatServer('Nilai $kunci bukan waktu yang bisa dibaca.');
    }
    return hasil.toLocal();
  }

  /// Membaca jawaban berhalaman: daftar barisnya, beserta jumlah seluruhnya.
  ///
  /// `total` dibaca terpisah dari panjang `isi`, dan itu seluruh gunanya bungkus ini:
  /// yang membacanya harus bisa tahu masih ada sisa atau tidak, dan panjang isi tidak
  /// pernah bisa menjawab itu.
  ///
  /// Bentuk yang salah melempar, bukan jadi halaman kosong. Daftar yang diam-diam
  /// kosong karena bentuk jawabannya berubah terbaca sebagai "belum ada order", dan
  /// itu jenis kegagalan yang tidak pernah dilaporkan siapa pun.
  static Halaman<T> halaman<T>(
    Map<String, dynamic> jawaban,
    T Function(Map<String, dynamic> baris) baca,
  ) {
    final isi = jawaban['isi'];
    final total = jawaban['total'];
    if (isi is! List || total is! int) {
      throw const GalatServer('Jawaban server bukan daftar berhalaman.');
    }

    return Halaman<T>(
      isi: [for (final baris in isi) baca(baris as Map<String, dynamic>)],
      total: total,
    );
  }

  /// Mencocokkan nama enum tanpa memperhatikan besar kecil huruf.
  ///
  /// Server menulisnya PascalCase (`AnterJemput`), Dart camelCase
  /// (`anterJemput`). Nama anggotanya sengaja dibuat sama persis di kedua sisi,
  /// jadi yang perlu diabaikan cuma huruf pertamanya.
  ///
  /// Nilai yang tidak dikenal melempar, bukan diam-diam jatuh ke nilai pertama.
  /// Status yang salah baca akan membuat layar menawarkan tombol yang tidak
  /// seharusnya ada, dan itu jauh lebih berbahaya daripada layar yang gagal muat.
  static T pilihan<T extends Enum>(
    List<T> daftar,
    dynamic nilai,
    String namaKolom,
  ) {
    final teks = nilai?.toString().toLowerCase();
    for (final kandidat in daftar) {
      if (kandidat.name.toLowerCase() == teks) return kandidat;
    }
    throw GalatServer('Nilai $namaKolom tidak dikenal: $nilai');
  }
}
