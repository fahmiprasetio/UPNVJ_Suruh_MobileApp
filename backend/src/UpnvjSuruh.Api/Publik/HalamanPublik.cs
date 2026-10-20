using System.Net;

namespace UpnvjSuruh.Api.Publik;

/// <summary>
/// Isi tiga halaman publik: kebijakan privasi, syarat layanan, dan penghapusan akun.
/// </summary>
/// <remarks>
/// Halaman publik dibutuhkan Google Play (URL kebijakan privasi dan URL penghapusan akun harus
/// bisa dibuka tanpa memasang atau masuk ke aplikasi), dan lebih dari itu: orang yang sudah
/// tidak punya aplikasinya tetap berhak membaca apa yang terjadi pada datanya dan menghapus
/// akunnya.
///
/// Isinya ditulis sebagai teks biasa di sini, bukan dimuat dari berkas, supaya ikut diperiksa
/// kompilator dan ikut diuji. Dan isinya sengaja diulang apa adanya di layar aplikasi
/// (<c>kebijakan_privasi_screen.dart</c>, <c>syarat_ketentuan_screen.dart</c>) dan di draf
/// formulir Data Safety: tiga tempat yang menjelaskan hal yang sama dengan kata yang berbeda
/// adalah tiga tempat yang akhirnya saling bertentangan. Kalau salah satunya diubah, ubah
/// ketiganya.
///
/// Tidak ada klaim tentang penyedia yang belum aktif. Penyedia pengirim kode OTP sengaja
/// tidak disebut namanya, dan lama penyimpanan catatan transaksi sengaja tidak disebut
/// angkanya: yang pertama belum diputuskan mitra, yang kedua belum ditegakkan apa pun di kode.
/// </remarks>
public static class HalamanPublik
{
    /// <summary>Tanggal terakhir isi halaman ini diubah. Ikut diubah bersama isinya.</summary>
    public const string DiperbaruiPada = "20 Oktober 2026";

    public static string Privasi(string? kontak) => Bungkus(
        "Kebijakan Privasi",
        $"""
        <p class="muda">Terakhir diperbarui: {DiperbaruiPada}</p>

        <p>UPNVJ Suruh adalah layanan jasa serabutan mahasiswa di lingkungan Universitas Pembangunan
        Nasional "Veteran" Jakarta (UPNVJ), di bawah Bidang Ekonomi Kreatif. Aplikasi ini
        dikembangkan sebagai proyek tugas akhir (Capstone Project) mahasiswa Fakultas Ilmu Komputer
        UPNVJ bersama mitra. Halaman ini menjelaskan data apa yang kami kumpulkan, untuk apa, dengan
        siapa dibagikan, dan bagaimana kamu bisa menghapusnya.</p>

        <h2>1. Data yang kami kumpulkan</h2>
        <ul>
          <li><b>Akun:</b> nama, nomor HP, alamat bawaan (opsional), dan password (opsional; yang
          disimpan hanya sidik hash-nya, bukan passwordnya).</li>
          <li><b>Pesanan:</b> jenis layanan, deskripsi pekerjaan, alamat jemput dan tujuan, jarak,
          dan jadwal, beserta harga dan statusnya.</li>
          <li><b>Percakapan:</b> pesan teks yang kamu kirim di chat pesanan.</li>
          <li><b>Bukti penyelesaian:</b> foto serah terima beserta catatannya, yang diunggah
          runner.</li>
          <li><b>Pembayaran:</b> jumlah tagihan, nomor referensi transaksi, status, dan waktunya.
          Kami tidak menerima dan tidak menyimpan nomor kartu atau akun dompet digitalmu; itu
          dimasukkan langsung di halaman pembayaran penyedia pembayaran.</li>
          <li><b>Lokasi:</b> hanya saat kamu menekan "Pakai lokasi saat ini" atau memilih titik di
          peta. Koordinatnya dipakai untuk menentukan alamat dan jarak rute. Yang kami simpan di
          pesananmu adalah alamat berupa teks dan jaraknya, bukan koordinat perangkatmu.</li>
          <li><b>Perangkat:</b> token notifikasi (Firebase Cloud Messaging) supaya notifikasi
          sampai ke ponselmu.</li>
        </ul>
        <p>Kami tidak memakai pelacak iklan, analitik pihak ketiga, maupun layanan pelaporan
        kerusakan aplikasi.</p>

        <h2>2. Untuk apa data dipakai</h2>
        <p>Untuk memverifikasi akunmu lewat kode OTP, memproses dan menyiarkan pesanan, menerima
        pembayaran, mempertemukan klien dengan runner, mengirim notifikasi tentang pesananmu,
        membantu bila ada kendala, serta mencegah penyalahgunaan. Kami tidak menjual data pribadi
        dan tidak memakainya untuk iklan.</p>

        <h2>3. Dengan siapa data dibagikan</h2>
        <ul>
          <li><b>Runner yang menerima pesananmu:</b> nama, alamat pesanan, dan nomor HP yang
          diperlukan untuk berkoordinasi selama pesanan berjalan. Runner yang tawarannya tidak
          dipilih atau pesanannya sudah selesai tidak lagi dapat membuka rincian alamatmu.
          Sebaliknya, kamu melihat nama dan nomor HP runner yang mengerjakan pesananmu.</li>
          <li><b>Midtrans (penyedia pembayaran):</b> nomor referensi pesanan dan jumlah tagihan.
          Data metode pembayaranmu diberikan langsung kepada Midtrans, bukan kepada kami.</li>
          <li><b>Google Firebase Cloud Messaging:</b> token perangkat dan isi notifikasi, untuk
          menyampaikan notifikasi ke ponselmu.</li>
          <li><b>OpenStreetMap (pencarian alamat, rute, dan tampilan peta):</b> teks pencarian
          alamat, koordinat titik yang kamu pilih, dan alamat IP perangkatmu, untuk menampilkan
          peta, menemukan alamat, dan menghitung jarak.</li>
          <li><b>Penyedia layanan pesan pengirim kode OTP:</b> nomor HP tujuan dan isi kode.</li>
          <li><b>Admin UPNVJ Suruh:</b> memantau pesanan, pembayaran, dan membantu kendala.</li>
        </ul>

        <h2>4. Keamanan</h2>
        <p>Data dikirim lewat sambungan terenkripsi (HTTPS). Password disimpan sebagai hash,
        tidak dapat dibaca siapa pun, termasuk tim kami. Token sesi disimpan di penyimpanan aman
        perangkat. Foto bukti diproses di server untuk membuang metadata EXIF, termasuk titik GPS
        kamera, sebelum disimpan. Permintaan kode OTP dan perubahan data penting dibatasi lajunya
        untuk mencegah penyalahgunaan.</p>

        <h2 id="hapus">5. Menghapus akun dan data</h2>
        <p>Kamu bisa menghapus akunmu sendiri kapan saja: di aplikasi lewat menu Pengaturan, atau
        lewat halaman <a href="/hapus-akun">/hapus-akun</a> tanpa perlu memasang aplikasi. Kami
        meminta kode OTP ke nomor HP-mu untuk memastikan itu benar kamu.</p>
        <p><b>Yang dihapus:</b> nama, nomor HP, alamat bawaan, dan password; perangkat notifikasi;
        isi pesan yang kamu kirim di percakapan pesanan; catatan pada penawaran runner; serta
        deskripsi, alamat jemput dan tujuan, dan catatan serah terima pada pesanan yang kamu buat
        sebagai klien. Akses ke akunmu langsung ditutup, termasuk sesi yang sedang berjalan.</p>
        <p><b>Yang dipertahankan, tanpa lagi terhubung ke identitasmu:</b> catatan transaksi,
        yaitu kode pesanan, jenis layanan, status, harga, waktu, pembayaran dan pengembaliannya,
        bayaran runner, jejak audit, dan foto bukti serah terima yang diunggah runner (metadata
        lokasinya sudah dibuang). Catatan ini diperlukan untuk pembukuan dan penyelesaian
        sengketa, dan namamu pada catatan itu diganti "Akun dihapus". Lama penyimpanannya
        ditetapkan mitra.</p>
        <p><b>Kapan penghapusan ditunda:</b> bila akunmu masih punya pesanan yang berjalan,
        pengembalian dana atau pembayaran yang sedang ditinjau, atau (untuk runner) pekerjaan aktif
        dan bayaran yang belum dicairkan, penghapusan ditolak beserta alasannya. Selesaikan dulu,
        lalu coba lagi. Akun admin dan akun yang sedang ditangguhkan dihapus lewat admin.</p>

        <h2>6. Hakmu</h2>
        <p>Kamu dapat memperbarui nama, alamat bawaan, nomor HP (dengan verifikasi kode OTP), dan
        password kapan saja lewat menu Profil dan Pengaturan, serta menghapus akunmu seperti di
        atas.</p>

        <h2>7. Anak-anak</h2>
        <p>Layanan ini ditujukan bagi mahasiswa dan tidak ditujukan bagi anak-anak.</p>

        <h2>8. Perubahan dan kontak</h2>
        <p>Bila kebijakan ini berubah, tanggal pembaruan di atas ikut diubah dan perubahan penting
        diumumkan di aplikasi. {KalimatKontak(kontak)}</p>
        """);

    public static string Syarat(string? kontak) => Bungkus(
        "Syarat & Ketentuan Layanan",
        $"""
        <p class="muda">Terakhir diperbarui: {DiperbaruiPada}</p>

        <h2>1. Ketentuan umum</h2>
        <p>UPNVJ Suruh adalah platform perantara jasa serabutan mahasiswa di lingkungan Universitas
        Pembangunan Nasional "Veteran" Jakarta, di bawah naungan Bidang Ekonomi Kreatif. Pengguna
        terdiri atas Klien (pemesan jasa) dan Runner (mitra pelaksana yang terdaftar dan
        terverifikasi).</p>

        <h2>2. Pemesanan dan pembayaran</h2>
        <p>Klien wajib memberikan alamat, nomor kontak, dan deskripsi pekerjaan yang jelas dan
        benar. Pembayaran dilakukan melalui halaman Midtrans. Pesanan Jalur A baru disiarkan ke
        runner setelah pembayaran terverifikasi. Pada Jalur B, pembayaran dilakukan setelah klien
        menyetujui salah satu penawaran harga dari runner.</p>

        <h2>3. Larangan dan batasan jasa</h2>
        <p>Klien dilarang memesan pengantaran atau pembelian barang yang melanggar hukum dan tata
        tertib kampus, termasuk minuman beralkohol, rokok atau vape ilegal, narkotika, obat-obatan
        terlarang, senjata tajam, dan barang berbahaya lainnya. Runner berhak membatalkan pesanan
        bila menemukan indikasi pelanggaran ini.</p>

        <h2>4. Pelaksanaan dan bukti selesai</h2>
        <p>Runner menyelesaikan pesanan sesuai kesepakatan waktu dan alamat. Pesanan baru dapat
        ditandai selesai setelah runner melampirkan foto bukti serah terima beserta catatannya.</p>

        <h2>5. Pembatalan dan pengembalian dana</h2>
        <p>Pesanan yang belum dibayar dapat dibatalkan klien kapan saja. Untuk pesanan yang sudah
        dibayar, pembatalan dilakukan lewat admin, yang sekaligus mencatat pengembalian dana. Dana
        dikembalikan melalui penyedia pembayaran sesuai ketentuannya.</p>

        <h2>6. Akun</h2>
        <p>Satu nomor HP untuk satu akun. Akun dapat ditangguhkan bila ada penyalahgunaan, dan
        pemiliknya dapat menghapus akunnya sendiri sesuai
        <a href="/kebijakan-privasi">Kebijakan Privasi</a>.</p>

        <h2>7. Kontak</h2>
        <p>{KalimatKontak(kontak)}</p>
        """);

    public static string HapusAkun(string? kontak) => Bungkus(
        "Hapus Akun UPNVJ Suruh",
        $$"""
        <p>Halaman ini untuk menghapus akun UPNVJ Suruh beserta data pribadimu, tanpa perlu
        memasang aplikasi. Penjelasan lengkap tentang apa yang dihapus dan apa yang dipertahankan
        ada di <a href="/kebijakan-privasi#hapus">Kebijakan Privasi</a>.</p>

        <div class="kartu">
          <b>Sebelum melanjutkan:</b> akun dan datamu akan dihapus dan <b>tidak bisa dikembalikan</b>.
          Penghapusan ditolak bila masih ada pesanan yang berjalan, pengembalian dana yang belum
          selesai, atau (bagi runner) pekerjaan aktif dan bayaran yang belum dicairkan.
        </div>

        <form id="langkah1" autocomplete="off">
          <label for="noHp">Nomor HP akunmu</label>
          <input id="noHp" name="noHp" inputmode="numeric" maxlength="20" placeholder="08xxxxxxxxxx" required>
          <label class="baris">
            <input id="paham" type="checkbox" required>
            <span>Saya paham akun dan data saya akan dihapus permanen.</span>
          </label>
          <button type="submit">Kirim kode ke nomor ini</button>
        </form>

        <form id="langkah2" autocomplete="off" hidden>
          <label for="kode">Kode 6 angka yang dikirim ke nomormu</label>
          <input id="kode" name="kode" inputmode="numeric" maxlength="6" pattern="\d{6}" required>
          <button type="submit" class="bahaya">Hapus akun saya</button>
        </form>

        <div id="pesan" role="status" aria-live="polite"></div>

        <p class="muda">{{KalimatKontak(kontak)}}</p>

        <script>
        (function () {
          var el = function (id) { return document.getElementById(id); };
          var pesan = el('pesan');
          function tampil(teks, galat) {
            pesan.textContent = teks;
            pesan.className = galat ? 'galat' : 'ok';
          }
          function kirim(url, badan) {
            return fetch(url, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify(badan)
            }).then(function (r) {
              return r.json().catch(function () { return null; }).then(function (j) {
                return { status: r.status, badan: j };
              });
            });
          }
          function detail(j, cadangan) {
            return j && j.detail ? j.detail : cadangan;
          }

          el('langkah1').addEventListener('submit', function (e) {
            e.preventDefault();
            tampil('Mengirim kode...', false);
            kirim('/api/auth/minta-kode', { noHp: el('noHp').value.trim() }).then(function (h) {
              if (h.status === 202) {
                tampil('Kalau nomor itu terdaftar, kode sudah dikirim. Masukkan kodenya di bawah.', false);
                el('langkah2').hidden = false;
                el('kode').focus();
              } else if (h.status === 429) {
                tampil(detail(h.badan, 'Terlalu sering meminta kode. Tunggu sebentar.'), true);
              } else if (h.status === 400) {
                tampil('Nomor HP tidak valid. Gunakan format 08xxxxxxxxxx.', true);
              } else {
                tampil('Gagal mengirim kode. Coba lagi sebentar lagi.', true);
              }
            }).catch(function () { tampil('Tidak bisa menghubungi server. Periksa sambunganmu.', true); });
          });

          el('langkah2').addEventListener('submit', function (e) {
            e.preventDefault();
            tampil('Memproses...', false);
            kirim('/api/akun/hapus', { noHp: el('noHp').value.trim(), kode: el('kode').value.trim() })
              .then(function (h) {
                if (h.status === 204) {
                  el('langkah1').hidden = true;
                  el('langkah2').hidden = true;
                  tampil('Akunmu sudah dihapus. Terima kasih sudah memakai UPNVJ Suruh.', false);
                } else if (h.status === 409) {
                  tampil(detail(h.badan, 'Akun belum bisa dihapus saat ini.'), true);
                } else if (h.status === 401) {
                  tampil('Nomor atau kode tidak cocok. Minta kode baru lalu coba lagi.', true);
                } else if (h.status === 400) {
                  tampil('Kode harus 6 angka.', true);
                } else if (h.status === 429) {
                  tampil(detail(h.badan, 'Terlalu banyak percobaan. Tunggu sebentar.'), true);
                } else {
                  tampil('Gagal menghapus akun. Coba lagi sebentar lagi.', true);
                }
              }).catch(function () { tampil('Tidak bisa menghubungi server. Periksa sambunganmu.', true); });
          });
        })();
        </script>
        """);

    /// <summary>
    /// Kalimat kontak. Nomor atau kanal bantuan dibaca dari konfigurasi (<c>Publik:KontakBantuan</c>),
    /// bukan ditulis di sini: itu keputusan mitra dan bisa berubah tanpa membangun ulang. Kalau
    /// belum diisi, kalimatnya mengarah ke satu-satunya kanal yang pasti ada, yaitu Pusat
    /// Bantuan di aplikasi.
    /// </summary>
    private static string KalimatKontak(string? kontak) =>
        string.IsNullOrWhiteSpace(kontak)
            ? "Pertanyaan tentang data dan privasi dapat disampaikan lewat menu Pusat Bantuan di aplikasi."
            : $"Pertanyaan tentang data dan privasi dapat disampaikan lewat {WebUtility.HtmlEncode(kontak.Trim())}.";

    private static string Bungkus(string judul, string isi) =>
        $$"""
        <!doctype html>
        <html lang="id">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>{{judul}} - UPNVJ Suruh</title>
          <style>
            :root { color-scheme: light dark; --hijau: #00aa13; --maroon: #8b2331; }
            body { font: 16px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
                   margin: 0; background: Canvas; color: CanvasText; }
            header { background: var(--hijau); color: #fff; padding: 20px 16px; }
            header b { font-size: 18px; }
            main { max-width: 720px; margin: 0 auto; padding: 16px; }
            h1 { font-size: 24px; margin: 8px 0 4px; }
            h2 { font-size: 18px; margin: 28px 0 6px; }
            a { color: var(--hijau); }
            .muda { opacity: .7; font-size: 14px; }
            .kartu { border: 1px solid #c8d4c9; border-radius: 12px; padding: 12px 14px; margin: 16px 0; }
            form { display: grid; gap: 10px; margin: 16px 0; }
            input[type=text], input:not([type]), input[inputmode] { font: inherit; padding: 10px 12px;
                   border: 1px solid #99a99b; border-radius: 10px; background: Field; color: FieldText; }
            label.baris { display: flex; gap: 8px; align-items: flex-start; }
            button { font: inherit; font-weight: 600; padding: 12px 16px; border: 0; border-radius: 12px;
                     background: var(--hijau); color: #fff; cursor: pointer; }
            button.bahaya { background: var(--maroon); }
            #pesan { white-space: pre-line; margin: 12px 0; padding: 0; }
            #pesan.ok, #pesan.galat { padding: 10px 12px; border-radius: 10px; }
            #pesan.ok { background: #e8f5e9; color: #14532d; }
            #pesan.galat { background: #fdecea; color: #7a1c1c; }
          </style>
        </head>
        <body>
          <header><b>UPNVJ Suruh</b></header>
          <main>
            <h1>{{judul}}</h1>
            {{isi}}
          </main>
        </body>
        </html>
        """;
}
