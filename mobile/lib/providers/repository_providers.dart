import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fake/fake_auth_repository.dart';
import '../data/fake/fake_foto_bukti_repository.dart';
import '../data/fake/fake_order_repository.dart';
import '../data/fake/seed_data.dart';
import '../domain/models/app_user.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/foto_bukti_repository.dart';
import '../domain/repositories/order_repository.dart';

/// Benar hanya di build debug.
///
/// Dibuat sebagai provider, bukan `kDebugMode` yang dibaca langsung di tiap
/// tempat, supaya tes bisa memaksanya `false` dan membuktikan alat penguji
/// benar-benar hilang di rilis. Tes selalu berjalan di mode debug, jadi tanpa
/// seam ini perilaku rilisnya mustahil diuji dan cuma bisa dipercaya.
final modeDebugProvider = Provider<bool>((ref) => kDebugMode);

/// Titik tukar backend.
///
/// Seluruh aplikasi mengambil repository lewat provider ini. Ketika kelompok
/// mengunci pilihan stack (rencana capstone bagian 14.4), yang berubah cuma
/// baris `return` di bawah, atau di test cukup `overrideWith`. Tidak ada
/// layar yang perlu disentuh.
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final repo = FakeOrderRepository(
    // Kontraknya tidak lagi menerima identitas pemanggil, jadi tiruannya perlu
    // cara lain mengetahuinya. Dibaca dari repository auth, bukan dari
    // `userAktifProvider`: provider itu beraliran dan otomatis dibuang saat tidak
    // ada yang mengawasinya, sementara `userAktif` adalah getter serentak yang
    // selalu menjawab keadaan sekarang.
    pemanggil: () => ref.read(authRepositoryProvider).userAktif?.id ?? '',
  );
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

/// Tiruan repository, kalau panel penawaran admin masih boleh dipakai.
///
/// Mengembalikan repositorynya sendiri, bukan sekadar penanda benar atau salah,
/// karena `buatPenawaran` sengaja bukan bagian dari kontrak `OrderRepository`:
/// menawar adalah pekerjaan admin, dan aplikasi ini tidak punya permukaan admin.
/// Panel alat penguji memanggil tiruannya langsung, dan begitu backend sungguhan
/// terpasang penyedianya mengembalikan `null` sehingga panelnya hilang sendiri.
///
/// Dashboard admin sungguhan tinggal di web (bagian 14.2), jadi bagi aplikasi
/// ini penawaran adalah kabar dari luar. Selama repository masih tiruan, panel
/// alat penguji berdiri di tempat dashboard itu; begitu backend sungguhan
/// dipasang, panelnya hilang sendiri tanpa ada layar yang perlu diubah.
///
/// Mode build ikut menjaga, dan itu bukan pengulangan. Selama backend belum
/// tersambung repositorynya memang masih tiruan, jadi penjagaan tipe saja
/// membuat build rilis hari ini tetap membawa panel ini.
final simulatorPenawaranProvider = Provider<FakeOrderRepository?>((ref) {
  if (!ref.watch(modeDebugProvider)) return null;
  final repo = ref.watch(orderRepositoryProvider);
  return repo is FakeOrderRepository ? repo : null;
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
  if (!ref.watch(modeDebugProvider)) return null;
  final repo = ref.watch(authRepositoryProvider);
  return repo is FakeAuthRepository ? SeedData.semuaUser : null;
});

/// Cara alat penguji memakai satu akun contoh, tanpa melewati alur kode.
///
/// Sengaja terpisah dari `masuk`, yang bentuknya harus tetap sama dengan server.
/// Alat penguji yang menumpang di alur sungguhan akan pelan-pelan membengkokkannya,
/// dan yang paling mungkin dibengkokkan adalah bagian yang menyusahkan saat menguji,
/// yaitu justru pemeriksaannya.
final pengalihAkunProvider = Provider<void Function(AppUser)?>((ref) {
  if (!ref.watch(modeDebugProvider)) return null;
  final repo = ref.watch(authRepositoryProvider);
  return repo is FakeAuthRepository ? repo.pakaiAkunUji : null;
});
