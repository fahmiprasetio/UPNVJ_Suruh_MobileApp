import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fake/fake_auth_repository.dart';
import '../data/fake/fake_foto_bukti_repository.dart';
import '../data/fake/fake_order_repository.dart';
import '../data/fake/seed_data.dart';
import '../domain/models/app_user.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/foto_bukti_repository.dart';
import '../domain/repositories/order_repository.dart';

/// Titik tukar backend.
///
/// Seluruh aplikasi mengambil repository lewat provider ini. Ketika kelompok
/// mengunci pilihan stack (rencana capstone bagian 14.4), yang berubah cuma
/// baris `return` di bawah, atau di test cukup `overrideWith`. Tidak ada
/// layar yang perlu disentuh.
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final repo = FakeOrderRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repo = FakeAuthRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// Kamera + penyimpanan foto bukti. Ikut menunggu pilihan stack (bagian 14.4).
final fotoBuktiRepositoryProvider = Provider<FotoBuktiRepository>((ref) {
  return FakeFotoBuktiRepository();
});

/// Penanda bahwa foto bukti masih tiruan, dipakai layar untuk mengaku terus
/// terang. Ikut hilang begitu kamera dan penyimpanan sungguhan dipasang.
final fotoBuktiTiruanProvider = Provider<bool>((ref) {
  return ref.watch(fotoBuktiRepositoryProvider) is FakeFotoBuktiRepository;
});

/// Penanda bahwa penawaran admin masih datang dari alat penguji.
///
/// Dashboard admin sungguhan tinggal di web (bagian 14.2), jadi bagi aplikasi
/// ini penawaran adalah kabar dari luar. Selama repository masih tiruan, panel
/// alat penguji berdiri di tempat dashboard itu; begitu backend sungguhan
/// dipasang, panelnya hilang sendiri tanpa ada layar yang perlu diubah.
final simulatorPenawaranProvider = Provider<bool>((ref) {
  return ref.watch(orderRepositoryProvider) is FakeOrderRepository;
});

/// User yang sedang masuk, `null` kalau belum.
final userAktifProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).watchUserAktif();
});

/// Versi tanpa pembungkus [AsyncValue] untuk layar yang sudah dipastikan
/// berada di balik gerbang login.
final userWajibProvider = Provider<AppUser>((ref) {
  final user = ref.watch(userAktifProvider).value;
  if (user == null) {
    throw StateError('Layar ini butuh user yang sudah masuk');
  }
  return user;
});

/// Daftar akun contoh untuk alat penguji ganti akun.
///
/// Mengembalikan `null` begitu autentikasi sungguhan dipasang, sehingga tombol
/// ganti akun hilang sendiri, alat penguji tidak ikut terbawa ke tangan
/// pengguna. Pola yang sama dipakai panel simulator pembayaran.
final akunUjiProvider = Provider<List<AppUser>?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo is FakeAuthRepository ? SeedData.semuaUser : null;
});
