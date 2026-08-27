import 'package:intl/intl.dart';

final NumberFormat _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

final DateFormat _tanggalJam = DateFormat('d MMM yyyy, HH:mm', 'id_ID');
final DateFormat _jam = DateFormat('HH:mm', 'id_ID');
final DateFormat _jadwal = DateFormat("EEEE, d MMMM yyyy 'pukul' HH:mm", 'id_ID');

/// `30000` -> `Rp 30.000`. Nilai `null` ditampilkan sebagai tanda hubung
/// karena harga Jalur B memang belum ada sebelum penawaran disepakati.
String formatRupiah(int? nilai) => nilai == null ? '-' : _rupiah.format(nilai);

String formatTanggalJam(DateTime waktu) => _tanggalJam.format(waktu.toLocal());

String formatJam(DateTime waktu) => _jam.format(waktu.toLocal());

/// Jadwal pekerjaan, ditulis panjang lengkap dengan nama harinya.
///
/// Sengaja tidak disingkat: salah membaca jadwal berarti runner datang di hari
/// yang salah, dan "Sabtu" jauh lebih sulit disalahpahami daripada "30/08".
String formatJadwal(DateTime waktu) => _jadwal.format(waktu.toLocal());

/// `Duration(hours: 2, minutes: 30)` -> `2 jam 30 menit`.
String formatDurasi(Duration durasi) {
  final jam = durasi.inHours;
  final menit = durasi.inMinutes.remainder(60);
  if (jam == 0) return '$menit menit';
  if (menit == 0) return '$jam jam';
  return '$jam jam $menit menit';
}

/// Selisih waktu dalam bahasa sehari-hari, untuk daftar order.
String formatWaktuRelatif(DateTime waktu, {DateTime? sekarang}) {
  final selisih = (sekarang ?? DateTime.now()).difference(waktu);
  if (selisih.inMinutes < 1) return 'baru saja';
  if (selisih.inMinutes < 60) return '${selisih.inMinutes} menit lalu';
  if (selisih.inHours < 24) return '${selisih.inHours} jam lalu';
  if (selisih.inDays < 7) return '${selisih.inDays} hari lalu';
  return formatTanggalJam(waktu);
}
