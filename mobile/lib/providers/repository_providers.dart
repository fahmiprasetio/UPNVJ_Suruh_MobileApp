import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/klien_api.dart';
import '../core/api/konfigurasi_api.dart';
import '../core/config/sumber_data.dart';
import '../core/realtime/order_hub_client.dart';
import '../data/api/api_auth_repository.dart';
import '../data/api/api_foto_bukti_repository.dart';
import '../data/api/api_order_repository.dart';
import '../data/api/api_tarif_repository.dart';
import '../data/api/sesi_token.dart';
import '../data/fake/fake_auth_repository.dart';
import '../data/fake/fake_foto_bukti_repository.dart';
import '../data/fake/fake_order_repository.dart';
import '../data/fake/fake_tarif_repository.dart';
import '../data/fake/seed_data.dart';
import '../domain/models/app_user.dart';
import '../domain/models/tarif.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/foto_bukti_repository.dart';
import '../domain/repositories/order_repository.dart';
import '../domain/repositories/tarif_repository.dart';

/// Benar hanya di build debug.
///
/// Dibuat sebagai provider, bukan `kDebugMode` yang dibaca langsung di tiap
/// tempat, supaya tes bisa memaksanya `false` dan membuktikan alat penguji
/// benar-benar hilang di rilis. Tes selalu berjalan di mode debug, jadi tanpa
/// seam ini perilaku rilisnya mustahil diuji dan cuma bisa dipercaya.
final modeDebugProvider = Provider<bool>((ref) => kDebugMode);

/// Sumber data yang sedang dipakai, dibaca dari saklar build.
///
/// Bawaannya [SumberData.api]: sejak sesi ini, aplikasi yang dijalankan tanpa
/// saklar apa pun bicara ke backend sungguhan. Tes yang butuh data karangan
/// menimpanya dengan [SumberData.tiruan] secara terang-terangan, sehingga dari
/// berkas tesnya sendiri kelihatan bahwa ia tidak sedang menguji jalur API.
final sumberDataProvider = Provider<SumberData>((ref) {
  return KonfigurasiSumberData.baca(modeDebug: ref.watch(modeDebugProvider));
});

/// Token sesi yang dibawa setiap permintaan.
///
/// Satu untuk seluruh aplikasi, karena yang menulisnya (repository auth) dan yang
/// membacanya (klien HTTP) adalah dua benda berbeda yang harus melihat nilai yang
/// sama. Isinya masih hidup di memori proses; [SesiToken] sudah berbentuk siap
/// menerima penyimpanan aman, dan [main] sudah memanggil `muat()` di tempat yang
/// benar sebelum penyimpanannya ada.
final sesiTokenProvider = Provider<SesiToken>((ref) => SesiToken());

/// Satu-satunya klien HTTP aplikasi.
///
/// Tokennya diberikan sebagai fungsi, bukan nilai, supaya permintaan berikutnya
/// selalu membaca token yang berlaku sekarang. Klien yang menyalin tokennya sekali
/// saat dibuat akan terus memakai token lama setelah pengguna keluar lalu masuk
/// sebagai akun lain tanpa aplikasi dimulai ulang.
/// Alamat backend yang dipakai, sekaligus tempat penolakannya terjadi.
///
/// Dibaca lewat provider, bukan langsung dari konstantanya, dengan alasan yang sama
/// seperti [sumberDataProvider]: penolakannya jadi bisa dibuktikan tes, dan ia
/// terjadi sekali di satu tempat alih-alih di setiap pemanggil.
final alamatApiProvider = Provider<String>((ref) {
  return KonfigurasiApi.baca(modeDebug: ref.watch(modeDebugProvider));
});

final klienApiProvider = Provider<KlienApi>((ref) {
  final klien = KlienApi(
    baseUrl: ref.watch(alamatApiProvider),
    token: () => ref.read(sesiTokenProvider).nilai,
  );
  ref.onDispose(klien.dispose);
  return klien;
});

/// Titik tukar backend untuk tarif Jalur A.
final tarifRepositoryProvider = Provider<TarifRepository>((ref) {
  if (ref.watch(sumberDataProvider) == SumberData.tiruan) {
    return FakeTarifRepository();
  }
  return ApiTarifRepository(klien: ref.watch(klienApiProvider));
});

/// Tarif yang sedang berlaku, diambil sekali dan disimpan Riverpod selama
/// providernya masih diawasi.
///
/// Bukan `StreamProvider` yang diambil ulang berkala seperti daftar order:
/// tarif jarang berubah, dan form isian harga menghitung ulang setiap
/// ketikan. Kalau admin mengubah tarif lewat dashboard web, klien yang
/// sedang membuka form akan tetap melihat angka lama sampai formnya dibuka
/// ulang (`FutureProvider` diambil ulang setiap providernya dipasang lagi,
/// misalnya saat kembali ke layar ini). Itu batas yang sengaja diterima:
/// mengejar perubahan tarif secara langsung berarti menambah jalur realtime
/// lagi untuk sesuatu yang berubahnya jarang sekali.
final tarifProvider = FutureProvider<Tarif>((ref) {
  return ref.watch(tarifRepositoryProvider).ambilTarif();
});

/// Titik tukar backend untuk order.
///
/// Cabang tiruannya menyambungkan identitas pemanggil lewat callback, karena
/// kontraknya sengaja tidak lagi punya parameter untuk itu (bagian 29.3). Dibaca
/// dari `authRepository.userAktif`, bukan dari `userAktifProvider`: provider itu
/// beraliran dan otomatis dibuang saat tidak ada yang mengawasinya, sementara
/// `userAktif` adalah getter serentak yang selalu menjawab keadaan sekarang.
/// Koneksi SignalR ke `OrderHub`, dipakai [orderRepositoryProvider] sebagai
/// jaring penyegar tambahan (lihat [OrderHubClient] dan bagian "Bagaimana
/// aliran dibuat" di [ApiOrderRepository]).
///
/// `null` di jalur tiruan, alat penguji tidak punya server untuk disambungi.
///
/// Hub-nya mensyaratkan `[Authorize]` di seluruh permukaannya, jadi koneksinya
/// mengikuti status masuk, bukan disambungkan sekali saat aplikasi dibuka:
/// [mulai] dipanggil ulang tiap kali [userAktifProvider] berpindah dari kosong
/// ke terisi (baru masuk, atau sesi lama pulih), dan [berhenti] dipanggil saat
/// berpindah ke kosong (keluar), supaya koneksi lama tidak terus menerima
/// siaran dengan identitas akun yang sudah ditinggalkan.
final orderHubClientProvider = Provider<OrderHubClient?>((ref) {
  if (ref.watch(sumberDataProvider) == SumberData.tiruan) return null;

  final client = OrderHubClient(
    baseUrl: ref.watch(alamatApiProvider),
    token: () => ref.read(sesiTokenProvider).nilai,
  );
  ref.onDispose(client.dispose);

  ref.listen(userAktifProvider, (_, sekarang) {
    if (sekarang.value != null) {
      client.mulai();
    } else {
      client.berhenti();
    }
  }, fireImmediately: true);

  return client;
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  if (ref.watch(sumberDataProvider) == SumberData.tiruan) {
    final repo = FakeOrderRepository(
      pemanggil: () => ref.read(authRepositoryProvider).userAktif?.id ?? '',
    );
    ref.onDispose(repo.dispose);
    return repo;
  }

  final repo = ApiOrderRepository(
    klien: ref.watch(klienApiProvider),
    perubahanLuar: ref.watch(orderHubClientProvider)?.perubahan,
  );
  ref.onDispose(repo.dispose);
  return repo;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (ref.watch(sumberDataProvider) == SumberData.tiruan) {
    final repo = FakeAuthRepository();
    ref.onDispose(repo.dispose);
    return repo;
  }

  final repo = ApiAuthRepository(
    klien: ref.watch(klienApiProvider),
    sesi: ref.watch(sesiTokenProvider),
  );
  ref.onDispose(repo.dispose);
  return repo;
});

/// Kamera + penyimpanan foto bukti.
///
/// Ikut saklar sumber data seperti dua repository lainnya. Di jalur API, kamera
/// perangkat yang dibuka dan hasilnya diunggah ke server; di jalur tiruan, tidak ada
/// kamera sama sekali, karena tes layar dan demo tanpa server tidak bisa memotret.
final fotoBuktiRepositoryProvider = Provider<FotoBuktiRepository>((ref) {
  if (ref.watch(sumberDataProvider) == SumberData.tiruan) {
    return FakeFotoBuktiRepository();
  }
  return ApiFotoBuktiRepository(klien: ref.watch(klienApiProvider));
});

/// Penanda bahwa foto bukti masih tiruan, dipakai layar untuk mengaku terus
/// terang. Ikut hilang begitu kamera dan penyimpanan sungguhan dipasang.
final fotoBuktiTiruanProvider = Provider<bool>((ref) {
  return ref.watch(fotoBuktiRepositoryProvider) is FakeFotoBuktiRepository;
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
/// `null` di jalur API, sehingga tombol ganti akun hilang sendiri: di sana satu-satunya
/// cara berpindah akun adalah keluar lalu masuk dengan nomor dan kode sungguhan.
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
