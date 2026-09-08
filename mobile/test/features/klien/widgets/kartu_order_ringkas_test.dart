import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/order.dart';
import 'package:upnvj_suruh/features/klien/widgets/kartu_order_ringkas.dart';

/// Lencana "pesan belum dibaca" di kartu riwayat order.
///
/// Sebelum ini kartunya tidak pernah menyebut chat sama sekali -- klien tidak
/// tahu ada percakapan baru sampai ia membuka satu per satu order lamanya.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Order buatOrder({int jumlahPesanBelumDibaca = 0}) => Order(
    id: 'o-1',
    kodeOrder: 'SRH-0001',
    klienId: 'k-1',
    namaKlien: 'Dina',
    serviceType: ServiceType.anterJemput,
    status: OrderStatus.dikerjakan,
    dibuatPada: DateTime(2026, 1, 1),
    jumlahPesanBelumDibaca: jumlahPesanBelumDibaca,
  );

  Future<void> pump(WidgetTester tester, Order order) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: KartuOrderRingkas(order: order, onTap: () {})),
    ),
  );

  testWidgets('menampilkan lencana jumlah pesan belum dibaca kalau ada', (
    tester,
  ) async {
    await pump(tester, buatOrder(jumlahPesanBelumDibaca: 3));

    expect(find.byType(Badge), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('3')),
      findsOneWidget,
    );
  });

  testWidgets('tidak menampilkan lencana kalau semua sudah dibaca', (
    tester,
  ) async {
    await pump(tester, buatOrder());

    expect(find.byType(Badge), findsNothing);
  });
}
