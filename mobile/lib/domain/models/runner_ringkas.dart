import 'package:flutter/foundation.dart';

/// Satu runner yang sudah menerima order, sebagaimana klien perlu mengenalinya.
///
/// Bukan cuma id: sebelum ini klien yang ordernya sedang dikerjakan tidak
/// pernah tahu siapa yang menuju kosnya, cuma bahwa "seseorang" sudah
/// menerimanya. Nomor HP ikut karena runner pegawai mitra yang dipercaya,
/// bukan orang asing dari pasar terbuka.
@immutable
class RunnerRingkas {
  const RunnerRingkas({required this.id, required this.nama, this.noHp});

  final String id;
  final String nama;
  final String? noHp;
}
