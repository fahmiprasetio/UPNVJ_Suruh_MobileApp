# Catatan Pengembangan: Menjalankan di Web dan Splash Screen

Berkas ini untuk diri sendiri dan untuk sesi berikutnya. Isinya dua hal: cara menyalakan
proyek supaya bisa dilihat di browser, dan catatan animasi splash screen, termasuk
angka-angka yang tidak boleh ditebak ulang dan bagian mana yang sengaja ditinggal.

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

1. `0,00 - 0,48` lencana naik dari bawah dengan `Curves.elasticOut`, sekalian memudar
   masuk di `0,00 - 0,12`
2. `0,48 - 0,79` berputar satu putaran penuh di sumbu Y dengan perspektif, seperti koin
3. `0,69 - 1,00` teks melengkung tertulis huruf demi huruf dari kiri ke kanan, tiap
   huruf turun ke tempatnya dari arah luar lingkaran

**`_pudar`, 280 milidetik, cuma memudar keluar.** Baru mulai setelah `_utama` selesai
DAN sesi selesai dipulihkan dari server, mana pun yang lebih lambat (lihat subbagian
berikutnya). Sebelum `_pudar` mulai, lencananya diam utuh di layar, bukan kosong.

Jeda dan pudar sengaja ikut di dalam pengendali animasi, bukan `Future.delayed`
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
2. **`_pudar` baru mulai setelah `_utama` selesai DAN `kesiapanSesiProvider` selesai**,
   lewat `Future.wait([?gerakan, ref.read(kesiapanSesiProvider.future)])` di
   `pembuka_screen.dart`. Selama menunggu yang mana pun yang lebih lambat, lencananya
   diam utuh (pengendali `_utama` berhenti di nilai akhirnya begitu `forward()` selesai,
   dan `_pudar` belum digerakkan sama sekali), bukan kosong.

Diuji lewat kasus `'lencana tetap utuh menunggu sesi, tidak memudar sebelum waktunya'` di
`pembuka_screen_test.dart`: `kesiapanSesiProvider` ditimpa dengan `Completer` yang tidak
pernah diselesaikan tesnya sendiri, dipompa sampai lewat durasi `_utama`, dan lencananya
harus tetap ada dengan opacity 1,0.

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

Perbaikannya `_batasTungguSesi`, 3 detik, ditulis di `pembuka_screen.dart` sendiri,
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

### Gerbangnya di router, bukan di layarnya

`Rute.pembuka` adalah `initialLocation`, dan `redirect` menahan seluruh rute lain selama
`StatusPembuka.selesai` masih `false`. Ditaruh di router supaya jalur yang diketik
langsung di bilah alamat browser juga ikut tertahan.

`StatusPembuka` sengaja `ChangeNotifier`, bukan state Riverpod. GoRouter menerima
`Listenable`, dan kalau nilainya jadi state Riverpod, `routerProvider` harus
mengamatinya, sehingga setiap perubahan membangun ulang seluruh GoRouter beserta riwayat
navigasinya. Router cukup dibuat sekali; yang berubah cukup isi objeknya.
`refreshListenable` sekarang `Listenable.merge([pendengar, pembuka])`.

### Berkas yang ditambahkan

```
mobile/assets/logo/lencana.png
mobile/lib/providers/pembuka_providers.dart
mobile/lib/features/pembuka/pembuka_screen.dart
mobile/lib/features/pembuka/widgets/lencana_logo.dart
mobile/lib/features/pembuka/widgets/teks_melengkung.dart
mobile/test/features/pembuka_screen_test.dart
```

`main.dart` juga berubah: baris yang dulu `await auth.pulihkanSesi()` sebelum `runApp`
sekarang `wadah.read(kesiapanSesiProvider)`, tanpa `await`.

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
