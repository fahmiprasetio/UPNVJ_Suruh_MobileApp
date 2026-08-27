import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/enums.dart';
import 'repository_providers.dart';

/// Peran yang sedang dipakai user, bukan seluruh peran yang ia punya.
///
/// Satu orang boleh memegang beberapa peran sekaligus (bagian 14.2), tapi pada
/// satu waktu ia cuma sedang mengerjakan satu hal: memesan, atau mengambil
/// order. Nilai inilah yang menentukan permukaan mana yang terbuka, jadi
/// pertanyaan "aplikasi ini sedang melayani siapa" punya satu jawaban di satu
/// tempat, bukan tersebar sebagai `if` di banyak layar.
///
/// Nilainya lahir ulang setiap kali user yang masuk berganti, karena [build]
/// mengamati [userAktifProvider]. Tanpa itu, mode runner milik akun sebelumnya
/// akan terbawa ke akun berikutnya yang bahkan bukan runner.
class PeranAktif extends Notifier<UserRole?> {
  @override
  UserRole? build() {
    return ref.watch(userAktifProvider).value?.peranBawaan;
  }

  /// Menukar permukaan. Peran yang tidak dimiliki user ditolak di sini, bukan
  /// dipercayakan pada layar yang memanggilnya.
  void ganti(UserRole peran) {
    final user = ref.read(userAktifProvider).value;
    if (user == null || !user.peranMobile.contains(peran)) return;
    state = peran;
  }
}

final peranAktifProvider = NotifierProvider<PeranAktif, UserRole?>(
  PeranAktif.new,
);
