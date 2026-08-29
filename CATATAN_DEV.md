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
rentang tulisan 107 derajat. Yang dipakai di kode 1,34, bukan 1,25, karena Roboto lebih
lebar dari huruf perancang logonya; busur yang lebih besar memuat lebar yang sama dalam
sudut yang lebih kecil, jadi rentangnya kembali ke 107 derajat tanpa mengecilkan huruf.

### Urutan animasi yang jalan sekarang

Total 2,75 detik, latar putih polos, satu `AnimationController` dengan empat `Interval`.

1. `0,00 - 0,40` lencana naik dari bawah dengan `Curves.elasticOut`, sekalian memudar
   masuk di `0,00 - 0,10`
2. `0,40 - 0,66` berputar satu putaran penuh di sumbu Y dengan perspektif, seperti koin
3. `0,62 - 0,87` teks melengkung tertulis huruf demi huruf dari kiri ke kanan, tiap
   huruf turun ke tempatnya dari arah luar lingkaran
4. `0,87 - 1,00` diam

Jeda diam di akhir sengaja ikut di dalam pengendali animasi, bukan `Future.delayed`
setelahnya. Timer yang menggantung di luar pengendali tidak terhitung oleh
`pumpAndSettle`, jadi tes layar selesai sebelum perpindahannya terjadi lalu gagal dengan
keluhan timer yang masih hidup.

Kalau perangkat mematikan animasi di setelan aksesibilitas, seluruh 2,75 detik itu
dilewati dan aplikasi langsung membuka layar berikutnya.

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

### Yang bisa dikerjakan berikutnya

`main()` masih memulihkan sesi sebelum `runApp`, jadi pengguna yang sudah masuk menunggu
satu panggilan HTTP di layar putih, baru animasi 2,75 detiknya jalan. Sekarang gerbang
pembukanya sudah ada, alasan lama untuk urutan itu tidak berlaku lagi: layar dalam tidak
mungkin terbuka selama pembuka belum selesai, jadi `pulihkanSesi` bisa dipindah ke
belakang `runApp` supaya berjalan berbarengan dengan animasinya. Belum dikerjakan karena
di luar lingkup pekerjaan splash screen.

## 7. Perkakas yang Terpasang

- Flutter 3.41.2 stable, SDK di `D:\Flutter\flutter`
- Ekstensi Dart dan Flutter sudah terpasang di Antigravity IDE
- Python 3.12 tersedia, dipakai sebagai server statis
- Brave di `C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe`

Kalau suatu saat perlu memaksa `flutter run` memakai Brave, variabelnya `CHROME_EXECUTABLE`,
dan di PowerShell harus ditulis dengan awalan `$env:`. Menulis `set VAR=...` tidak
berpengaruh di PowerShell karena itu membuat variabel PowerShell biasa, bukan environment
variable yang terbaca proses anak.
