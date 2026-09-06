import '../../domain/models/tarif.dart';

/// Membaca isian jarak, menerima koma maupun titik sebagai pemisah desimal.
///
/// Orang Indonesia mengetik "2,5" sedangkan [double.tryParse] menuntut "2.5".
/// `null` untuk isian yang kosong, bukan angka, atau nol/negatif -- jarak nol
/// tidak masuk akal untuk anter jemput maupun jastip barang.
double? bacaJarak(String teks) {
  final angka = double.tryParse(teks.trim().replaceAll(',', '.'));
  if (angka == null || angka <= 0) return null;
  return angka;
}

/// Kebalikan [bacaJarak]: menulis jarak kembali ke bentuk yang diketik orang.
///
/// Dipakai "Pesan lagi" untuk mengisi ulang kolom jarak dari order lama. Hasilnya
/// wajib bisa dibaca [bacaJarak] lagi, jadi pemisah desimalnya koma, sama seperti
/// yang dicontohkan [validasiJarak] di pesan galatnya sendiri.
///
/// Bilangan bulat ditulis tanpa ekor ",0": "3 km", bukan "3,0 km".
String tulisJarak(double? jarak) {
  if (jarak == null) return '';
  if (jarak == jarak.roundToDouble()) return jarak.round().toString();
  return jarak.toString().replaceAll('.', ',');
}

/// Validator kolom jarak untuk Anter Jemput dan Jastip Barang.
///
/// Keduanya memakai batas jarak yang sama, [Tarif.anjemJarakMaksimalKm] --
/// tidak ada batas terpisah untuk Jastip Barang di [Tarif], jadi ini bukan
/// kekeliruan menyalin nama field, melainkan keadaan yang sudah begitu sejak
/// tarifnya dirancang.
String? validasiJarak(String? nilai, Tarif tarif) {
  final bersih = nilai?.trim() ?? '';
  if (bersih.isEmpty) return 'Perkiraan jarak wajib diisi';
  final jarak = bacaJarak(bersih);
  if (jarak == null) return 'Isi dengan angka, misalnya 2,5';
  if (jarak > tarif.anjemJarakMaksimalKm) {
    return 'Di atas ${tarif.anjemJarakMaksimalKm.round()} km belum '
        'dilayani, pakai Permintaan Lain';
  }
  return null;
}
