import { useLayoutEffect, useRef, useState } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';

import { alamatApi } from '../inti/klien_api';
import { useSesi, usePengguna } from '../auth/sesi';

/**
 * Rangka yang mengelilingi seluruh halaman dashboard.
 *
 * Isinya sedikit dengan sengaja: judul, tautan antarhalaman, siapa yang sedang masuk, dan
 * tombol keluar. Yang paling berguna justru yang terakhir di bilah bawah, yaitu alamat
 * backend yang sedang dituju. Dashboard bisa diarahkan ke server mana pun lewat berkas
 * `.env`, dan sebagian besar waktu yang terbuang saat mengembangkan habis untuk
 * mengherankan data yang tidak muncul, padahal halamannya sedang bicara ke server lain.
 */
export function Rangka() {
  const pengguna = usePengguna();
  const { keluar } = useSesi();
  const lokasi = useLocation();
  const navRef = useRef<HTMLElement>(null);
  const [sorot, setSorot] = useState<{ kiri: number; lebar: number } | null>(null);

  /*
   * Sorotan menu diukur dari DOM, bukan dihitung dari urutan menu: lebar tiap tautan
   * berbeda menurut panjang teksnya dan bisa berubah saat jendela diubah ukurannya.
   * Satu elemen latar dipindahkan dengan transform, jadi saat menu berganti sorotannya
   * bergeser dari posisi lama ke posisi baru, bukan melompat.
   */
  useLayoutEffect(() => {
    const nav = navRef.current;
    if (nav === null) return;

    const ukur = () => {
      const aktif = nav.querySelector<HTMLAnchorElement>('a.aktif');
      if (aktif === null) return;
      const kotakNav = nav.getBoundingClientRect();
      const kotakAktif = aktif.getBoundingClientRect();
      setSorot({ kiri: kotakAktif.left - kotakNav.left, lebar: kotakAktif.width });
    };

    ukur();

    if (typeof ResizeObserver === 'undefined') return;
    const pengamat = new ResizeObserver(ukur);
    pengamat.observe(nav);
    return () => pengamat.disconnect();
  }, [lokasi.pathname]);

  return (
    <div className="rangka">
      <header className="rangka__kepala">
        <div className="rangka__merek">
          <span className="rangka__judul">UPNVJ Suruh</span>
          <span className="rangka__anak-judul">Dashboard Admin</span>
        </div>

        <nav className="rangka__nav" ref={navRef}>
          {sorot !== null && (
            <span
              aria-hidden="true"
              className="rangka__nav-sorot"
              style={{ transform: `translateX(${sorot.kiri}px)`, width: sorot.lebar }}
            />
          )}
          <NavLink to="/order" className={({ isActive }) => (isActive ? 'aktif' : '')}>
            Pantauan Order
          </NavLink>
          <NavLink to="/pengguna" className={({ isActive }) => (isActive ? 'aktif' : '')}>
            Kelola Peran
          </NavLink>
          <NavLink to="/tarif" className={({ isActive }) => (isActive ? 'aktif' : '')}>
            Kelola Tarif
          </NavLink>
          <NavLink to="/pembayaran" className={({ isActive }) => (isActive ? 'aktif' : '')}>
            Rekap Pembayaran
          </NavLink>
        </nav>

        <div className="rangka__akun">
          {pengguna && <span title={pengguna.noHp}>{pengguna.nama}</span>}
          <button type="button" className="tombol tombol--halus" onClick={keluar}>
            Keluar
          </button>
        </div>
      </header>

      <main className="rangka__isi">
        <Outlet />
      </main>

      <footer className="rangka__kaki">
        <span>Backend: {alamatApi}</span>
      </footer>
    </div>
  );
}
