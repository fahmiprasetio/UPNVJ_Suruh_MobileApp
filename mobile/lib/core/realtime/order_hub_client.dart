import 'dart:async';
import 'dart:convert';

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
class OrderHubClient {
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
  /// Sengaja tidak membedakan "OrderBroadcast" dari "OrderTaken": pemanggilnya
  /// cuma perlu tahu "ada yang berubah, ambil ulang", bukan detail apa yang
  /// berubah. Membedakannya berarti bentuk muatan pesan harus dijaga sama persis
  /// dengan backend di dua tempat, untuk sesuatu yang tidak dipakai layar mana pun.
  Stream<void> get perubahan => _perubahan.stream;

  WebSocketChannel? _soket;
  StreamSubscription<void>? _langgananSoket;
  Timer? _pewaktuPing;
  Timer? _pewaktuSambungUlang;
  bool _seharusnyaJalan = false;
  String _bufer = '';

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
  }

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
        _soket?.sink.add('${jsonEncode({'type': 6})}$_pemisahPesan');
      });
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
