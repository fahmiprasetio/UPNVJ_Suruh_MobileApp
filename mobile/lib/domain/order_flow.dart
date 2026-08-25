import 'enums.dart';
import 'models/order.dart';

/// Urutan status yang dilewati sebuah order, per jalur layanan.
///
/// Cerminan state machine di rencana capstone bagian 4. Jalur A melewati dua
/// status pertama karena harganya sudah pasti sejak awal.
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
  OrderStatus.menungguPersetujuanKlien,
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
