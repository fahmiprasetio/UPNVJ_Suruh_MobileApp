# Catatan Pengembangan

Berkas ini untuk diri sendiri dan untuk sesi berikutnya. Isinya angka-angka yang tidak boleh
ditebak ulang, alasan di balik keputusan yang tidak terbaca dari kode, bagian yang sengaja
ditinggal, dan tempat melanjutkan.

Bagian 1 sampai 7 dari sesi pertama: cara menyalakan proyek supaya bisa dilihat di browser,
dan catatan animasi splash screen. Bagian 8 dan seterusnya dari sesi 30 Agustus 2026:
pengerasan keamanan backend dan migrasi sistem desain ke permukaan klien.

**Kalau sedang mencari tempat melanjutkan, langsung ke bagian 11.**

---

## 1. Cara Menjalankan (Ringkas)

Dua perintah, lalu buka `localhost:8770` di Brave sendiri.

**Perintah 1, build (hanya kalau kode berubah):**

```
cd "D:\Projek Website & Mobile App\UPNVJ_Suruh_MobileApp\mobile"
flutter build web --release --no-web-resources-cdn
```

**Perintah 2, nyalakan server:**

```
cd "D:\Projek Website & Mobile App\UPNVJ_Suruh_MobileApp\mobile\build\web"
python -m http.server 8770 --bind 127.0.0.1
```

Lalu ketik `localhost:8770` di Brave. Tidak ada jendela browser yang terbuka otomatis.
Ekstensi Brave boleh tetap menyala.

Kalau kode tidak berubah, cukup perintah kedua. Build lamanya masih tersimpan di
`mobile/build/web`.

---

## 2. Kenapa Tidak Pakai `flutter run -d chrome`

Ini penting, jangan diulang kesalahannya.

`flutter run -d chrome` menjalankan mode debug yang memecah aplikasi jadi **871 berkas
JavaScript, total 118 MB**. Akibatnya di mesin ini:

- Kompilasi dingin 1,5 sampai 2,5 menit setiap kali dijalankan
- Setiap dari 871 request diperiksa satu per satu oleh ekstensi Brave, jadi di Brave asli
  halamannya terlihat blank padahal sebenarnya masih memuat
- Flutter memaksa membuka jendela Brave baru dengan profil sementara dan
  `--disable-extensions`, bukan Brave yang biasa dipakai

Build release mengompilasi jadi **36 berkas, satu `main.dart.js` berukuran 3,7 MB**, dan
terunduh dalam 0,25 detik. Itu sebabnya cara di bagian 1 yang dipakai.

Flag `--no-web-resources-cdn` bukan hiasan. Tanpa itu, CanvasKit diambil dari
`gstatic.com` lewat internet. Dengan flag itu, CanvasKit ikut dibundel lokal dan
`useLocalCanvasKit` bernilai true, sehingga tidak ada request keluar sama sekali.

---

## 3. Batasan Mesin yang Harus Diingat

Hasil pemeriksaan, bukan perkiraan:

- CPU hanya **2 core**
- RAM **7,8 GB**, sering tersisa di bawah 1 GB saat Brave dan IDE menyala
- Drive C sisa **8,6 GB**

Konsekuensinya:

- **Windows desktop tidak bisa dipakai.** Visual Studio Build Tools terpasang tapi rusak,
  dan workload "Desktop development with C++" butuh sekitar 7 sampai 10 GB di drive C
  yang tidak tersedia.
- **Emulator Android tidak bisa dipakai.** Butuh disk dan RAM lebih besar lagi.
- **Web adalah satu-satunya target yang realistis** di mesin ini.

Kalau layar tiba-tiba putih total tanpa pesan error apa pun, curigai RAM lebih dulu, bukan
kode. CanvasKit butuh alokasi heap WASM sekaligus, dan kalau gagal, gagalnya di lapisan
browser sehingga terminal Flutter tetap bersih tanpa exception. Obatnya menutup DevTools
dan tab berat, bukan mengubah kode.

---

## 4. Hal yang Sudah Dipastikan Sehat

Sudah diuji dengan probe bertahap, jadi tidak perlu dicurigai lagi:

- Kode aplikasi, `main()` berjalan tuntas sampai `runApp` dan frame pertama tergambar
- `initializeDateFormatting` untuk locale id_ID
- `flutter_secure_storage` di web
- Ketiga delegate `flutter_localizations` untuk locale id_ID
- CanvasKit dan rendering di Brave
- Routing GoRouter dan Riverpod

---

## 5. Menjalankan Tanpa Backend

Backend .NET default menunjuk `http://10.0.2.2:5059`, yaitu alamat khusus emulator
Android. Alamat itu **tidak valid di browser**, jadi semua panggilan API akan gagal.

Proyek ini punya mode tanpa server yang resmi:

```
--dart-define=SUMBER_DATA=tiruan
```

Tapi perhatikan: `KonfigurasiSumberData.baca` sengaja **menolak** nilai tiruan di build
non-debug, jadi saklar ini tidak bisa dipakai bersama `flutter build web --release`.

Untuk sekadar melihat tampilan (termasuk splash screen dan layar masuk), ini tidak jadi
masalah. Layar-layar itu tidak memanggil API sampai ada tombol yang ditekan.

Kalau nanti butuh menjalankan alur data lengkap di browser, arahkan ke backend lokal:

```
flutter build web --release --no-web-resources-cdn --dart-define=API_BASE_URL=http://localhost:5059
```

dan pastikan backend .NET-nya menyala.

---

## 6. Splash Screen (Sudah Dikerjakan)

### Keputusan: animasi dari kode, bukan video

Video mp4 ditolak untuk splash screen karena:

- `video_player` sendiri butuh waktu inisialisasi, jadi justru menambah beban di detik
  yang paling sensitif, dan sering memunculkan kedipan hitam
- Ukuran file 1 sampai 3 MB, sementara animasi kode nol tambahan
- Kompresi video merusak area putih polos, muncul banding dan artefak di tepi logo
- Durasi terkunci, memaksa pengguna menunggu walau aplikasi sudah siap

### Aset

Aset mentah tetap di `assets/` pada akar proyek sebagai sumber. Yang dipakai aplikasi
adalah `mobile/assets/logo/lencana.png`, dibuat ulang dari `assets/tanpa nama.png`
dengan langkah berikut:

1. Latar putihnya dibuang dengan flood fill dari seluruh piksel tepi. Cara ini dipilih
   supaya putih yang memang bagian logo (garis helm, sorotan di jalan, mata buaya) tidak
   ikut hilang, karena putih-putih itu tidak menyambung ke luar gambar.
2. Tepi hasil keying dihaluskan dengan blur 0,8 piksel supaya tidak bergerigi.
3. Kanvasnya digeser sampai pusat cincin jatuh persis di tengah gambar, lalu
   diperkecil ke 512 x 512.

Langkah 3 itu bukan kerapian, tapi syarat: teks "UPNVJ SURUH" digambar dari kode dan
harus sepusat dengan cincin yang tercetak di dalam PNG. Angka hasil pengukurannya
tercatat di `GeometriLencana` (`mobile/lib/features/pembuka/widgets/lencana_logo.dart`),
jari-jari cincin 0,478 kali sisi gambar. Kalau `lencana.png` diganti, angka itu harus
diukur ulang.

Teks melengkungnya digambar `CustomPainter`, bukan disimpan sebagai gambar, karena yang
diinginkan hurufnya muncul satu per satu. Sebagai gambar, satu-satunya animasi yang
mungkin adalah menyingkap seluruh baris di balik topeng, dan itu terbaca sebagai tirai.
Geometrinya diambil dari `logo-with-name.jpg`: alas huruf 1,25 kali jari-jari cincin,
tinggi huruf 0,372 kali jari-jari cincin, rentang tulisan 107 derajat. Yang dipakai di
kode berbeda dari ketiganya: alas huruf 1,46 dan tinggi huruf 0,29. Logo aslinya gambar
diam yang dipandang utuh, sementara ini layar yang dilewati, dan di detik yang cuma
sekejap itu tulisan yang menempel di cincin terbaca sebagai satu gumpalan gelap bersama
lencananya. Menjauhkan tulisan sekaligus mengecilkan rentang sudutnya, karena busur yang
lebih besar memuat lebar yang sama dalam sudut yang lebih kecil.

### Urutan animasi yang jalan sekarang

Dua `AnimationController`, bukan satu, dan itu bukan detail remeh — lihat subbagian
setelah ini.

**`_utama`, 2,1 detik, gerakan dekoratifnya. Selalu selesai dalam waktu tetap ini:**

1. `0,00 - 0,48` lencana naik dari bawah dengan `Curves.elasticOut`. Sengaja TANPA
   pemudaran masuk: lencananya utuh sejak bingkai pertama Flutter, cuma bergerak naik,
   supaya di awal pun tidak ada sepersekian detik yang isinya putih polos
2. `0,48 - 0,79` berputar satu putaran penuh di sumbu Y dengan perspektif, seperti koin
3. `0,69 - 1,00` teks melengkung tertulis huruf demi huruf dari kiri ke kanan, tiap
   huruf turun ke tempatnya dari arah luar lingkaran

**`_angkat`, 220 milidetik, mengangkat seluruh lapisannya.** Baru mulai setelah `_utama`
selesai DAN sesi selesai dipulihkan dari server, mana pun yang lebih lambat (lihat
subbagian berikutnya). Sebelum `_angkat` mulai, lencananya diam utuh di layar, bukan
kosong.

Yang memudar adalah SELURUH lapisan putih berlencana itu, bukan lencananya sendirian di
atas latar putih yang tetap tinggal. Bedanya menentukan: memudarkan lencana saja
menyisakan latar putih lapisan itu di layar, dan latar putih yang tersisa itu persis
bingkai kosong yang harus tidak ada.

Jeda dan angkat sengaja ikut di dalam pengendali animasi, bukan `Future.delayed`
terpisah. Timer yang menggantung di luar pengendali tidak terhitung oleh
`pumpAndSettle`, jadi tes layar selesai sebelum perpindahannya terjadi lalu gagal dengan
keluhan timer yang masih hidup.

Ukuran lencananya 0,48 kali sisi terpendek layar, dibatasi 120 sampai 190 piksel. Batas
atas itu yang paling sering terpakai: di jendela browser sisi terpendek adalah tingginya,
dan tinggi jendela di layar biasa jauh lebih besar dari lebar ponsel, jadi tanpa batas
itu lencananya membengkak jadi gambar raksasa.

Kalau perangkat mematikan animasi di setelan aksesibilitas, `_utama` dilompati langsung
ke keadaan akhir. Kesiapan sesi tetap ditunggu meski begitu: melompatinya berarti
aplikasi bisa menampilkan layar dalam sebelum tahu siapa yang masuk, itu beda soal dari
sekadar menghemat waktu pengguna.

### Kenapa dua pengendali, bukan satu: bug layar putih kosong

Sebelumnya pudar keluarnya ikut di dalam pengendali dekoratif yang sama, jadi begitu
waktunya habis, lencananya memudar tanpa peduli apakah layar berikutnya sudah siap.
Pemulihan sesinya sendiri sebuah panggilan jaringan ke `KonfigurasiApi.baseUrl`, dan
waktunya tidak pernah pasti. Kalau panggilan itu lebih lambat dari durasi animasi (dan di
mesin ini, tanpa backend .NET yang menyala, ia memang selalu lebih lambat, dibatasi 20
detik oleh `KonfigurasiApi.batasWaktu` sebelum menyerah), yang terlihat pengguna adalah:
animasi selesai, lencananya memudar sampai tidak terlihat, layar tetap putih kosong
sampai batas waktu itu habis, baru layar berikutnya muncul. Persis keluhan "logo hilang,
layar putih, nunggu, baru muncul halaman 2".

Perbaikannya dua bagian, saling bergantung:

1. **`main()` tidak lagi menunggu pemulihan sesi sebelum `runApp`.** Panggilannya
   dipindah ke [kesiapanSesiProvider](mobile/lib/providers/pembuka_providers.dart),
   sebuah `FutureProvider` yang dipicu lewat `ref.read` di `main()` (bukan ditunggu),
   supaya panggilannya sudah berjalan sejak sebelum bingkai pertama, berbarengan dengan
   animasi, bukan menahannya.
2. **`_angkat` baru mulai setelah `_utama` selesai DAN `kesiapanSesiProvider` selesai**,
   lewat `Future.wait([?gerakan, ref.read(kesiapanSesiProvider.future)])` di
   `pembuka_overlay.dart`. Selama menunggu yang mana pun yang lebih lambat, lencananya
   diam utuh (pengendali `_utama` berhenti di nilai akhirnya begitu `forward()` selesai,
   dan `_angkat` belum digerakkan sama sekali), bukan kosong.

Diuji lewat kasus `'lencana tetap utuh menunggu sesi, tidak diangkat lebih awal'` di
`pembuka_overlay_test.dart`: `kesiapanSesiProvider` ditimpa dengan `Completer` yang tidak
pernah diselesaikan tesnya sendiri, dipompa sampai lewat durasi `_utama`, dan lencananya
harus tetap ada dengan opacity 1,0.

### Akar cacatnya: pembuka harus LAPISAN, bukan rute

Dua perbaikan di atas ternyata masih menyisakan sekejap layar putih, dan sebabnya lebih
dalam dari soal timing mana pun. Selama pembuka berupa rute `/pembuka`, urutannya selalu
salah secara struktural:

```
pembuka dilepas  ->  layar berikutnya MULAI dibangun  ->  layar berikutnya tergambar
                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                     sepanjang ini yang terlihat adalah sisa layar sebelumnya,
                     yaitu latar putih polos
```

Tidak ada nilai durasi yang bisa memperbaiki ini, karena masalahnya bukan berapa lama
melainkan siapa duluan. Menyetel `_angkat` jadi 0 milidetik pun tetap menyisakan jeda
membangun dan merasterisasi halaman berikutnya, dan di mesin 2 core dengan CanvasKit,
jeda itu cukup panjang untuk terlihat.

Perbaikannya membalik urutannya: pembuka sekarang **lapisan di atas seluruh aplikasi**,
dipasang lewat `builder` milik `MaterialApp.router` di `app.dart`, bukan rute.

```
Stack
 ├─ ExcludeSemantics(aplikasi sesungguhnya)   <- dibangun & digambar sejak bingkai 1
 └─ PembukaOverlay                            <- menutupinya
```

Akibatnya seluruh 2,1 detik animasi itu bukan lagi waktu tunggu yang terbuang: di
belakang lencana, `MasukScreen` atau `BerandaKlienScreen` sudah selesai dibangun,
di-layout, dan dirasterisasi. Mengangkat lapisannya tinggal memperlihatkan sesuatu yang
sudah jadi, jadi tidak ada lagi jeda di antara keduanya karena tidak ada lagi urutan
"yang satu pergi dulu, baru yang lain datang".

Konsekuensi lain, semuanya ke arah yang benar:

- `Rute.pembuka` dihapus, `initialLocation` kembali ke `Rute.beranda`, dan gerbang
  `if (!pembuka.selesai)` di `redirect` ikut hilang. Router tidak perlu tahu apa-apa lagi
  soal pembuka.
- `refreshListenable` kembali jadi `pendengar` saja, tanpa `Listenable.merge`.
- `StatusPembuka` tidak lagi perlu berupa `ChangeNotifier` (dulu supaya bisa dipasang ke
  GoRouter), sekarang `Notifier<bool>` Riverpod biasa.
- Bilah alamat browser tidak lagi sempat menampilkan `/#/pembuka`, langsung `/#/`.

Dibuktikan lewat dua kasus di `pembuka_overlay_test.dart` yang khusus menjaga cacat ini
tidak kembali: `'halaman berikutnya sudah dibangun di belakang pembuka, bukan sesudahnya'`
dan pasangannya untuk yang sudah masuk. Keduanya memeriksa `MasukScreen`/
`BerandaKlienScreen` sudah ada di pohon widget **di bingkai pertama**, selagi pembukanya
masih menutupi. Kalau suatu saat pembuka dikembalikan menjadi rute, dua kasus itu gagal.

Diperiksa juga secara piksel, dengan merender bingkai-bingkai tepat di tengah peralihan
lalu mengukur kontras isinya:

```
2100ms  kontras konten =   0.0   (lapisan masih menutup penuh, ini masih splash)
2160ms  kontras konten =  37.5   (beranda mulai tersingkap, lencana masih terlihat di atasnya)
2220ms  kontras konten =  95.5   (makin tersingkap, lencana masih ada)
2400ms  kontras konten = 210.8   (beranda utuh, lencana sudah hilang)
```

Yang penting bukan angkanya, melainkan tidak adanya bingkai yang kontrasnya nol SETELAH
animasi selesai. Konten naik terus dari 0 sambil lencananya masih menumpuk di atasnya,
jadi tidak pernah ada bingkai yang isinya putih saja.

### Batas tunggu sesinya sendiri, bukan mengandalkan batas API

Versi pertama perbaikan di atas ternyata belum cukup, dan gejalanya sempat dilaporkan
sebagai "rusak": jeda setelah animasi selesai jadi lama sekali, tidak berhenti sendiri,
dan cuma bergerak lagi setelah tab-nya diklik. Sebabnya bertumpuk dua:

1. `kesiapanSesiProvider` menunggu `pulihkanSesi`, dan itu jatuh ke `KonfigurasiApi.batasWaktu`
   milik `KlienApi`, yaitu **20 detik**. Cocok untuk permintaan biasa yang penggunanya
   sudah tahu sedang menunggu (menekan tombol, melihat putaran pemuatan), tapi di layar
   pembuka penggunanya belum menekan apa pun dan tidak tahu ada permintaan yang sedang
   berjalan sama sekali. Belasan detik diam terbaca sebagai macet.
2. Timer di baliknya, baik `Future.timeout` milik Dart maupun `setTimeout` milik
   browser di baliknya, ditahan (throttled) kalau tab-nya tidak sedang fokus atau
   sedang di latar belakang, sesuatu yang lazim di semua browser modern untuk menghemat
   baterai. Itu sebabnya jedanya terasa **tidak berbatas** dan baru bergerak lagi
   setelah tab-nya diklik: klik itu mengembalikan fokus tab, timer yang tertahan
   akhirnya diizinkan berjalan, dan 20 detik yang tertunda itu langsung habis begitu
   diberi kesempatan.

Perbaikannya `_batasTungguSesi`, 3 detik, ditulis di `pembuka_overlay.dart` sendiri,
lewat `ref.read(kesiapanSesiProvider.future).timeout(_batasTungguSesi, onTimeout: () {})`
sebelum masuk ke `Future.wait`. Panggilan jaringannya sendiri tetap boleh berjalan
sampai batas 20 detiknya di balik layar; yang dibatasi cuma berapa lama LAYAR PEMBUKA
boleh ikut menunggunya. Begitu 3 detik itu habis, pembuka jalan terus seakan belum
masuk. Kalau ternyata sesinya memang ada dan jawaban server akhirnya datang belakangan,
`_PendengarSesi` di `app_router.dart` tetap menyimaknya lewat stream `watchUserAktif()`,
dan router memindahkan dari layar masuk ke beranda sendiri tanpa diminta ulang.

Diuji lewat kasus `'penantian sesi punya batas, tidak menunggu selamanya'`: sesi yang
sama sekali tidak pernah diselesaikan tesnya, dipompa lewat 3,3 detik (batas tunggu
ditambah durasi pudar), dan layar pembuka harus sudah pergi ke layar masuk meski
sesinya tidak pernah siap.

### Yang berubah dari rencana lama

**Pergantian "buaya saja" jadi "buaya di atas motor" belum ada.** Putaran sumbu Y di
langkah 2 adalah tempat yang memang disediakan untuk trik itu, dan momen gambar setipis
garis sudah terjadi di sana. Yang belum ada bahan gambarnya: memisahkan buaya dari
motornya bukan pekerjaan memotong, melainkan menggambar ulang bagian motor yang
tertutup badan buaya. Kalau nanti lapisan PNG-nya jadi, penukarannya tinggal disisipkan
di puncak putaran itu, tanpa mengubah struktur animasinya.

Sama halnya dengan cincin yang tergambar melingkar dan jalan tanah yang tergambar dari
kiri ke kanan: keduanya sudah tercetak di dalam satu berkas lencana, jadi tidak bisa
dianimasikan terpisah sebelum berkasnya dipecah.

**Native splash-nya putih polos, tanpa logo.** Ini menyimpang dari rencana lama dan
alasannya penting. Logo yang diam di tengah lalu tiba-tiba diganti logo yang melompat
masuk dari bawah terbaca sebagai kesalahan gambar, bukan sebagai satu animasi, dan di
web jeda menyalakan engine cukup lama sehingga logo diam itu sempat terbaca. Yang
sebenarnya perlu dihindari adalah kedipan warna, dan itu selesai dengan warna yang sama
di kedua sisi. Karena itu tidak ada paket `flutter_native_splash` yang dipasang; yang
diubah cuma:

- `mobile/web/index.html`, `html, body { background-color: #FFFFFF }`, plus judul tab
  dan deskripsi yang tadinya masih "upnvj_suruh" dan "A new Flutter project"
- `mobile/android/app/src/main/res/drawable-v21/launch_background.xml`, dari
  `?android:colorBackground` jadi putih, supaya di mode gelap jendela peluncur tidak
  muncul hitam lebih dulu

### Berkas yang ditambahkan

```
mobile/assets/logo/lencana.png
mobile/lib/providers/pembuka_providers.dart
mobile/lib/features/pembuka/pembuka_overlay.dart
mobile/lib/features/pembuka/widgets/lencana_logo.dart
mobile/lib/features/pembuka/widgets/teks_melengkung.dart
mobile/test/features/pembuka_overlay_test.dart
```

Dua berkas lama juga berubah:

- `main.dart`, baris yang dulu `await auth.pulihkanSesi()` sebelum `runApp` sekarang
  `wadah.read(kesiapanSesiProvider)`, tanpa `await`.
- `app.dart`, `MaterialApp.router` dapat `builder` yang menumpuk `PembukaOverlay` di atas
  seluruh aplikasi. Ini tempat perbaikan jeda putihnya sebenarnya tinggal.

### Catatan pahit soal iterasi, dan jalan keluarnya

Build release tidak punya hot reload, sekitar 3 menit per perubahan, dan itu menyiksa
untuk menyetel timing animasi. Yang dipakai untuk menyetel geometri teks melengkung
kemarin bukan build web sama sekali, melainkan golden test sementara:
`flutter test <berkas> --update-goldens` merender komposisinya jadi PNG dalam 2 detik,
PNG-nya dibandingkan berdampingan dengan `logo-with-name.jpg`, angkanya disetel, ulangi.
Berkas tesnya sudah dihapus setelah selesai karena golden test rapuh antar versi Flutter
dan butuh font dari `C:\Windows\Fonts`, tapi caranya layak diulang kalau nanti
animasinya disetel lagi.

Untuk menyetel timing (bukan geometri), pilihannya tetap dua dan belum diambil:

- Terima build ulang 3 menit per perubahan, tapi selalu di Brave sendiri
- Pakai `flutter run -d chrome` yang punya hot reload 1 sampai 3 detik, tapi harus lewat
  jendela Brave berprofil sementara yang dibuka otomatis Flutter

### Tone warna tema gelap

Keluhan terpisah dari splash screen, tapi ditemukan dan diperbaiki di sesi yang sama:
tema gelap terlihat murahan, kartu-kartu di beranda nyaris tidak terbedakan dari latar
di belakangnya.

Sebabnya ketahuan lewat golden test sementara yang merender `BerandaKlienScreen` dengan
`AppTheme.gelap()`: `CardThemeData` di `app_theme.dart` tidak pernah mengisi `color`,
jadi jatuh ke bawaan Material 3 untuk `Card` tanpa warna sendiri, yaitu
`surfaceContainerLow`, cuma satu tingkat dari `surface` yang jadi warna latar
`Scaffold`. Di tema terang selisih satu tingkat itu masih kelihatan karena putihnya
tetap terbaca putih; di tema gelap, dua abu-abu gelap yang berdekatan itu sama-sama
terbaca hitam, dan yang tersisa untuk menandai kartunya cuma garis setipis rambut.

Dua perbaikan di `app_theme.dart`:

1. `cardTheme.color` diisi eksplisit ke `skema.surfaceContainerHigh` (dua tingkat dari
   latar, bukan satu), dan `appBarTheme.backgroundColor` dari `skema.surface` jadi
   `skema.surfaceContainer`, supaya bilah atas juga punya batasnya sendiri.
2. Khusus untuk `brightness == Brightness.dark`, seluruh tangga permukaan (`surface`,
   `surfaceContainerLowest` sampai `surfaceContainerHighest`, `onSurface`,
   `onSurfaceVariant`, `outline`, `outlineVariant`) ditimpa dengan navy yang searah
   warna merek (`_biruUpnvj`), bukan abu-abu nyaris tanpa warna bawaan
   `ColorScheme.fromSeed`. Dicoba dulu lewat parameter `dynamicSchemeVariant`
   (`vibrant`, `fidelity`, dll.), tapi Material 3 sengaja menjaga permukaannya
   rendah-chroma di semua varian itu, jadi tidak ada yang menghasilkan navy yang cukup
   terasa; warnanya akhirnya ditulis tangan.

Tema terang tidak disentuh, tingkatannya sudah cukup jelas tanpa perubahan.

## 7. Perkakas yang Terpasang

- Flutter 3.41.2 stable, SDK di `D:\Flutter\flutter`
- Ekstensi Dart dan Flutter sudah terpasang di Antigravity IDE
- Python 3.12 tersedia, dipakai sebagai server statis
- Brave di `C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe`

Kalau suatu saat perlu memaksa `flutter run` memakai Brave, variabelnya `CHROME_EXECUTABLE`,
dan di PowerShell harus ditulis dengan awalan `$env:`. Menulis `set VAR=...` tidak
berpengaruh di PowerShell karena itu membuat variabel PowerShell biasa, bukan environment
variable yang terbaca proses anak.

---

# Sesi 30 Agustus 2026: pengerasan backend dan migrasi sistem desain

Tujuh belas commit, dari `136502b` sampai `19a4363`. Dua pekerjaan besar yang tidak
berhubungan: menutup temuan keamanan di backend, lalu memindahkan DESIGN.md ke kode di
permukaan klien.

Bagian ini ditulis supaya sesi berikutnya tidak mengulang penelusuran yang sama. Yang
dicatat cuma hal yang **tidak bisa disimpulkan dari membaca kode**: alasan di balik angka,
aturan yang harus diikuti pekerjaan berikutnya, keputusan yang sengaja ditunda, dan
keadaan yang tidak terlihat dari commit.

## 8. Pengerasan Keamanan dan Keandalan Backend

Berangkat dari penyisiran menyeluruh atas backend dan aplikasi. Sembilan putaran, satu
temuan per putaran, masing-masing dengan tesnya.

### Yang ditutup

| Temuan | Inti perbaikannya |
|---|---|
| Tidak ada batas laju sama sekali | Dua lapis: per nomor HP untuk pengirim OTP, per pemanggil untuk sisanya |
| Webhook tidak memeriksa jumlah uang | Kurang bayar tidak melunasi; ditandai `JumlahTidakCocok` |
| Foto bukti bisa dipakai ulang lintas order | `Sah()` menuntut nama berkas berawalan id order |
| Foto bukti terbuka bagi siapa pun yang tahu alamatnya | Lewat controller ber-`AksesOrder`, bukan `UseStaticFiles` |
| Pendaftaran membocorkan siapa yang punya akun | 202 tanpa badan untuk semua nomor |
| Runner membaca tawar-menawar sebelum ia bergabung | `PesanTerlihat`, disaring `AcceptedAt` penugasannya |
| Semua daftar tanpa batas | Berhalaman, termasuk chat; aplikasi memakai jendela yang bisa diperlebar |
| Admin tidak punya cara menemukan permintaan Jalur B | `GET /api/admin/orders` |
| Tidak ada satu pun pekerja latar | `Penyapu`: kedaluwarsakan pembayaran, hapus foto yatim |

Ditutup juga yang kecil-kecil: HSTS, `nosniff` global, indeks `Order.Status`, `/health`
yang benar-benar menanyakan basis datanya, `DbUpdateConcurrencyException` jadi 409 bukan
500, indeks unik `(OrderId, GatewayReference)`, `JadwalMulai` tidak boleh di masa lalu,
dan build rilis menolak `API_BASE_URL` non-https.

### Angka dan aturan yang tidak boleh ditebak ulang

Semuanya di `backend/src/UpnvjSuruh.Api/Auth/BatasLaju.cs` dan `Data/BatasHalaman.cs`.

- **Batas laju per nomor HP**: 5 permintaan kode per jam, jeda minimal 60 detik. Kuncinya
  nomor HP, bukan alamat IP, karena nomor itulah yang menerima SMS dan yang tagihannya
  ditanggung mitra. Penyerang berganti IP semudah pindah jaringan.
- **Batas laju per alamat IP sengaja longgar** (100 per 5 menit). Jaringan kampus menaruh
  ratusan orang di balik satu alamat; batas ketat di sana mengunci seisi gedung karena
  ulah satu orang.
- **Webhook pembayaran dikecualikan** dari seluruh batas laju, termasuk jaring umum, dan
  begitu juga `/health`. Kabar yang tertahan di webhook adalah kabar uang masuk;
  pemeriksa kesehatan yang dijawab 429 akan menyimpulkan servernya mati.
- **Halaman**: bawaan 20, maksimal 100. Nilai bawaannya yang paling penting — endpoint
  yang baru berbatas kalau diminta akan tetap tidak berbatas bagi pemanggil yang lupa.
- **Foto yatim dihapus setelah 7 hari.** Longgar dengan sengaja: runner memotret,
  melihat hasilnya, mungkin mengulang, dan pada order terjadwal jeda itu bisa berhari-hari.

### Jebakan yang sudah kena sekali

- **Parameter aksi tidak boleh senama dengan kunci kueri.** `[FromQuery] PermintaanHalaman
  halaman` membuat properti `Halaman` tidak pernah terikat, jadi setiap permintaan
  diam-diam menjawab halaman pertama. Namanya sekarang `permintaan` di semua controller.
- **EF menautkan entitas baru ke koleksi navigasi induknya begitu ia terlacak.** Membaca
  `order.RunnerAssignments.Count` sesudah `Add` lalu menambahinya satu menghasilkan
  kelebihan satu. Pada order satu runner hasilnya kebetulan benar; pada order dua runner
  ordernya berhenti disiarkan setelah runner pertama menerima.
- **Urutan daftar butuh pemecah seri.** `OrderByDescending(CreatedAt)` saja membuat baris
  hilang dari satu halaman lalu muncul dua kali di halaman berikutnya. Semua daftar
  sekarang `.ThenByDescending(o => o.Id)`.

### Tiga cacat yang ditemukan tesnya, bukan audit

1. Order multi-runner tidak pernah bisa terisi penuh (lihat jebakan EF di atas).
2. Nomor halaman tidak pernah terbaca server.
3. Tujuh berkas uji sudah merah sejak sebelum sesi ini: empat backend memakai URL foto
   karangan yang memang ditolak `Sah()`, tiga mobile membuka kamera sungguhan lalu
   menggantung sepuluh menit karena berkas tesnya tidak menyatakan `sumberTiruan`.

### Keputusan yang sengaja tidak diambil

- **Membatalkan order yang lama menunggu pembayaran.** Tempatnya sudah siap di `Penyapu`,
  tapi berapa lama dianggap ditinggalkan dan apakah pantas dibatalkan sendiri tanpa
  memberi tahu pemesannya adalah keputusan produk. Butuh jawaban mitra.
- **Verifikasi jarak tempuh.** Harga dihitung server dan tidak pernah diterima dari
  aplikasi, tapi jaraknya masih diisi klien dan belum diverifikasi siapa pun. Risiko
  pendapatan, bukan bug.
- **Membuang EXIF dari foto bukti.** Koordinat di foto itu sudah diketahui semua orang
  yang boleh membukanya, dan jalur bocornya sudah ditutup. Sebaiknya menunggu pindah ke
  object storage, tempat pemrosesan gambar biasanya sudah tersedia.
- **Jejak audit perubahan status order.** Perubahan peran punya `UserRoleChange`; order
  belum. Ini tabel baru plus penulisan di setiap transisi, jadi pekerjaan tersendiri.
- **`AllowedHosts` masih `*`.** Diisi saat deploy dengan domain sungguhan.

### Strix

Diminta dijalankan, belum dijalankan. Butuh Docker (terpasang v29.3.1 tapi daemonnya mati),
pemasangan lewat `curl -sSL https://strix.ai/install | bash`, dan kunci API LLM berbayar.
Nilainya di sini terbatas: ia menguji aplikasi berjalan lewat HTTP, dan untuk menembus
lapisan auth ia butuh akun beserta token, sementara sisa temuan yang belum ditutup adalah
celah rancangan yang tidak dikenali pemindai.

## 9. Migrasi Sistem Desain dan Permukaan Klien

DESIGN.md sudah menetapkan dunia visualnya berbulan lalu; kodenya tidak pernah menyusul.
Sesi ini memindahkannya, lalu membangun ulang lima layar klien.

### Palet

Navy `#16336B` dengan aksen kuning `#F5A524` diganti hijau lencana `#4B7043` dengan maroon
`#8B2331`. Seluruhnya dicuplik dari `assets/logo/lencana.png`. Aturannya: warna yang tidak
bisa ditunjuk di lencananya tidak masuk.

**Dua suara, dan ini yang paling sering dilanggar tanpa sadar.** Hijau menyatakan apa yang
sudah benar (tahap terlewati, harga disepakati, pilihan yang aktif). Maroon meminta ditekan
(tombol utama, TERIMA, pintu permintaan bebas). Karena itu tombol utama maroon, bukan hijau.

**Aturan terang/gelap yang harus diikuti pekerjaan berikutnya:** bidang berwarna memakai
peran berkekuatan penuh di tema terang, dan peran wadahnya di tema gelap. Di Material, peran
penuh pada tema gelap adalah warna muda yang dibuat untuk teks, bukan untuk isian; hijau muda
selebar layar di tengah malam menyilaukan. Dipakai di kepala beranda dan di pintu permintaan
bebas.

**Tabrakan warna yang muncul dari migrasi ini, semuanya sudah diperbaiki:**

- `mencariRunner` dipindah dari `secondaryContainer` ke `primaryContainer`. Sejak maroon
  jadi sekunder, ia dan `errorContainer` sama-sama merah muda dan tidak terbedakan pada pil
  selebar sebelas piksel. Merah sekarang hanya berarti satu hal: ada yang harus dibayar.
  `dikerjakan` naik ke `primary` penuh, jadi hijau punya dua tingkat yang terbaca berurutan.
- Segmen `SegmentedButton` yang terpilih dihijaukan lewat tema. Bawaan Material memakai
  `secondaryContainer`, jadi setiap pilihan aktif berubah merah muda.
- Pita cara kerja Jalur B dihijaukan. Ia keterangan, bukan peringatan.

Ketiganya lolos dari membaca kode, karena di kodenya tertulis `secondaryContainer` yang
sebelum migrasi memang warna yang benar. Kalau nanti ada layar lain yang belum ditata,
periksa dulu apakah ia memakai peran sekunder untuk sesuatu yang sebenarnya keadaan.

### Skala harga

DESIGN.md mewajibkan harga jadi elemen terbesar di permukaan mana pun yang memuat uang.
Tiga layar melanggarnya. Skala yang sekarang dipakai:

- **20 px / 700** — kartu order di daftar, total di kartu ringkasan harga
- **24 px / 700** (`headlineSmall`/`headlineMedium`) — kepala detail order, layar bayar,
  kartu penawaran
- Harga yang belum ada ditulis **seukuran harga sungguhan**, "Harga menunggu penawaran",
  dan cuma berbeda warnanya. Tidak pernah tanda hubung, nol, atau perkiraan.

### Struktur yang berubah

- **Permukaan klien sekarang punya cangkang dengan bilah bawah** (`CangkangKlien`), dua
  tujuan: Beranda dan Order Saya. Sebelumnya Order Saya cuma ikon di pojok bilah atas.
  Dipasang di `IndexedStack` supaya berpindah tab tidak memuat ulang daftar.
- **Bilah navigasinya satu widget bersama** (`BilahNavigasiBawah`), dipakai cangkang klien
  dan runner. Dua bilah yang berbeda tipis dirasakan pengguna sebagai kegugupan tanpa bisa
  ia tunjuk, dan akun dua peran melihat keduanya dalam hitungan detik.
- **Bilah bawah detail order hanya untuk tindakan.** Keterangan status pindah ke bawah
  linimasa. Slot bilah bawah yang dipakai memajang kalimat menghasilkan teks mengambang di
  tepi layar, jauh dari isi yang ia jelaskan.

### Keputusan yang menyimpang dari DESIGN.md, sengaja

DESIGN.md menulis bilah atas memakai `paper-container` untuk semua layar. Beranda diberi
pengecualian berupa bilah hijau yang menyatu dengan panel sapaan, karena beranda satu-satunya
layar yang tugasnya menyambut, bukan menyelesaikan sesuatu. Layar tugas boleh tenang; layar
sambutan yang tenang cuma terbaca sebagai belum dikerjakan. Kalau kelak diputuskan konsistensi
penuh lebih penting, ini satu baris untuk dikembalikan.

## 10. Cara Memeriksa Desain Tanpa Emulator

Mesin ini tidak punya emulator Android, dan tidak ada alat tangkap layar browser. Cara yang
dipakai sepanjang sesi ini adalah golden sementara, memperluas trik yang dulu dipakai
menyetel geometri teks melengkung splash (bagian 6).

Resepnya:

1. Tulis `test/pratinjau_<layar>_test.dart` sementara.
2. Muat font sungguhan, kalau tidak semua teks jadi kotak:
   `FontLoader('Roboto')..addFont(...File(r'C:\Windows\Fonts\segoeui.ttf')...)`.
3. Atur `tester.view.physicalSize` ke ukuran ponsel (`400 x 860`, atau `400 x 1000` untuk
   layar panjang) dengan `devicePixelRatio = 1`.
4. Navigasi lewat ketukan sungguhan sampai layarnya, lalu
   `expectLater(find.byType(UpnvjSuruhApp), matchesGoldenFile('pratinjau/<nama>.png'))`.
5. Jalankan `flutter test <berkas> --update-goldens`, lalu **lihat PNG-nya**.
6. Perbaiki semua yang terlihat sekaligus, render ulang sekali untuk memastikan, berhenti.
7. Hapus berkas tes dan folder `test/pratinjau` setelah selesai.

Yang perlu diingat saat membacanya:

- **Ikon dan tombol tampil sebagai kotak.** Segoe UI tidak punya glyph Material, dan gaya
  teks yang ditulis tangan tanpa `fontFamily` jatuh ke font tes. Itu artefak, bukan cacat.
  Teks yang lewat `TextTheme` tampil normal.
- Golden ini **sengaja tidak dipertahankan**. Ia rapuh antar versi Flutter, butuh font dari
  `C:\Windows\Fonts`, dan tidak menjaga apa pun; ia alat lihat, bukan tes.

Lima cacat ditemukan lewat cara ini dan tidak akan ditemukan lewat membaca kode: pintu
maroon yang tampil merah muda pucat di tema terang, harga yang terkubur di tabel rincian,
tahap akhir order selesai yang terbaca menggantung, segmen terpilih yang berubah merah, dan
pita keterangan yang berubah jadi peringatan.

## 11. Keadaan Sekarang dan Tempat Melanjutkan

**Kedua suite hijau.** Backend 275 lulus, mobile 271 lulus, `flutter analyze` bersih. Tidak
ada tes merah yang ditinggalkan.

**Alur klien sudah utuh dan sudah ditata**: beranda, form Jalur A dan B, Order Saya, detail
order, layar bayar.

**Yang belum ditata** (warnanya sudah benar karena ikut tema, tata letaknya belum):

1. **Permukaan runner** — Order Masuk beserta kartu siaran dan tombol TERIMA, Order Saya
   runner, lembar penyelesaian. Separuh produk yang belum dapat perhatian sama sekali.
   TERIMA adalah satu-satunya tombol huruf besar di sistem ini.
2. **Chat order** — dipakai klien dan runner.
3. **Layar masuk dan daftar** — kesan pertama, dan satu-satunya layar yang belum pernah
   disentuh.

**Yang belum dikerjakan di backend** sudah didaftar di bagian 8 sebagai keputusan yang
sengaja ditunda.

**Catatan kecil yang mudah terlupa:** `RINGKASAN_PAPARAN.md`, `PRODUCT.md`, dan `DESIGN.md`
masih untracked di git. Bagian 10 di `RINGKASAN_PAPARAN.md` sudah diperbarui dengan hasil
sesi ini, tapi perubahan itu belum ikut ter-commit.
