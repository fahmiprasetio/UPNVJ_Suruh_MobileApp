import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/core/realtime/order_hub_client.dart';

/// Cek pemisahan pesan Protokol Hub JSON dan pengenalan tipe Invocation.
///
/// Ini logika yang paling mudah salah tulis tanpa ketahuan: satu bingkai
/// WebSocket boleh membawa beberapa pesan sekaligus atau satu pesan yang
/// terpotong, dan salah hitung batasnya membuat pesan hilang atau tergabung
/// diam-diam, tanpa galat apa pun yang kelihatan.
void main() {
  group('pisahkanPesanHub', () {
    test('satu pesan utuh diakhiri pemisah', () {
      final hasil = pisahkanPesanHub('{"type":1}\x1e');
      expect(hasil.pesanUtuh, ['{"type":1}']);
      expect(hasil.sisa, isEmpty);
    });

    test('beberapa pesan dalam satu bingkai', () {
      final hasil = pisahkanPesanHub('{"type":1}\x1e{"type":6}\x1e');
      expect(hasil.pesanUtuh, ['{"type":1}', '{"type":6}']);
      expect(hasil.sisa, isEmpty);
    });

    test('pesan yang belum lengkap tertinggal di sisa', () {
      final hasil = pisahkanPesanHub('{"type":1}\x1e{"type"');
      expect(hasil.pesanUtuh, ['{"type":1}']);
      expect(hasil.sisa, '{"type"');
    });

    test('bingkai kosong (dua pemisah berurutan) diabaikan', () {
      final hasil = pisahkanPesanHub('\x1e\x1e{"type":1}\x1e');
      expect(hasil.pesanUtuh, ['{"type":1}']);
    });

    test('balasan jabat tangan sukses ("{}") tetap dianggap satu pesan', () {
      // Bukan bagian pisahkanPesanHub untuk tahu isinya bermakna atau tidak,
      // itu tugas apakahPesanInvocation. Diuji terpisah di bawah.
      final hasil = pisahkanPesanHub('{}\x1e{"type":1}\x1e');
      expect(hasil.pesanUtuh, ['{}', '{"type":1}']);
    });

    test('bufer kosong tidak menghasilkan apa-apa', () {
      final hasil = pisahkanPesanHub('');
      expect(hasil.pesanUtuh, isEmpty);
      expect(hasil.sisa, isEmpty);
    });
  });

  group('apakahPesanInvocation', () {
    test('tipe 1 adalah invocation', () {
      expect(apakahPesanInvocation('{"type":1,"target":"OrderBroadcast"}'), isTrue);
    });

    test('tipe 6 (ping) bukan invocation', () {
      expect(apakahPesanInvocation('{"type":6}'), isFalse);
    });

    test('balasan jabat tangan sukses ("{}", tanpa "type") bukan invocation', () {
      expect(apakahPesanInvocation('{}'), isFalse);
    });

    test('pesan yang bukan JSON tidak melempar galat', () {
      expect(apakahPesanInvocation('bukan json'), isFalse);
    });

    test('pesan berbentuk larik, bukan objek, tidak melempar galat', () {
      expect(apakahPesanInvocation('[1,2,3]'), isFalse);
    });
  });
}
