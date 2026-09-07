import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/notifikasi/konfigurasi_firebase.dart';
import 'data/api/sesi_token.dart';
import 'providers/pembuka_providers.dart';
import 'providers/repository_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Wajib sebelum memakai DateFormat dengan locale id_ID.
  await initializeDateFormatting('id_ID');

  // Dilewati sepenuhnya kalau identitas proyeknya tidak diisi saat build. Aplikasi tetap
  // berjalan utuh tanpa Firebase, cuma tanpa notifikasi push, dan itu memang keadaan yang
  // berlaku di CI dan di mesin siapa pun yang belum punya proyek Firebase.
  //
  // Kegagalannya ditelan, bukan dibiarkan menjatuhkan aplikasi: notifikasi yang tidak
  // menyala adalah kehilangan, sedangkan aplikasi yang tidak mau terbuka adalah kegagalan
  // total, dan keduanya tidak sebanding.
  if (KonfigurasiFirebase.lengkap) {
    try {
      await Firebase.initializeApp(options: KonfigurasiFirebase.opsi);
    } catch (_) {
      // Sengaja diam.
    }
  }

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

  // Dibaca sekarang supaya providernya sungguh dibuat: ia tidak punya pembaca lain, dan
  // provider Riverpod yang tidak pernah dibaca tidak pernah berjalan. Ia sendiri tidak
  // melakukan apa-apa sampai ada yang masuk (lihat [notifikasiPushProvider]).
  wadah.read(notifikasiPushProvider);

  runApp(
    UncontrolledProviderScope(container: wadah, child: const UpnvjSuruhApp()),
  );
}
