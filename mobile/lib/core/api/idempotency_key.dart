import 'dart:convert';
import 'dart:math';

/// Key acak yang tetap hidup selama satu draft order.
///
/// Form membuatnya sekali saat dibuka dan memakai nilai yang sama ketika request
/// diulang. Membuat key di repository setiap kali method dipanggil akan mengalahkan
/// tujuan idempotensi, karena retry jaringan akan terlihat sebagai draft baru.
String buatIdempotencyKey() {
  final acak = Random.secure();
  final bytes = List<int>.generate(16, (_) => acak.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}
