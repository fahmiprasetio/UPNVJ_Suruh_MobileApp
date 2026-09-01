import 'enums.dart';
import 'models/order.dart';

/// Urutan status yang dilewati sebuah order, per jalur layanan.
///
/// Jalur A melewati dua tahap pertama karena harganya sudah pasti sejak
/// awal. Jalur B tidak lagi melewati [OrderStatus.menungguPersetujuanKlien]:
/// order tetap berstatus [OrderStatus.permintaan] selama masih menerima
/// tawaran dari runner mana pun (bisa lebih dari satu tawaran sekaligus),
/// dan langsung lompat ke [OrderStatus.menungguPembayaran] begitu klien
/// menyetujui salah satunya, tanpa ada tahap "menunggu persetujuan" yang
/// benar-benar disinggahi. Status itu dibiarkan ada di enumnya (lihat
/// `Domain.OrderStatus` di backend) supaya nilainya tidak bergeser, tapi
/// tidak dipakai di sini karena tidak pernah benar-benar terjadi lagi.
///
/// [OrderStatus.batal] sengaja tidak ada di daftar mana pun: pembatalan bukan
/// tahap yang dilalui, melainkan keluar dari alur.
const List<OrderStatus> _alurJalurA = [
  OrderStatus.menungguPembayaran,
  OrderStatus.mencariRunner,
  OrderStatus.dikerjakan,
  OrderStatus.selesai,
];

const List<OrderStatus> _alurJalurB = [
  OrderStatus.permintaan,
  OrderStatus.menungguPembayaran,
  OrderStatus.mencariRunner,
  OrderStatus.dikerjakan,
  OrderStatus.selesai,
];

List<OrderStatus> alurStatus(OrderTrack track) =>
    track == OrderTrack.jalurA ? _alurJalurA : _alurJalurB;

extension OrderAlur on Order {
  List<OrderStatus> get alur => alurStatus(track);

  /// Posisi status sekarang di dalam alur, atau `-1` kalau order batal.
  int get indeksTahap => alur.indexOf(status);

  bool get dibatalkan => status == OrderStatus.batal;

  bool sudahLewat(OrderStatus tahap) {
    if (dibatalkan) return false;
    return alur.indexOf(tahap) < indeksTahap;
  }

  bool sedangDi(OrderStatus tahap) => !dibatalkan && status == tahap;
}
