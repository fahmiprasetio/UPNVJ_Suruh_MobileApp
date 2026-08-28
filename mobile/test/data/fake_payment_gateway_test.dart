import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/core/config/tarif_config.dart';
import 'package:upnvj_suruh/data/fake/fake_payment_gateway.dart';
import 'package:upnvj_suruh/domain/enums.dart';
import 'package:upnvj_suruh/domain/models/transaksi_pembayaran.dart';

/// Membuat transaksi lalu melewati jeda jaringan tiruannya.
TransaksiPembayaran buatTransaksi(
  FakeAsync async,
  FakePaymentGateway gateway, {
  String orderId = 'o-1',
}) {
  TransaksiPembayaran? hasil;
  gateway.buatTransaksi(orderId: orderId).then((t) => hasil = t);
  async.elapse(const Duration(seconds: 1));
  return hasil!;
}

void main() {
  test('satu order tidak melahirkan QR baru tiap kali dibuka', () {
    fakeAsync((async) {
      final gateway = FakePaymentGateway();
      addTearDown(gateway.dispose);

      final pertama = buatTransaksi(async, gateway);
      final kedua = buatTransaksi(async, gateway);

      expect(kedua.id, pertama.id);
      expect(kedua.qrisPayload, pertama.qrisPayload);
    });
  });

  test('batas waktu bayar diambil dari TarifConfig', () {
    fakeAsync((async) {
      final gateway = FakePaymentGateway();
      addTearDown(gateway.dispose);

      final transaksi = buatTransaksi(async, gateway);

      expect(
        transaksi.kedaluwarsaPada.difference(transaksi.dibuatPada),
        TarifConfig.batasWaktuBayar,
      );
      expect(transaksi.status, PaymentStatus.pending);
    });
  });

  test('kabar dari gateway mengubah status jadi berhasil', () {
    fakeAsync((async) {
      final gateway = FakePaymentGateway();
      addTearDown(gateway.dispose);

      final transaksi = buatTransaksi(async, gateway);
      final diterima = <TransaksiPembayaran>[];
      gateway.watchTransaksi(transaksi.orderId).listen(diterima.add);
      async.flushMicrotasks();

      gateway.simulasikanPembayaranMasuk(transaksi.orderId);
      async.flushMicrotasks();

      expect(diterima.last.status, PaymentStatus.berhasil);
      expect(diterima.last.dibayarPada, isNotNull);
    });
  });

  test('transaksi hangus sendiri saat batas waktu lewat', () {
    fakeAsync((async) {
      final gateway = FakePaymentGateway();
      addTearDown(gateway.dispose);

      final transaksi = buatTransaksi(async, gateway);
      final diterima = <TransaksiPembayaran>[];
      gateway.watchTransaksi(transaksi.orderId).listen(diterima.add);

      async.elapse(TarifConfig.batasWaktuBayar + const Duration(minutes: 1));

      expect(diterima.last.status, PaymentStatus.kedaluwarsa);
    });
  });

  test('pembayaran yang sudah berhasil tidak dianulir pewaktu kedaluwarsa', () {
    fakeAsync((async) {
      final gateway = FakePaymentGateway();
      addTearDown(gateway.dispose);

      final transaksi = buatTransaksi(async, gateway);
      final diterima = <TransaksiPembayaran>[];
      gateway.watchTransaksi(transaksi.orderId).listen(diterima.add);

      gateway.simulasikanPembayaranMasuk(transaksi.orderId);
      async.elapse(TarifConfig.batasWaktuBayar + const Duration(minutes: 1));

      expect(diterima.last.status, PaymentStatus.berhasil);
    });
  });

  test('order yang sudah dibayar boleh punya transaksi baru untuk order lain', () {
    fakeAsync((async) {
      final gateway = FakePaymentGateway();
      addTearDown(gateway.dispose);

      final satu = buatTransaksi(async, gateway, orderId: 'o-1');
      final dua = buatTransaksi(async, gateway, orderId: 'o-2');

      expect(dua.id, isNot(satu.id));
      expect(dua.orderId, 'o-2');
    });
  });
}
