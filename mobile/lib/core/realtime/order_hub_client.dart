import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/klien_api.dart' show PengambilToken;

/// Pemisah pesan di Protokol Hub JSON milik SignalR: karakter Record Separator.
const String _pemisahPesan = '\x1e';

/// Hasil memisah teks yang baru datang dari soket jadi pesan-pesan utuh.
///
/// Fungsi murni, terpisah dari [OrderHubClient] supaya bisa diuji tanpa soket
/// sungguhan: satu bingkai WebSocket boleh membawa beberapa pesan sekaligus,
/// atau satu pesan boleh terpotong di dua bingkai berbeda, dan potongan yang
/// belum lengkap harus menunggu di [sisa] sampai pemisahnya datang.
({List<String> pesanUtuh, String sisa}) pisahkanPesanHub(String bufer) {
  final pesanUtuh = <String>[];
  var sisa = bufer;

  while (sisa.contains(_pemisahPesan)) {
    final batas = sisa.indexOf(_pemisahPesan);
    final satuPesan = sisa.substring(0, batas);
    sisa = sisa.substring(batas + 1);
    // Bingkai kosong (dua pemisah berurutan) diabaikan di sini. Balasan jabat
    // tangan yang sukses, "{}", tetap lolos sampai [apakahPesanInvocation]:
    // objek itu memang bukan pesan kosong, cuma kebetulan tidak punya "type".
    if (satuPesan.isNotEmpty) pesanUtuh.add(satuPesan);
  }

  return (pesanUtuh: pesanUtuh, sisa: sisa);
}

/// Benar kalau satu pesan hub adalah Invocation (server memanggil metode di
/// klien, ini yang berisi "OrderBroadcast"/"OrderTaken").
///
/// Pesan yang bukan JSON objek dianggap bukan invocation, bukan dilempar sebagai
/// galat: satu pesan yang tidak terbaca tidak seharusnya menjatuhkan koneksinya.
bool apakahPesanInvocation(String pesanJson) {
  try {
    final pesan = jsonDecode(pesanJson);
    return pesan is Map<String, dynamic> && pesan['type'] == 1;
  } on FormatException {
    return false;
  }
}

/// Menyusun satu pesan Invocation untuk dikirim ke server: memanggil method
/// [target] di hub dengan [argumen], mengikuti Protokol Hub JSON yang sama
/// dengan yang dibaca [apakahPesanInvocation].
///
/// Fungsi murni, terpisah dari [OrderHubClient] dengan alasan yang sama seperti
/// [pisahkanPesanHub]: supaya bentuk pesannya bisa diuji tanpa soket sungguhan.
/// Tidak menyertakan "invocationId" — server tidak diminta membalas, kedua
/// method hub yang memakainya ("GabungOrder" dan "TinggalkanOrder") sama-sama
/// tidak berbalas nilai, dan invocationId cuma berarti sesuatu kalau balasannya
/// ditunggu.
String bentukInvocation(String target, List<Object?> argumen) =>
    '${jsonEncode({'type': 1, 'target': target, 'arguments': argumen})}$_pemisahPesan';

/// Bagian dari [OrderHubClient] yang dibutuhkan pemakainya di luar dirinya
/// sendiri ([ApiOrderRepository] cuma butuh [perubahan], `ApiPaymentGateway`
/// butuh ketiganya), dipisahkan sebagai antarmuka supaya tes bisa memberi
/// tiruan yang tidak sungguhan menyambung ke mana pun — persis alasan yang
/// sama dengan `KontrakOrderHub` di sisi web.
abstract interface class SaluranHubOrder {
  void ikutiOrder(String orderId);
  void berhentiIkutiOrder(String orderId);
  Stream<void> get perubahan;
}

/// Klien SignalR minimal, ditulis tangan alih-alih memakai paket `signalr_netcore`.
///
/// Paket itu tidak mencantumkan dukungan web di pub.dev, dan proyek ini cuma bisa
/// dijalankan sebagai Flutter web di mesin pengembang (`CATATAN_DEV.md` bagian 3:
/// tidak ada emulator Android, tidak ada Windows desktop). Client SignalR yang
/// tidak jalan di web tidak berguna di sini. `web_socket_channel` resmi didukung
/// tim Dart di semua platform termasuk web, dan Protokol Hub JSON di baliknya
/// cukup sederhana untuk ditulis sendiri: satu pesan jabat tangan, lalu pesan JSON
/// dipisah karakter Record Separator (`\x1e`), ping berkala supaya server tidak
/// menganggap koneksinya mati.
///
/// Dipakai sebagai jaring penyegar tambahan, bukan satu-satunya sumber kebenaran:
/// [ApiOrderRepository] tetap mengambil ulang berkala lewat
/// `KonfigurasiApi.jedaSegarkan` sebagai jaring pengaman. Kalau koneksi hub putus
/// (jaringan kampus yang goyah, tab yang lama tidak difokuskan), penyegaran
/// berkala itu tetap membuat layar tidak basi selamanya menunggu koneksi pulih.
///
/// Server mensyaratkan `[Authorize]` di seluruh hub (lihat `OrderHub.cs`), jadi
/// [mulai] dipanggil ulang oleh [orderHubClientProvider] setiap kali status masuk
/// berubah, bukan sekali saat aplikasi dibuka.
///
/// ## Bergabung ke grup satu order
///
/// [ikutiOrder] dan [berhentiIkutiOrder] mengirim "GabungOrder"/"TinggalkanOrder"
/// ke server (rencana capstone bagian 41), dipakai layar bayar untuk kabar
/// "PaymentChanged" dan oleh `orderProvider` untuk kabar "MessageAdded" (bagian
/// 43) — kelas ini sengaja tidak membedakan kabar-kabar itu satu sama lain, dengan
/// alasan yang sama seperti di atas.
///
/// Id order yang sedang diikuti disimpan di [_orderDiikuti] dan dikirim ulang
/// setiap kali soket berhasil tersambung, termasuk sesudah sambung ulang.
/// Keanggotaan grup di SignalR menempel pada satu koneksi, bukan pada akunnya;
/// koneksi yang putus lalu tersambung lagi mendapat id koneksi baru, dan tanpa
/// pengiriman ulang ini layar bayar akan diam-diam berhenti mendengar tepat
/// pada saat jaringan sempat goyah, yaitu saat jaring pengaman ini justru paling
/// dibutuhkan.
class OrderHubClient implements SaluranHubOrder {
  OrderHubClient({
    required String baseUrl,
    required PengambilToken token,
    http.Client? klienHttp,
    Duration? jedaSambungUlang,
    Duration? jedaPing,
  }) : _baseUrl = baseUrl,
       _token = token,
       _klienHttp = klienHttp ?? http.Client(),
       _jedaSambungUlang = jedaSambungUlang ?? const Duration(seconds: 5),
       _jedaPing = jedaPing ?? const Duration(seconds: 10);

  final String _baseUrl;
  final PengambilToken _token;
  final http.Client _klienHttp;
  final Duration _jedaSambungUlang;
  final Duration _jedaPing;

  final StreamController<void> _perubahan = StreamController<void>.broadcast();

  /// Menyala setiap kali server mengirim pesan apa pun ke hub ini.
  ///
  /// Sengaja tidak membedakan satu kabar dari kabar lain ("OrderBroadcast",
  /// "OrderTaken", "PaymentChanged", "MessageAdded"): pemanggilnya cuma perlu
  /// tahu "ada yang berubah, ambil ulang", bukan detail apa yang berubah.
  /// Membedakannya berarti bentuk muatan pesan harus dijaga sama persis dengan
  /// backend di dua tempat, untuk sesuatu yang tidak dipakai layar mana pun.
  @override
  Stream<void> get perubahan => _perubahan.stream;

  WebSocketChannel? _soket;
  StreamSubscription<void>? _langgananSoket;
  Timer? _pewaktuPing;
  Timer? _pewaktuSambungUlang;
  bool _seharusnyaJalan = false;
  String _bufer = '';

  /// Order yang sedang diikuti, beserta berapa banyak pengamat di aplikasi ini
  /// yang sedang memintanya.
  ///
  /// Dihitung, bukan sekadar didaftar, karena satu order bisa diikuti lebih dari
  /// satu tempat sekaligus: layar bayar mengikuti lewat aliran transaksinya
  /// sendiri, dan pada saat yang sama `orderProvider` mengikutinya lagi untuk
  /// ordernya. Kalau ini cuma himpunan, yang pertama selesai akan mengirim
  /// "TinggalkanOrder" selagi yang kedua masih membutuhkannya, dan yang kedua
  /// diam-diam berhenti menerima kabar tanpa ada yang terlihat salah.
  final Map<String, int> _orderDiikuti = {};

  /// Cuma untuk tes: order yang sedang diikuti beserta jumlah pengamatnya.
  /// Perilaku hitungannya tidak bisa diamati dari luar tanpa soket sungguhan,
  /// karena [_kirim] diam-diam tidak melakukan apa pun selagi belum tersambung.
  @visibleForTesting
  Map<String, int> get orderDiikuti => Map.unmodifiable(_orderDiikuti);

  /// Mulai (atau sambung ulang) koneksi ke hub. Aman dipanggil berkali-kali.
  void mulai() {
    if (_seharusnyaJalan) return;
    _seharusnyaJalan = true;
    _sambung();
  }

  /// Putus koneksi dan berhenti mencoba sambung ulang, dipanggil saat pengguna keluar.
  void berhenti() {
    _seharusnyaJalan = false;
    _pewaktuSambungUlang?.cancel();
    _tutupSoket();
    // Bukan cuma soketnya yang ditutup: daftar order yang diikuti ikut
    // dikosongkan. Sesi berikutnya (akun lain yang masuk di perangkat yang sama)
    // tidak seharusnya mewarisi langganan order milik akun sebelumnya.
    _orderDiikuti.clear();
  }

  /// Mulai mendengarkan kabar satu order ("PaymentChanged", "MessageAdded"),
  /// dipanggil begitu salah satu layar order itu dibuka.
  ///
  /// Aman dipanggil sebelum soketnya tersambung, atau selagi terputus: id-nya
  /// disimpan lebih dulu, dikirim begitu (atau begitu lagi) tersambung. Aman pula
  /// dipanggil berkali-kali untuk order yang sama, asal setiap panggilan
  /// berpasangan dengan satu [berhentiIkutiOrder].
  @override
  void ikutiOrder(String orderId) {
    _orderDiikuti.update(orderId, (jumlah) => jumlah + 1, ifAbsent: () => 1);
    // Dikirim juga saat pengamat kedua datang walau grupnya sudah diikuti.
    // "GabungOrder" idempoten di sisi server, dan mengirimnya ulang lebih murah
    // daripada menjaga tebakan tentang keadaan grup di sisi sini tetap benar.
    _kirim(bentukInvocation('GabungOrder', [orderId]));
  }

  /// Berhenti mendengarkan satu order, dipanggil begitu layarnya ditutup.
  ///
  /// Grupnya baru sungguh ditinggalkan saat pengamat terakhirnya pergi.
  @override
  void berhentiIkutiOrder(String orderId) {
    final sisa = (_orderDiikuti[orderId] ?? 0) - 1;
    if (sisa > 0) {
      _orderDiikuti[orderId] = sisa;
      return;
    }

    _orderDiikuti.remove(orderId);
    _kirim(bentukInvocation('TinggalkanOrder', [orderId]));
  }

  /// Menulis satu pesan mentah ke soket, diam-diam diabaikan kalau sedang tidak
  /// tersambung. Pemanggilnya (mulai, ping berkala, ikutiOrder) tidak perlu tahu
  /// keadaan koneksinya lebih dulu; yang tidak sempat terkirim akan menyusul
  /// lewat jalur masing-masing begitu tersambung lagi ([_sambung] mengirim ulang
  /// seluruh [_orderDiikuti], [_pewaktuPing] menyala lagi begitu soket baru ada).
  void _kirim(String pesan) => _soket?.sink.add(pesan);

  Future<void> _sambung() async {
    if (!_seharusnyaJalan) return;

    final token = _token();
    if (token == null || token.isEmpty) {
      // Belum masuk. Coba lagi nanti alih-alih gagal diam-diam selamanya, karena
      // pemanggil di sisi provider yang menentukan kapan token akan ada, bukan
      // klien ini.
      _jadwalkanSambungUlang();
      return;
    }

    try {
      final connectionId = await _negosiasi(token);
      final alamatSoket = _alamatSoket(connectionId, token);
      final soket = WebSocketChannel.connect(alamatSoket);
      await soket.ready;

      // berhenti() bisa dipanggil selagi negosiasi atau pembukaan soket di atas
      // masih menunggu (pengguna keluar tepat di jendela itu). Tanpa penjagaan
      // ini, soket yang terlanjur tersambung dengan token lama akan tetap hidup
      // dan terus menerima siaran walau sudah dianggap berhenti.
      if (!_seharusnyaJalan) {
        unawaited(soket.sink.close());
        return;
      }
      _soket = soket;

      soket.sink.add('${jsonEncode({'protocol': 'json', 'version': 1})}$_pemisahPesan');

      _langgananSoket = soket.stream.listen(
        _terimaPesan,
        onDone: _koneksiPutus,
        onError: (_) => _koneksiPutus(),
        cancelOnError: true,
      );

      _pewaktuPing = Timer.periodic(_jedaPing, (_) {
        _kirim('${jsonEncode({'type': 6})}$_pemisahPesan');
      });

      // Keanggotaan grup SignalR menempel pada satu koneksi, bukan pada akun.
      // Soket yang baru ini punya id koneksi baru, jadi order yang tadinya
      // diikuti lewat koneksi lama (kalau ini sambungan ulang sesudah putus)
      // perlu diminta lagi dari awal; server tidak mengingatnya sendiri.
      for (final orderId in _orderDiikuti.keys) {
        _kirim(bentukInvocation('GabungOrder', [orderId]));
      }
    } catch (_) {
      // Negosiasi gagal (server belum menyala, token ditolak, jaringan mati).
      // Bukan galat yang layak dilempar ke pemanggil: klien ini cuma jaring
      // tambahan, dan penyegaran berkala tetap jalan tanpanya.
      _jadwalkanSambungUlang();
    }
  }

  /// Langkah pertama protokol SignalR sebelum WebSocket dibuka: menukar token
  /// dengan id koneksi yang dipasang di alamat soketnya.
  Future<String> _negosiasi(String token) async {
    final jawaban = await _klienHttp
        .post(
          Uri.parse('$_baseUrl/hubs/orders/negotiate?negotiateVersion=1'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 10));

    if (jawaban.statusCode != 200) {
      throw StateError('Negosiasi hub gagal: ${jawaban.statusCode}');
    }

    final isi = jsonDecode(jawaban.body) as Map<String, dynamic>;
    // connectionToken dipakai kalau ada (server dengan lebih dari satu instans),
    // connectionId dipakai kalau tidak. Client resmi SignalR mengikuti pola yang
    // sama.
    return (isi['connectionToken'] ?? isi['connectionId']) as String;
  }

  Uri _alamatSoket(String connectionId, String token) {
    final alamatHttp = Uri.parse('$_baseUrl/hubs/orders');
    return alamatHttp.replace(
      scheme: alamatHttp.scheme == 'https' ? 'wss' : 'ws',
      queryParameters: {'id': connectionId, 'access_token': token},
    );
  }

  void _terimaPesan(dynamic pesanMentah) {
    final hasil = pisahkanPesanHub(_bufer + (pesanMentah as String));
    _bufer = hasil.sisa;

    for (final pesan in hasil.pesanUtuh) {
      if (apakahPesanInvocation(pesan)) _perubahan.add(null);
    }
  }

  void _koneksiPutus() {
    _tutupSoket();
    _jadwalkanSambungUlang();
  }

  void _tutupSoket() {
    _pewaktuPing?.cancel();
    _langgananSoket?.cancel();
    _soket?.sink.close();
    _soket = null;
    _bufer = '';
  }

  void _jadwalkanSambungUlang() {
    if (!_seharusnyaJalan) return;
    _pewaktuSambungUlang?.cancel();
    _pewaktuSambungUlang = Timer(_jedaSambungUlang, _sambung);
  }

  void dispose() {
    berhenti();
    _klienHttp.close();
    _perubahan.close();
  }
}
