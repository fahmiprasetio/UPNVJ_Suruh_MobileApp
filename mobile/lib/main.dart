import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/api/api_auth_repository.dart';
import 'data/api/sesi_token.dart';
import 'providers/repository_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Wajib sebelum memakai DateFormat dengan locale id_ID.
  await initializeDateFormatting('id_ID');

  // Token dimuat sebelum aplikasi digambar, bukan sesudah. Kalau urutannya terbalik,
  // permintaan pertama tiap layar terbang tanpa token dan dijawab 401, lalu pengguna
  // yang sebenarnya masih punya sesi terlempar ke layar masuk sekali setiap membuka
  // aplikasi.
  final sesi = SesiToken();
  await sesi.muat();

  final wadah = ProviderContainer(
    overrides: [sesiTokenProvider.overrideWithValue(sesi)],
  );

  // Token saja tidak cukup: aplikasi juga harus tahu itu milik siapa sebelum layar
  // pertama digambar, karena yang menentukan layar mana yang dibuka adalah ada atau
  // tidaknya sesi. Menanyakannya setelah aplikasi tergambar membuat pemilik sesi yang
  // sah melihat kedipan layar masuk setiap kali membuka aplikasi.
  final auth = wadah.read(authRepositoryProvider);
  if (auth is ApiAuthRepository) {
    await auth.pulihkanSesi();
  }

  runApp(
    UncontrolledProviderScope(container: wadah, child: const UpnvjSuruhApp()),
  );
}
