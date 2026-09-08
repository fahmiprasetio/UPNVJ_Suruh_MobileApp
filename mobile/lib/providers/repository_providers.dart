import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/api/klien_api.dart';
import '../core/api/konfigurasi_api.dart';
import '../core/config/sumber_data.dart';
import '../core/notifikasi/konfigurasi_firebase.dart';
import '../core/notifikasi/notifikasi_push.dart';
import '../core/realtime/order_hub_client.dart';
import '../core/router/app_router.dart';
import '../domain/enums.dart';
import '../data/api/api_auth_repository.dart';
import '../data/api/api_foto_bukti_repository.dart';
import '../data/api/api_order_repository.dart';
import '../data/api/api_pendapatan_repository.dart';
import '../data/api/api_tarif_repository.dart';
import '../data/api/sesi_token.dart';
import '../data/fake/fake_auth_repository.dart';
import '../data/fake/fake_foto_bukti_repository.dart';
import '../data/fake/fake_order_repository.dart';
import '../data/fake/fake_pendapatan_repository.dart';
import '../data/fake/fake_tarif_repository.dart';
import '../data/fake/seed_data.dart';
import '../domain/models/app_user.dart';
import '../domain/models/pendapatan.dart';
import '../domain/models/tarif.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/foto_bukti_repository.dart';
import '../domain/repositories/order_repository.dart';
import '../domain/repositories/pendapatan_repository.dart';
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

/// Benar kalau sesi terakhir berakhir karena tokennya ditolak server, bukan
/// karena penggunanya menekan keluar.
///
/// Dipakai layar masuk untuk menjelaskan kenapa orangnya tiba-tiba ada di sana.
/// Tanpa keterangan itu, keluar paksa terbaca sebagai aplikasi yang rusak
/// sendiri, dan orang yang mengira aplikasinya rusak tidak mencoba masuk lagi.
///
/// Dikosongkan di satu tempat saja, yaitu begitu ada yang berhasil masuk. Itu
/// cukup untuk keduanya: sesi yang berakhir karena tombol keluar mendapati
/// nilainya sudah `false` sejak ia masuk tadi, jadi tidak ada kalimat yang salah
/// muncul untuk orang yang memang sengaja keluar.
class SesiDitolak extends Notifier<bool> {
  @override
  bool build() => false;

  void tandai() => state = true;

  void padamkan() => state = false;
}

final sesiDitolakProvider = NotifierProvider<SesiDitolak, bool>(SesiDitolak.new);

/// Klien HTTP mentah yang dipakai [klienApiProvider].
///
/// Berdiri sebagai provider tersendiri semata supaya tes bisa memasang klien tiruan
/// dan membuktikan apa yang terjadi ketika server menolak token, tanpa server
/// sungguhan. Itu satu-satunya jalur di aplikasi ini yang kalau putus tidak
/// menimbulkan galat apa pun, cuma aplikasi yang berhenti bisa dipakai tanpa memberi
/// tahu kenapa. Alasannya sama dengan [modeDebugProvider].
///
/// Penutupannya diserahkan ke [KlienApi.dispose], pemilik satu-satunya, supaya tidak
/// ada dua tempat yang mengaku menutup benda yang sama.
final klienHttpProvider = Provider<http.Client>((ref) => http.Client());

final klienApiProvider = Provider<KlienApi>((ref) {
  final klien = KlienApi(
    klien: ref.watch(klienHttpProvider),
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

/// Titik tukar backend untuk pendapatan runner.
final pendapatanRepositoryProvider = Provider<PendapatanRepository>((ref) {
  if (ref.watch(sumberDataProvider) == SumberData.tiruan) {
    return FakePendapatanRepository();
  }
  return ApiPendapatanRepository(klien: ref.watch(klienApiProvider));
});

/// Pendapatan runner yang sedang masuk.
///
/// `FutureProvider`, bukan aliran yang diambil ulang tiap lima belas detik
/// seperti daftar order, dan itu keputusan yang sama dengan [tarifProvider]
/// dengan alasan yang mirip: cuma dua kejadian yang mengubah angka di layar ini,
/// dan keduanya jarang. Runner menutup order (yang berarti ia sedang berada di
/// layar lain, dan layar ini akan mengambil ulang begitu dibuka lagi), dan admin
/// menandai bayaran sudah diserahkan, yang terjadi sekali seminggu.
///
/// Konsekuensinya ditulis terang-terangan: layar yang sedang terbuka tidak akan
/// melihat pelunasan yang baru saja dicatat admin sampai ditarik untuk
/// disegarkan. Layarnya menyediakan tarikan itu justru karena batas ini ada.
final pendapatanProvider = FutureProvider<Pendapatan>((ref) {
  return ref.watch(pendapatanRepositoryProvider).ambilPendapatan();
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

/// Pendaftaran perangkat untuk notifikasi push, mengikuti status masuk.
///
/// `null` di dua keadaan, dan keduanya disengaja: di jalur data tiruan, yang memang tidak
/// punya server untuk didaftari, dan di build yang identitas proyek Firebase-nya tidak
/// diisi sama sekali. Yang kedua yang penting: proyek ini harus tetap bisa dibangun dan
/// diuji oleh mesin yang belum punya proyek Firebase, termasuk CI.
///
/// Polanya sama persis dengan [orderHubClientProvider] di atas, karena persoalannya sama:
/// keduanya menempel pada akun yang sedang masuk, bukan pada aplikasi yang sedang dibuka.
final notifikasiPushProvider = Provider<NotifikasiPush?>((ref) {
  if (ref.watch(sumberDataProvider) == SumberData.tiruan) return null;
  if (!KonfigurasiFirebase.lengkap) return null;

  final notifikasi = NotifikasiPush(
    klien: ref.watch(klienApiProvider),
    // ponytail: dituju lewat peran bawaan akun, bukan peran yang sedang aktif dipakai
    // (rencana capstone bagian 14.2 membolehkan satu akun berpindah mode). Founder yang
    // memegang dua peran bisa saja sedang di mode runner ketika notifikasi klien datang
    // dan sebaliknya; muatan pesannya cuma berisi orderId, tidak ada penanda peran mana
    // yang dituju. Upgrade path: server ikut mengirim peran tertuju, atau baca
    // `peranAktifProvider` sekali `Ref` itu terjangkau tanpa membuat impor melingkar baru.
    bukaOrder: (orderId) {
      final peran = ref.read(userAktifProvider).value?.peranBawaan;
      final tujuan = peran == UserRole.runner
          ? Rute.chatOrderRunner(orderId)
          : Rute.detailOrder(orderId);
      ref.read(routerProvider).go(tujuan);
    },
  );
  ref.onDispose(notifikasi.dispose);

  ref.listen(userAktifProvider, (_, sekarang) {
    unawaited(sekarang.value != null ? notifikasi.mulai() : notifikasi.berhenti());
  }, fireImmediately: true);

  return notifikasi;
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
    // Arahnya sengaja begini: repository yang memberi tahu ke atas, bukan klien HTTP
    // yang meminta repository lewat provider. Yang kedua membuat keduanya saling
    // membutuhkan, dan Riverpod menolaknya sebagai lingkaran saat dijalankan.
    saatSesiBerakhirPaksa: () => ref.read(sesiDitolakProvider.notifier).tandai(),
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
