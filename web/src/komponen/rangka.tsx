import { useEffect, useState, useRef } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';

import { useSesi, usePengguna } from '../auth/sesi';
import { PemilihTema } from './pemilih_tema';

const KUNCI_SIDEBAR_CIUT = 'admin_sidebar_ciut';

export function Rangka() {
  const pengguna = usePengguna();
  const { keluar } = useSesi();
  const lokasi = useLocation();

  const [ciut, setCiut] = useState<boolean>(() => {
    return localStorage.getItem(KUNCI_SIDEBAR_CIUT) === 'true';
  });

  const [bukaSidebarMobile, setBukaSidebarMobile] = useState(false);
  const [bukaPengaturan, setBukaPengaturan] = useState(false);
  const modalRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    localStorage.setItem(KUNCI_SIDEBAR_CIUT, String(ciut));
  }, [ciut]);

  // Shortcut keyboard Ctrl+B untuk toggle sidebar
  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'b') {
        e.preventDefault();
        setCiut((prev) => !prev);
      }
    }
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  // Tutup sidebar mobile saat berpindah halaman
  useEffect(() => {
    setBukaSidebarMobile(false);
  }, [lokasi.pathname]);

  // Tutup modal jika klik di luar atau tekan Escape
  useEffect(() => {
    function handleEscape(e: KeyboardEvent) {
      if (e.key === 'Escape') setBukaPengaturan(false);
    }
    if (bukaPengaturan) {
      window.addEventListener('keydown', handleEscape);
      return () => window.removeEventListener('keydown', handleEscape);
    }
  }, [bukaPengaturan]);

  function getInfoHalaman() {
    const path = lokasi.pathname;
    if (path.startsWith('/order/')) {
      return { judul: 'Detail Order', deskripsi: 'Pemeriksaan status, bukti, dan intervensi pesanan' };
    }
    if (path.startsWith('/order')) {
      return { judul: 'Pantauan Order', deskripsi: 'Monitoring pesanan aktif & penanganan order macet' };
    }
    if (path.startsWith('/pengguna')) {
      return { judul: 'Kelola Peran & Akses', deskripsi: 'Pengaturan akun klien, mitra runner, dan admin' };
    }
    if (path.startsWith('/tarif')) {
      return { judul: 'Konfigurasi Tarif', deskripsi: 'Pengaturan batas harga dasar, per-km, dan fee platform' };
    }
    if (path.startsWith('/pembayaran')) {
      return { judul: 'Rekap Pembayaran', deskripsi: 'Laporan transaksi, komisi platform, dan payout runner' };
    }
    return { judul: 'Dashboard Admin', deskripsi: 'Pusat operasional UPNVJ Suruh' };
  }

  const { judul, deskripsi } = getInfoHalaman();

  function inisialNama(nama?: string): string {
    if (!nama) return 'AD';
    const bagian = nama.trim().split(/\s+/);
    const pertama = bagian[0];
    const terakhir = bagian[bagian.length - 1];
    if (bagian.length === 1 && pertama) {
      return pertama.slice(0, 2).toUpperCase();
    }
    if (pertama && terakhir) {
      const huruf1 = pertama[0] ?? '';
      const huruf2 = terakhir[0] ?? '';
      return (huruf1 + huruf2).toUpperCase();
    }
    return 'AD';
  }

  return (
    <div className={`rangka ${ciut ? 'rangka--ciut' : ''}`}>
      {/* Backdrop untuk tampilan mobile */}
      {bukaSidebarMobile && (
        <div
          className="rangka__backdrop"
          onClick={() => setBukaSidebarMobile(false)}
          aria-hidden="true"
        />
      )}

      {/* Sidebar Navigasi Utama */}
      <aside
        className={`rangka__sidebar ${ciut ? 'rangka__sidebar--ciut' : ''} ${
          bukaSidebarMobile ? 'rangka__sidebar--mobile-terbuka' : ''
        }`}
      >
        {/* Kepala Sidebar: Tombol Ciut/Expand di Urutan Pertama */}
        <div className="rangka__sidebar-kepala">
          <button
            type="button"
            className="tombol-ciut-sidebar"
            onClick={() => setCiut(!ciut)}
            title={ciut ? 'Perluas sidebar (Ctrl+B)' : 'Sempitkan sidebar (Ctrl+B)'}
            aria-label={ciut ? 'Perluas sidebar' : 'Sempitkan sidebar'}
          >
            <svg
              className={`ikon-panah-ciut ${ciut ? 'ikon-panah-ciut--putar' : ''}`}
              viewBox="0 0 24 24"
              width="18"
              height="18"
              fill="none"
              stroke="currentColor"
              strokeWidth="2.2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <polyline points="15 18 9 12 15 6" />
            </svg>
          </button>

          <div className="rangka__merek">
            <div className="rangka__logo-badge" title="UPNVJ Suruh">
              <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M12 2L2 7l10 5 10-5-10-5z" />
                <path d="M2 17l10 5 10-5" />
                <path d="M2 12l10 5 10-5" />
              </svg>
            </div>
            {!ciut && (
              <div className="rangka__merek-teks">
                <span className="rangka__judul">UPNVJ Suruh</span>
                <span className="rangka__anak-judul">Portal Admin</span>
              </div>
            )}
          </div>
        </div>

        {/* Daftar Menu Navigasi */}
        <nav className="rangka__navigasi">
          <NavLink
            to="/order"
            className={({ isActive }) => `rangka__tautan ${isActive ? 'aktif' : ''}`}
            title={ciut ? 'Pantauan Order' : undefined}
          >
            <span className="rangka__tautan-ikon">
              <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                <polyline points="14 2 14 8 20 8" />
                <line x1="16" y1="13" x2="8" y2="13" />
                <line x1="16" y1="17" x2="8" y2="17" />
                <polyline points="10 9 9 9 8 9" />
              </svg>
            </span>
            {!ciut && <span className="rangka__tautan-label">Pantauan Order</span>}
          </NavLink>

          <NavLink
            to="/pengguna"
            className={({ isActive }) => `rangka__tautan ${isActive ? 'aktif' : ''}`}
            title={ciut ? 'Kelola Peran' : undefined}
          >
            <span className="rangka__tautan-ikon">
              <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                <circle cx="9" cy="7" r="4" />
                <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                <path d="M16 3.13a4 4 0 0 1 0 7.75" />
              </svg>
            </span>
            {!ciut && <span className="rangka__tautan-label">Kelola Peran</span>}
          </NavLink>

          <NavLink
            to="/tarif"
            className={({ isActive }) => `rangka__tautan ${isActive ? 'aktif' : ''}`}
            title={ciut ? 'Kelola Tarif' : undefined}
          >
            <span className="rangka__tautan-ikon">
              <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <line x1="12" y1="1" x2="12" y2="23" />
                <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
              </svg>
            </span>
            {!ciut && <span className="rangka__tautan-label">Kelola Tarif</span>}
          </NavLink>

          <NavLink
            to="/pembayaran"
            className={({ isActive }) => `rangka__tautan ${isActive ? 'aktif' : ''}`}
            title={ciut ? 'Rekap Pembayaran' : undefined}
          >
            <span className="rangka__tautan-ikon">
              <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <rect x="1" y="4" width="22" height="16" rx="2" ry="2" />
                <line x1="1" y1="10" x2="23" y2="10" />
              </svg>
            </span>
            {!ciut && <span className="rangka__tautan-label">Rekap Pembayaran</span>}
          </NavLink>
        </nav>

        {/* Seksi Bawah Sidebar: Profil & Pengaturan Tema */}
        <div className="rangka__sidebar-kaki">
          <div
            className="rangka__kartu-akun rangka__kartu-akun--interaktif"
            onClick={() => setBukaPengaturan(true)}
            title="Klik untuk Pengaturan Profil & Tema"
            role="button"
            tabIndex={0}
            onKeyDown={(e) => {
              if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                setBukaPengaturan(true);
              }
            }}
          >
            <div className="rangka__avatar" title={pengguna?.nama ?? 'Admin'}>
              {inisialNama(pengguna?.nama)}
            </div>

            {!ciut && (
              <div className="rangka__info-akun">
                <span className="rangka__nama-akun" title={pengguna?.noHp}>
                  {pengguna?.nama ?? 'Admin'}
                </span>
                <span className="rangka__badge-peran">Admin &bull; Pengaturan</span>
              </div>
            )}

            <button
              type="button"
              className="tombol-ikon"
              title="Pengaturan Warna & Tampilan"
              onClick={(e) => {
                e.stopPropagation();
                setBukaPengaturan(true);
              }}
            >
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <circle cx="12" cy="12" r="3" />
                <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z" />
              </svg>
            </button>
          </div>
        </div>
      </aside>

      {/* Konten Utama Aplikasi */}
      <div className="rangka__utama">
        {/* Bilah Atas Konten (Bersih tanpa indikator teknis/API sampah) */}
        <header className="rangka__bilah-atas">
          <div className="rangka__bilah-kiri">
            <button
              type="button"
              className="tombol-menu-mobile"
              onClick={() => setBukaSidebarMobile(true)}
              aria-label="Buka menu navigasi"
            >
              <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <line x1="3" y1="12" x2="21" y2="12" />
                <line x1="3" y1="6" x2="21" y2="6" />
                <line x1="3" y1="18" x2="21" y2="18" />
              </svg>
            </button>

            <div className="rangka__tajuk-halaman">
              <h1 className="rangka__judul-halaman">{judul}</h1>
              <p className="rangka__deskripsi-halaman">{deskripsi}</p>
            </div>
          </div>

          <div className="rangka__bilah-kanan">
            <button
              type="button"
              className="tombol-profil-topbar"
              onClick={() => setBukaPengaturan(true)}
              title="Buka Pengaturan Profil & Tampilan"
            >
              <div className="rangka__avatar rangka__avatar--kecil">
                {inisialNama(pengguna?.nama)}
              </div>
              <span className="rangka__nama-topbar">{pengguna?.nama ?? 'Admin'}</span>
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <circle cx="12" cy="12" r="3" />
                <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z" />
              </svg>
            </button>

            <button
              type="button"
              className="tombol-ikon tombol-logout"
              title="Keluar dari sesi admin"
              onClick={keluar}
            >
              <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
                <polyline points="16 17 21 12 16 7" />
                <line x1="21" y1="12" x2="9" y2="12" />
              </svg>
            </button>
          </div>
        </header>

        {/* Isi Halaman Dinamis */}
        <main className="rangka__isi">
          <Outlet />
        </main>

        {/* Kaki Halaman (Bersih & Profesional) */}
        <footer className="rangka__kaki">
          <span>UPNVJ Suruh &bull; Portal Operasional Layanan Kampus</span>
          <span>UPN &quot;Veteran&quot; Jakarta</span>
        </footer>
      </div>

      {/* Modal / Dialog Pengaturan Profil & Tema Tampilan */}
      {bukaPengaturan && (
        <div
          className="modal-latar"
          onClick={() => setBukaPengaturan(false)}
          role="dialog"
          aria-modal="true"
          aria-labelledby="judul-modal-pengaturan"
        >
          <div
            className="modal-kotak"
            ref={modalRef}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="modal-kotak__kepala">
              <div className="modal-kotak__tajuk">
                <h2 id="judul-modal-pengaturan">Pengaturan Profil & Tampilan</h2>
                <p>Kustomisasi tema warna antarmuka dan info akun admin</p>
              </div>
              <button
                type="button"
                className="tombol-tutup-modal"
                onClick={() => setBukaPengaturan(false)}
                aria-label="Tutup pengaturan"
              >
                &times;
              </button>
            </div>

            <div className="modal-kotak__isi">
              {/* Seksi Profil Pengguna */}
              <div className="seksi-profil-modal">
                <div className="seksi-profil-modal__avatar">
                  {inisialNama(pengguna?.nama)}
                </div>
                <div className="seksi-profil-modal__info">
                  <span className="seksi-profil-modal__nama">{pengguna?.nama ?? 'Admin'}</span>
                  <span className="seksi-profil-modal__hp">{pengguna?.noHp ?? '-'}</span>
                  <span className="seksi-profil-modal__badge">Peran: Administrator</span>
                </div>
              </div>

              {/* Seksi Pemilih Warna & Mode Tampilan */}
              <div className="seksi-tema-modal">
                <h3 className="seksi-tema-modal__judul">Tema & Warna Antarmuka</h3>
                <p className="seksi-tema-modal__deskripsi">
                  Pilih mode gelap/terang serta aksen warna favorit Anda:
                </p>
                <PemilihTema ringkas={false} />
              </div>
            </div>

            <div className="modal-kotak__kaki">
              <button
                type="button"
                className="tombol tombol--halus"
                onClick={() => setBukaPengaturan(false)}
              >
                Selesai
              </button>
              <button
                type="button"
                className="tombol tombol--bahaya"
                onClick={keluar}
              >
                Keluar dari Akun
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
