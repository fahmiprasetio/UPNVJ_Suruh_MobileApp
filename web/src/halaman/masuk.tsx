import { useState, type FormEvent } from 'react';
import { Navigate, useLocation } from 'react-router-dom';

import { useSesi } from '../auth/sesi';
import { mintaKode } from '../inti/api_admin';
import { pesanGalat } from '../komponen/keadaan';

/**
 * Masuk ke dashboard: nomor HP, lalu kode yang dikirim ke nomor itu.
 *
 * Dua langkah, bukan satu formulir berisi dua kolom sekaligus. Kolom kode yang sudah
 * terlihat sebelum kodenya diminta membuat orang mengisinya dengan tebakan, lalu
 * menghabiskan jatah percobaan yang dijaga PembatasOtp di backend.
 *
 * Tidak ada pendaftaran di sini, dan itu bukan kelalaian. Akun admin tidak pernah lahir
 * dari layar mana pun: ia dibuat lewat pendaftaran biasa di aplikasi mobile lalu diangkat
 * oleh admin lain (atau oleh `Admin:NomorHpAwal` untuk yang pertama). Menyediakan
 * pendaftaran di dashboard cuma memberi kesan bahwa mendaftar di sini berarti jadi admin.
 */
export function HalamanMasuk() {
  const { keadaan, api, masuk } = useSesi();
  const lokasi = useLocation();

  const [noHp, setNoHp] = useState('');
  const [kode, setKode] = useState('');
  const [tahap, setTahap] = useState<'nomor' | 'kode'>('nomor');
  const [sibuk, setSibuk] = useState(false);
  const [galat, setGalat] = useState<unknown>(null);

  if (keadaan.tahap === 'masuk') {
    const tujuan = (lokasi.state as { tujuan?: string } | null)?.tujuan ?? '/order';
    return <Navigate to={tujuan} replace />;
  }

  async function kirimNomor(peristiwa: FormEvent) {
    peristiwa.preventDefault();
    setSibuk(true);
    setGalat(null);
    try {
      await mintaKode(api, noHp.trim());
      setTahap('kode');
    } catch (salah) {
      setGalat(salah);
    } finally {
      setSibuk(false);
    }
  }

  async function kirimKode(peristiwa: FormEvent) {
    peristiwa.preventDefault();
    setSibuk(true);
    setGalat(null);
    try {
      await masuk(noHp.trim(), kode.trim());
    } catch (salah) {
      setGalat(salah);
    } finally {
      setSibuk(false);
    }
  }

  return (
    <main className="halaman-masuk">
      <div className="kartu kartu--masuk">
        <h1>Dashboard Admin</h1>
        <p className="halaman-masuk__keterangan">UPNVJ Suruh. Khusus akun berperan admin.</p>

        {/* Sengaja memakai kelas netral, bukan `keadaan--galat`. Sesi yang habis
            waktunya bukan kesalahan siapa pun, dan kotak merah di halaman masuk
            terbaca sebagai dashboard yang rusak sendiri. */}
        {keadaan.tahap === 'keluar' && keadaan.ditolak === true && (
          <p className="keadaan" role="status">
            Sesimu sudah berakhir. Masuk lagi, ya, tidak ada data yang hilang.
          </p>
        )}

        {tahap === 'nomor' ? (
          <form onSubmit={kirimNomor}>
            <label htmlFor="noHp">Nomor HP</label>
            <input
              id="noHp"
              name="noHp"
              type="tel"
              inputMode="tel"
              autoComplete="tel"
              maxLength={20}
              required
              value={noHp}
              onChange={(e) => setNoHp(e.target.value)}
              disabled={sibuk}
            />
            <button type="submit" className="tombol" disabled={sibuk || noHp.trim().length === 0}>
              {sibuk ? 'Mengirim...' : 'Kirim kode'}
            </button>
          </form>
        ) : (
          <form onSubmit={kirimKode}>
            <label htmlFor="kode">Kode yang dikirim ke {noHp}</label>
            <input
              id="kode"
              name="kode"
              inputMode="numeric"
              autoComplete="one-time-code"
              maxLength={10}
              required
              autoFocus
              value={kode}
              onChange={(e) => setKode(e.target.value)}
              disabled={sibuk}
            />
            <button type="submit" className="tombol" disabled={sibuk || kode.trim().length === 0}>
              {sibuk ? 'Memeriksa...' : 'Masuk'}
            </button>
            <button
              type="button"
              className="tombol tombol--halus"
              disabled={sibuk}
              onClick={() => {
                setTahap('nomor');
                setKode('');
                setGalat(null);
              }}
            >
              Ganti nomor
            </button>
          </form>
        )}

        {galat !== null && (
          <p className="keadaan keadaan--galat" role="alert">
            {pesanGalat(galat)}
          </p>
        )}

        {import.meta.env.DEV && (
          // Cuma di build pengembangan. Di lingkungan Development backend memakai
          // PengirimOtpLog, yang menulis kodenya ke log server alih-alih mengirim SMS,
          // dan tanpa keterangan ini setiap orang baru akan menunggu SMS yang tidak
          // akan pernah datang.
          <p className="halaman-masuk__catatan">
            Mode pengembangan: kodenya tidak dikirim lewat SMS, melainkan tercetak di
            jendela tempat <code>dotnet run</code> berjalan.
          </p>
        )}
      </div>
    </main>
  );
}
