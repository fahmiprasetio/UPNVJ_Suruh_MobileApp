import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';
import 'package:upnvj_suruh/domain/order_flow.dart';

Order buatOrder({
  required ServiceType serviceType,
  required OrderStatus status,
}) {
  return Order(
    id: 'o-uji',
    kodeOrder: 'SRH-0001',
    klienId: 'u-1',
    namaKlien: 'Uji',
    serviceType: serviceType,
    status: status,
    dibuatPada: DateTime(2026, 8, 25),
  );
}

void main() {
  group('alur status', () {
    test('Jalur A melewati dua tahap pertama', () {
      final alur = alurStatus(OrderTrack.jalurA);

      expect(alur, hasLength(4));
      expect(alur.first, OrderStatus.menungguPembayaran);
      expect(alur, isNot(contains(OrderStatus.permintaan)));
      expect(alur, isNot(contains(OrderStatus.menungguPersetujuanKlien)));
    });

    test('Jalur B dimulai dari permintaan tanpa harga', () {
      final alur = alurStatus(OrderTrack.jalurB);

      // Tidak lagi enam tahap: order Jalur B tetap Permintaan selama masih
      // menerima tawaran (bisa dari beberapa runner sekaligus), lalu langsung
      // lompat ke MenungguPembayaran begitu klien menyetujui salah satunya.
      // Tidak ada tahap "menunggu persetujuan" yang benar-benar disinggahi.
      expect(alur, hasLength(5));
      expect(alur.first, OrderStatus.permintaan);
      expect(alur[1], OrderStatus.menungguPembayaran);
      expect(alur, isNot(contains(OrderStatus.menungguPersetujuanKlien)));
    });

    test('batal bukan tahap di alur mana pun', () {
      for (final track in OrderTrack.values) {
        expect(alurStatus(track), isNot(contains(OrderStatus.batal)));
      }
    });
  });

  group('posisi order di alurnya', () {
    test('tahap sebelum status sekarang dihitung sudah lewat', () {
      final order = buatOrder(
        serviceType: ServiceType.anterJemput,
        status: OrderStatus.dikerjakan,
      );

      expect(order.sudahLewat(OrderStatus.menungguPembayaran), isTrue);
      expect(order.sudahLewat(OrderStatus.mencariRunner), isTrue);
      expect(order.sudahLewat(OrderStatus.dikerjakan), isFalse);
      expect(order.sedangDi(OrderStatus.dikerjakan), isTrue);
      expect(order.sudahLewat(OrderStatus.selesai), isFalse);
    });

    test('order batal tidak dianggap sedang di tahap mana pun', () {
      final order = buatOrder(
        serviceType: ServiceType.anterJemput,
        status: OrderStatus.batal,
      );

      expect(order.dibatalkan, isTrue);
      for (final tahap in order.alur) {
        expect(order.sedangDi(tahap), isFalse);
        expect(order.sudahLewat(tahap), isFalse);
      }
    });

    test('permintaan Jalur B ada di tahap pertama, bukan di luar alur', () {
      final order = buatOrder(
        serviceType: ServiceType.bantuPindahKos,
        status: OrderStatus.permintaan,
      );

      expect(order.indeksTahap, 0);
      expect(order.sedangDi(OrderStatus.permintaan), isTrue);
    });
  });
}
