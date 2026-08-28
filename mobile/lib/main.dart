import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/api/sesi_token.dart';
import 'providers/repository_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Wajib sebelum memakai DateFormat dengan locale id_ID.
  await initializeDateFormatting('id_ID');

  // Token dimuat sebelum aplikasi digambar, bukan sesudah. Kalau urutannya
  // terbalik, permintaan pertama tiap layar terbang tanpa token dan dijawab 401,
  // lalu pengguna yang sebenarnya masih punya sesi terlempar ke layar masuk
  // sekali setiap membuka aplikasi. Sekarang belum ada yang tersimpan, jadi
  // pemanggilan ini belum mengubah apa pun; tempatnya yang sudah benar duluan.
  final sesi = SesiToken();
  await sesi.muat();

  runApp(
    ProviderScope(
      overrides: [sesiTokenProvider.overrideWithValue(sesi)],
      child: const UpnvjSuruhApp(),
    ),
  );
}
