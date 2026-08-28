import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/data/fake/seed_data.dart';
import 'package:upnvj_suruh/domain/models/order.dart';

/// [Order.jumlahPesan] terpisah dari [Order.messages] karena daftar order tidak
/// membawa isi percakapannya. Di data contoh keduanya ada sekaligus, jadi keduanya
/// bisa berselisih, dan selisihnya cuma tampak sebagai angka yang salah di kartu
/// order, bukan sebagai galat. Tes ini yang menangkapnya.
void main() {
  test('data contoh: jumlah pesan cocok dengan isi percakapannya', () {
    for (final order in SeedData.orderAwal()) {
      expect(
        order.jumlahPesan,
        order.messages.length,
        reason: 'Order ${order.kodeOrder} menyebut ${order.jumlahPesan} pesan '
            'tapi memuat ${order.messages.length}',
      );
    }
  });

  test('menambah pesan ikut menaikkan jumlahnya', () {
    final order = SeedData.orderAwal().firstWhere((o) => o.messages.isNotEmpty);

    final sesudah = order.copyWith(messages: [...order.messages, order.messages.first]);

    expect(sesudah.jumlahPesan, order.messages.length + 1);
  });

  test('mengubah hal lain tidak menyentuh jumlah pesannya', () {
    // Angka dari server harus bertahan lewat copyWith yang tidak menyangkut chat,
    // kalau tidak ia akan tereset jadi nol setiap kali status order berubah.
    final order = SeedData.orderAwal().firstWhere((o) => o.messages.isNotEmpty);

    final sesudah = order.copyWith(harga: 12345);

    expect(sesudah.jumlahPesan, order.jumlahPesan);
  });
}
