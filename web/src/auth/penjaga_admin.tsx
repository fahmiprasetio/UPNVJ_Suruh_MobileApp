import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';

import { Memuat } from '../komponen/keadaan';
import { useSesi } from './sesi';

/**
 * Pintu ke seluruh halaman dashboard.
 *
 * PERHATIKAN APA YANG *BUKAN* GUNA BERKAS INI: ini bukan penjagaan keamanan. Yang benar-benar
 * menjaga data ada di backend, di `[Authorize(Roles = Peran.Admin)]` pada setiap controller
 * admin, dan itu tidak bisa ditembus dengan menyunting keadaan di peramban. Yang dikerjakan
 * di sini cuma menghindarkan orang dari layar yang seluruh isinya akan dijawab 403.
 *
 * Perbedaan itu penting untuk dipegang saat menambah halaman baru: halaman yang lupa
 * dibungkus penjaga ini tidak membocorkan apa pun, ia cuma tampil kosong dengan galat.
 * Endpoint yang lupa dijaga di backend adalah cerita yang sama sekali lain.
 */
export function PerluAdmin({ children }: { children: ReactNode }) {
  const { keadaan, keluar } = useSesi();
  const lokasi = useLocation();

  if (keadaan.tahap === 'memeriksa') {
    return <Memuat keterangan="Memeriksa sesi..." />;
  }

  if (keadaan.tahap === 'keluar') {
    // Alamat yang sedang dituju dititipkan, supaya sesudah masuk orangnya kembali ke
    // halaman yang tadi ia buka, bukan selalu ke beranda. Tautan ke satu order tertentu
    // biasanya datang dari orang lain yang sedang bertanya tentang order itu.
    return <Navigate to="/masuk" replace state={{ tujuan: lokasi.pathname + lokasi.search }} />;
  }

  if (!keadaan.pengguna.roles.includes('Admin')) {
    // Sengaja tidak dilempar balik ke layar masuk. Masuk ulang tidak akan menambah peran,
    // jadi yang terjadi cuma orang berputar-putar di antara dua layar tanpa pernah diberi
    // tahu apa yang sebenarnya kurang.
    return (
      <main className="halaman-pesan">
        <h1>Dashboard ini khusus admin</h1>
        <p>
          Akun <strong>{keadaan.pengguna.nama}</strong> masuk sebagai{' '}
          {keadaan.pengguna.roles.join(', ').toLowerCase()}, bukan admin.
        </p>
        <p>
          Kalau ini seharusnya akun admin, minta admin lain menambahkan perannya. Kalau kamu
          runner, pekerjaanmu ada di aplikasi, bukan di sini.
        </p>
        <button type="button" onClick={keluar}>
          Keluar
        </button>
      </main>
    );
  }

  return <>{children}</>;
}
