import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/features/klien/beranda/widgets/maskot_melambai.dart';

// PNG transparan 1x1, cuma supaya Image punya sesuatu yang valid buat
// di-decode. Isinya tidak penting -- yang diuji cuma mekanisme ganti frame
// dan pembersihan timer, bukan tampilan gambarnya.
const _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

void main() {
  testWidgets(
    'sprite jalan sampai frame terakhir lalu balik diam, timer beres saat dibuang',
    (tester) async {
      final spriteSheet = MemoryImage(base64Decode(_png1x1));

      await tester.pumpWidget(
        MaterialApp(
          home: MaskotMelambai(
            spriteSheet: spriteSheet,
            jumlahFrame: 15,
            fps: 6,
            jedaMelambai: const Duration(milliseconds: 20),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(); // biar ImageStreamListener sempat memuat gambarnya

      await tester.pump(const Duration(milliseconds: 20)); // jeda diam lewat
      // 15 frame @ 6fps sekitar 2.5 detik: lewati sampai kelar satu putaran
      // penuh plus jeda berikutnya, jangan sampai timer masih menyala.
      await tester.pump(const Duration(seconds: 3));

      // Buang widgetnya sebelum tes selesai supaya semua Timer ikut mati;
      // kalau dispose() lupa membatalkan salah satunya, flutter_test menolak
      // tes ini karena ada timer yang nyangkut.
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
