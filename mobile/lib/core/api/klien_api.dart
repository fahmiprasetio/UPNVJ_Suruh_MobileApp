import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'galat_api.dart';
import 'konfigurasi_api.dart';

/// Sumber token untuk permintaan yang butuh identitas.
///
/// Berbentuk fungsi, bukan nilai, karena token bisa berubah di tengah hidup
/// aplikasi: pengguna masuk, keluar, lalu masuk lagi sebagai akun lain. Klien yang
/// menyimpan tokennya sekali saat dibuat akan terus memakai token lama setelah
/// pengguna berganti akun.
typedef PengambilToken = String? Function();

/// Dipanggil ketika server menolak token yang sedang dipakai.
///
/// Berbentuk callback, bukan galat yang dilempar ke atas, karena yang harus
/// terjadi bukan urusan satu layar yang kebetulan sedang mengambil data:
/// seluruh aplikasi harus berhenti memakai token itu. Layar mana pun tetap
/// menerima [GalatTidakBerwenang]-nya seperti biasa.
typedef PenolakanSesi = void Function();

/// Satu-satunya tempat aplikasi ini bicara HTTP.
///
/// Semua repository lewat sini, jadi hal-hal yang harus benar di setiap permintaan
/// hanya perlu ditulis sekali: header, batas waktu, penerjemahan galat, dan
/// pemasangan token. Repository yang merakit permintaannya masing-masing berarti
/// setiap repository baru adalah kesempatan baru untuk lupa salah satunya.
class KlienApi {
  KlienApi({
    http.Client? klien,
    String? baseUrl,
    PengambilToken? token,
    Duration? batasWaktu,
  })  : _klien = klien ?? http.Client(),
        _baseUrl = baseUrl ?? KonfigurasiApi.baseUrl,
        _token = token ?? (() => null),
        _batasWaktu = batasWaktu ?? KonfigurasiApi.batasWaktu;

  final http.Client _klien;
  final String _baseUrl;
  final PengambilToken _token;
  final Duration _batasWaktu;

  /// Siapa yang diberi tahu ketika server menolak token yang sedang dipakai.
  ///
  /// Dipasang belakangan, bukan diterima di konstruktor, dan arahnya memang
  /// begitu: yang memasangnya adalah `ApiAuthRepository`, satu-satunya yang tahu
  /// cara mengakhiri sesi, dan repository itu sendiri dibuat dari klien ini. Kalau
  /// urutannya dibalik — klien ini yang meminta repositorynya lewat provider —
  /// keduanya jadi saling membutuhkan, dan Riverpod menolaknya sebagai lingkaran.
  PenolakanSesi? saatSesiDitolak;

  Future<Map<String, dynamic>> get(String jalur, {Map<String, String>? kueri}) async =>
      _kirim(() => _klien.get(_alamat(jalur, kueri), headers: _header()));

  Future<List<dynamic>> getDaftar(String jalur, {Map<String, String>? kueri}) async {
    final jawaban = await _jalankan(() => _klien.get(_alamat(jalur, kueri), headers: _header()));
    final isi = _uraikan(jawaban);
    if (isi is! List) {
      throw const GalatServer('Jawaban server tidak berbentuk daftar.');
    }
    return isi;
  }

  Future<Map<String, dynamic>> post(String jalur, {Object? badan}) async => _kirim(
        () => _klien.post(
          _alamat(jalur, null),
          headers: _header(denganBadan: badan != null),
          body: badan == null ? null : jsonEncode(badan),
        ),
      );

  Future<Map<String, dynamic>> put(String jalur, {Object? badan}) async => _kirim(
        () => _klien.put(
          _alamat(jalur, null),
          headers: _header(denganBadan: badan != null),
          body: badan == null ? null : jsonEncode(badan),
        ),
      );

  /// Mengirim satu berkas sebagai multipart.
  ///
  /// Lewat pintu yang sama dengan permintaan lain, bukan merakit `MultipartRequest`
  /// sendiri di repository yang membutuhkannya. Yang harus benar di setiap permintaan,
  /// yaitu token, batas waktu, dan penerjemahan galat, cuma ditulis sekali di sini;
  /// repository yang merakit permintaannya masing-masing adalah kesempatan baru untuk
  /// melupakan salah satunya.
  Future<Map<String, dynamic>> postBerkas(
    String jalur, {
    required String kolom,
    required String namaBerkas,
    required List<int> isi,
  }) async {
    Future<http.Response> kirim() async {
      final permintaan = http.MultipartRequest('POST', _alamat(jalur, null))
        // Content-Type tidak ikut dipasang di sini: paket http yang menyusunnya,
        // lengkap dengan batas antarbagian yang harus cocok dengan badannya.
        ..headers.addAll(_header())
        ..files.add(
          http.MultipartFile.fromBytes(kolom, isi, filename: namaBerkas),
        );

      // Dikembalikan sebagai Response biasa supaya jalannya sama persis dengan
      // permintaan lain sesudah ini, termasuk penerjemahan galatnya.
      return http.Response.fromStream(await _klien.send(permintaan));
    }

    return _kirim(kirim);
  }

  Uri _alamat(String jalur, Map<String, String>? kueri) =>
      Uri.parse('$_baseUrl$jalur').replace(queryParameters: kueri);

  /// Header identitas untuk permintaan yang tidak bisa lewat kelas ini.
  ///
  /// Ada satu: widget gambar. `Image.network` mengambil berkasnya sendiri, jadi ia
  /// tidak bisa memakai [get] maupun [post], padahal sejak foto bukti dijaga token,
  /// permintaan tanpa header ini dijawab 401 dan yang tampil cuma kotak gagal muat.
  ///
  /// Dibagikan dari sini, bukan disusun ulang di widget-nya, supaya bentuk header-nya
  /// cuma ditulis sekali. Kata "Bearer" yang ditulis di dua tempat akan tetap benar
  /// sampai salah satunya diubah, dan yang berubah lebih dulu biasanya yang punya tes.
  ///
  /// Kosong kalau belum masuk, bukan berisi token kosong: header Authorization yang
  /// ada tapi kosong ditolak server dengan galat yang berbeda dari sekadar belum masuk.
  Map<String, String> get headerOtorisasi {
    final token = _token();
    if (token == null || token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
  }

  Map<String, String> _header({bool denganBadan = false}) {
    final header = <String, String>{'Accept': 'application/json'};
    if (denganBadan) header['Content-Type'] = 'application/json';
    return header..addAll(headerOtorisasi);
  }

  Future<Map<String, dynamic>> _kirim(Future<http.Response> Function() permintaan) async {
    final jawaban = await _jalankan(permintaan);
    final isi = _uraikan(jawaban);

    // 204 dan jawaban berbadan kosong sah adanya, dan pemanggil yang tidak butuh
    // isinya tidak perlu tahu bedanya.
    if (isi == null) return const {};
    if (isi is! Map<String, dynamic>) {
      throw const GalatServer('Jawaban server tidak berbentuk objek.');
    }
    return isi;
  }

  Future<http.Response> _jalankan(Future<http.Response> Function() permintaan) async {
    final http.Response jawaban;
    try {
      jawaban = await permintaan().timeout(_batasWaktu);
    } on TimeoutException {
      throw const GalatJaringan('Server tidak menjawab tepat waktu. Coba lagi, ya.');
    } on SocketException {
      throw const GalatJaringan();
    } on http.ClientException {
      throw const GalatJaringan();
    }

    if (jawaban.statusCode >= 200 && jawaban.statusCode < 300) return jawaban;

    // Token yang ditolak dilaporkan sekali di sini, bukan ditunggu ditangani
    // masing-masing layar.
    //
    // Tanpa ini, sesi yang habis di tengah pemakaian (token berlaku 60 menit,
    // dan tidak ada penyegarannya) tidak menghasilkan apa pun selain setiap
    // layar berubah jadi kotak "gagal muat" dengan tombol coba lagi yang
    // selamanya gagal. Tidak ada satu pun kalimat yang memberi tahu bahwa yang
    // dibutuhkan cuma masuk lagi, dan tidak ada jalan keluar selain menebaknya
    // sendiri lewat tombol keluar di layar profil. Yang ditangani dengan benar
    // selama ini cuma token kedaluwarsa yang ketahuan saat aplikasi DIBUKA
    // (`ApiAuthRepository.pulihkanSesi`), bukan yang habis saat sedang dipakai.
    //
    // Syarat keduanya penting: cuma permintaan yang benar-benar membawa token
    // yang boleh memicunya. Kode masuk yang salah juga dijawab 401, dan itu
    // berangkat tanpa token sama sekali — memperlakukannya sebagai sesi ditolak
    // berarti setiap salah ketik kode mengeluarkan orang yang bahkan belum
    // masuk.
    if (jawaban.statusCode == 401 && headerOtorisasi.isNotEmpty) {
      saatSesiDitolak?.call();
    }

    throw _terjemahkan(jawaban);
  }

  /// Menerjemahkan jawaban gagal jadi galat yang sudah punya arti bagi layar.
  GalatApi _terjemahkan(http.Response jawaban) {
    final pesan = _pesanDari(jawaban);

    return switch (jawaban.statusCode) {
      400 || 422 => GalatPermintaan(pesan ?? 'Ada isian yang belum benar.'),
      401 => const GalatTidakBerwenang(),
      403 => const GalatDilarang(),
      404 => const GalatTidakDitemukan(),
      409 => GalatBentrok(pesan ?? 'Data ini bentrok dengan yang sudah ada.'),
      // Pesannya dipakai apa adanya kalau server mengirimkannya, karena hanya server
      // yang tahu batas mana yang tercapai dan berapa lama sisanya. Tanpa penanganan
      // khusus, 429 jatuh ke GalatServer dan layar menyuruh pengguna mencoba lagi
      // sebentar lagi, yaitu persis hal yang membuatnya ditolak tadi.
      429 => pesan == null ? const GalatTerlaluSering() : GalatTerlaluSering(pesan),
      _ => const GalatServer(),
    };
  }

  /// Mengambil kalimat yang layak dibaca pengguna dari badan ProblemDetails.
  ///
  /// Hanya dipakai untuk galat yang memang salah pengguna. Untuk 5xx, isinya
  /// sengaja diabaikan, lihat alasannya di [GalatServer].
  String? _pesanDari(http.Response jawaban) {
    try {
      final isi = _uraikan(jawaban);
      if (isi is! Map<String, dynamic>) return null;

      // ASP.NET Core mengirim galat validasi sebagai peta field ke daftar pesan.
      final errors = isi['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final pertama = errors.values.first;
        if (pertama is List && pertama.isNotEmpty) return pertama.first.toString();
      }

      final detail = isi['detail'] ?? isi['title'];
      return detail is String && detail.isNotEmpty ? detail : null;
    } on GalatServer {
      // Badan yang bukan JSON bukan alasan menutupi galatnya. Kode statusnya sudah
      // cukup untuk memilih jenis galat yang benar, jadi cukup kembalikan tanpa
      // pesan tambahan.
      return null;
    }
  }

  /// Menguraikan badan jawaban, dan mengubah badan yang bukan JSON jadi galat yang
  /// sudah punya arti.
  ///
  /// Tanpa ini, jawaban 200 yang ternyata halaman HTML dari reverse proxy akan
  /// muncul di layar sebagai `FormatException` mentah lengkap dengan potongan
  /// dokumennya. Yang seperti itu tidak bisa dibaca pengguna dan tidak bisa
  /// ditangani layar, karena bukan turunan [GalatApi].
  dynamic _uraikan(http.Response jawaban) {
    if (jawaban.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(jawaban.bodyBytes));
    } on FormatException {
      throw const GalatServer('Jawaban server tidak bisa dibaca.');
    }
  }

  void dispose() => _klien.close();
}
