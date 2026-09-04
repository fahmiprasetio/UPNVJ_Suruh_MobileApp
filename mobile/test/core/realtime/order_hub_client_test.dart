import 'dart:convert';

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

  group('bentukInvocation', () {
    test('menyusun type 1 beserta target dan argumen', () {
      final pesan = bentukInvocation('GabungOrder', ['abc-123']);

      expect(pesan, endsWith('\x1e'));
      expect(apakahPesanInvocation(pesan.substring(0, pesan.length - 1)), isTrue);

      final terpisah = pisahkanPesanHub(pesan);
      expect(terpisah.pesanUtuh, hasLength(1));
      final isi = jsonDecode(terpisah.pesanUtuh.single) as Map<String, dynamic>;
      expect(isi['type'], 1);
      expect(isi['target'], 'GabungOrder');
      expect(isi['arguments'], ['abc-123']);
    });

    test('tidak menyertakan invocationId', () {
      // Server tidak diminta membalas; menyertakan id yang tidak pernah dipakai
      // siapa pun cuma menambah bidang yang bisa disalahpahami sebagai sesuatu
      // yang harus dijaga.
      final isi =
          jsonDecode(bentukInvocation('TinggalkanOrder', ['x']).replaceAll('\x1e', ''))
              as Map<String, dynamic>;
      expect(isi.containsKey('invocationId'), isFalse);
    });

    test('argumen kosong menghasilkan larik kosong, bukan hilang', () {
      final isi =
          jsonDecode(bentukInvocation('Sesuatu', []).replaceAll('\x1e', ''))
              as Map<String, dynamic>;
      expect(isi['arguments'], isEmpty);
    });
  });
}
