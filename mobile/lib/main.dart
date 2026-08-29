import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/api/sesi_token.dart';
import 'providers/pembuka_providers.dart';
import 'providers/repository_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Wajib sebelum memakai DateFormat dengan locale id_ID.
  await initializeDateFormatting('id_ID');

  // Token dimuat sebelum aplikasi digambar, bukan sesudah. Kalau urutannya terbalik,
  // permintaan pertama tiap layar terbang tanpa token dan dijawab 401, lalu pengguna
  // yang sebenarnya masih punya sesi terlempar ke layar masuk sekali setiap membuka
  // aplikasi. Ini pembacaan penyimpanan lokal, bukan panggilan jaringan, jadi
  // tetap ditunggu di sini: tidak pernah lambat.
  final sesi = SesiToken();
  await sesi.muat();

  final wadah = ProviderContainer(
    overrides: [sesiTokenProvider.overrideWithValue(sesi)],
  );

  // Dipicu sekarang, bukan ditunggu. Tanya-ke-server siapa pemilik tokennya
  // adalah panggilan jaringan, dan layar pembuka sendiri yang menunggunya
  // sambil memainkan animasinya, lewat [kesiapanSesiProvider]. `main` cuma
  // menyalakan pemicunya lebih awal supaya panggilannya sudah berjalan
  // sebelum bingkai pertama digambar, bukan baru dimulai setelah lencananya
  // muncul.
  wadah.read(kesiapanSesiProvider);

  runApp(
    UncontrolledProviderScope(container: wadah, child: const UpnvjSuruhApp()),
  );
}
