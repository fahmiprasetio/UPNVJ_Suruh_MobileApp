import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/preferensi_tema.dart';

/// Ditimpa di [main] dengan yang sudah selesai memuat pilihan tersimpan.
/// Tanpa penimpaan itu nilainya selalu bawaan, dan pilihan yang pernah dibuat
/// pengguna hilang tiap kali aplikasi dibuka.
final preferensiTemaProvider = Provider<PreferensiTema>(
  (ref) => PreferensiTema(),
);

/// Tema yang sedang dipakai, dan satu-satunya tempat yang boleh menggantinya.
class ModeTema extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(preferensiTemaProvider).mode;

  void pilih(ThemeMode mode) {
    state = mode;
    // Tidak ditunggu: yang dilihat pengguna adalah [state] yang sudah berubah,
    // dan penulisan ke penyimpanan cuma menentukan apa yang terbaca besok.
    ref.read(preferensiTemaProvider).simpan(mode);
  }
}

final modeTemaProvider = NotifierProvider<ModeTema, ThemeMode>(ModeTema.new);
