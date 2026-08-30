import 'package:flutter_test/flutter_test.dart';
import 'package:upnvj_suruh/core/api/konfigurasi_api.dart';

/// Alamat backend yang salah tidak boleh ikut terbang ke tangan pengguna.
///
/// Nilai bawaannya alamat emulator lewat http biasa, dan itu benar untuk mesin
/// pengembang. Build rilis yang lahir tanpa `--dart-define` menyala seperti biasa lalu
/// gagal di setiap permintaan, karena Android memblokir lalu lintas tanpa sandi, dan
/// yang terlihat pengguna cuma "tidak bisa menghubungi server" tanpa sebab yang bisa
/// ditebak siapa pun.
void main() {
  group('alamat backend', () {
    test('rilis menolak alamat bawaan yang menunjuk emulator', () {
      expect(
        () => KonfigurasiApi.baca(
          modeDebug: false,
          nilai: 'http://10.0.2.2:5059',
        ),
        throwsStateError,
      );
    });

    test('rilis menolak http walaupun servernya sungguhan', () {
      // Token sesi dan nomor HP orang tidak boleh berangkat tanpa sandi. Alamat http
      // yang kebetulan bekerja saat diuji adalah alamat yang akan terbawa ke pengguna.
      expect(
        () => KonfigurasiApi.baca(
          modeDebug: false,
          nilai: 'http://api.contoh.test',
        ),
        throwsStateError,
      );
    });

    test('rilis menerima https', () {
      expect(
        KonfigurasiApi.baca(modeDebug: false, nilai: 'https://api.contoh.test'),
        'https://api.contoh.test',
      );
    });

    test('debug membiarkan http, karena di situlah backend lokal hidup', () {
      expect(
        KonfigurasiApi.baca(modeDebug: true, nilai: 'http://10.0.2.2:5059'),
        'http://10.0.2.2:5059',
      );
    });
  });
}
