import 'package:upnvj_suruh/core/config/sumber_data.dart';
import 'package:upnvj_suruh/providers/repository_providers.dart';

/// Menyatakan bahwa satu tes berjalan di atas data karangan, bukan API.
///
/// Sejak penukaran backend, bawaan aplikasi adalah [SumberData.api]. Tes layar
/// yang tidak menyebut apa-apa akan berusaha menembak alamat backend, gagal, dan
/// gagalnya menyesatkan: yang terbaca "layar tidak menampilkan sapaan", padahal
/// yang terjadi "tidak ada server".
///
/// Karena itu penukarannya ditulis di daftar `overrides` tiap tes, bukan
/// diwariskan diam-diam lewat nilai bawaan. Dari berkas tesnya sendiri terbaca
/// bahwa ia menguji layar di atas tiruan, dan tidak membuktikan apa pun tentang
/// jalur API.
final sumberTiruan = sumberDataProvider.overrideWithValue(SumberData.tiruan);
