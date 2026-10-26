import { useState, useRef, useEffect } from 'react';
import { useTema, type AksenTema } from '../inti/tema';

const DAFTAR_AKSEN: { id: AksenTema; label: string; warna: string }[] = [
  { id: 'hijau', label: 'Aloha Emerald (Default)', warna: '#00AA13' },
  { id: 'biru', label: 'Ocean Blue', warna: '#0284C7' },
  { id: 'ungu', label: 'Royal Violet', warna: '#7C3AED' },
  { id: 'jingga', label: 'Sunset Amber', warna: '#D97706' },
  { id: 'mawar', label: 'Rose Pink', warna: '#E11D48' },
];

export function PemilihTema({ ringkas = false }: { ringkas?: boolean }) {
  const { mode, setMode, aksen, setAksen, temaAktif, gantiTemaCepat } = useTema();
  const [bukaMenu, setBukaMenu] = useState(false);
  const kontainerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function klikLuar(e: MouseEvent) {
      if (kontainerRef.current && !kontainerRef.current.contains(e.target as Node)) {
        setBukaMenu(false);
      }
    }
    if (bukaMenu) {
      document.addEventListener('mousedown', klikLuar);
      return () => document.removeEventListener('mousedown', klikLuar);
    }
  }, [bukaMenu]);

  if (ringkas) {
    return (
      <div className="pemilih-tema-ringkas" ref={kontainerRef}>
        <button
          type="button"
          className="tombol-ikon"
          title={`Ganti tema (${temaAktif === 'gelap' ? 'Ke Terang' : 'Ke Gelap'})`}
          onClick={gantiTemaCepat}
        >
          {temaAktif === 'gelap' ? (
            <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="12" cy="12" r="5" />
              <line x1="12" y1="1" x2="12" y2="3" />
              <line x1="12" y1="21" x2="12" y2="23" />
              <line x1="4.22" y1="4.22" x2="5.64" y2="5.64" />
              <line x1="18.36" y1="18.36" x2="19.78" y2="19.78" />
              <line x1="1" y1="12" x2="3" y2="12" />
              <line x1="21" y1="12" x2="23" y2="12" />
              <line x1="4.22" y1="19.78" x2="5.64" y2="18.36" />
              <line x1="18.36" y1="5.64" x2="19.78" y2="4.22" />
            </svg>
          ) : (
            <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
            </svg>
          )}
        </button>

        <button
          type="button"
          className="tombol-ikon"
          title="Pilih palet warna aksen"
          onClick={() => setBukaMenu(!bukaMenu)}
        >
          <span
            className="titik-warna"
            style={{ backgroundColor: DAFTAR_AKSEN.find((a) => a.id === aksen)?.warna }}
          />
        </button>

        {bukaMenu && (
          <div className="menu-layang-tema">
            <p className="menu-layang-tema__judul">Pilih Aksen Warna</p>
            <div className="daftar-titik-aksen">
              {DAFTAR_AKSEN.map((item) => (
                <button
                  key={item.id}
                  type="button"
                  className={`tombol-titik-aksen ${aksen === item.id ? 'aktif' : ''}`}
                  style={{ backgroundColor: item.warna }}
                  title={item.label}
                  onClick={() => {
                    setAksen(item.id);
                    setBukaMenu(false);
                  }}
                />
              ))}
            </div>
          </div>
        )}
      </div>
    );
  }

  return (
    <div className="pemilih-tema">
      <div className="pemilih-tema__baris">
        <span className="pemilih-tema__label">Mode Tampilan</span>
        <div className="pemilih-tema__grup-mode">
          <button
            type="button"
            className={`tombol-mode ${mode === 'terang' ? 'aktif' : ''}`}
            title="Mode Terang (Aloha Clean)"
            onClick={() => setMode('terang')}
          >
            <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="12" cy="12" r="5" />
              <line x1="12" y1="1" x2="12" y2="3" />
              <line x1="12" y1="21" x2="12" y2="23" />
              <line x1="4.22" y1="4.22" x2="5.64" y2="5.64" />
              <line x1="18.36" y1="18.36" x2="19.78" y2="19.78" />
              <line x1="1" y1="12" x2="3" y2="12" />
              <line x1="21" y1="12" x2="23" y2="12" />
              <line x1="4.22" y1="19.78" x2="5.64" y2="18.36" />
              <line x1="18.36" y1="5.64" x2="19.78" y2="4.22" />
            </svg>
            <span>Terang</span>
          </button>
          <button
            type="button"
            className={`tombol-mode ${mode === 'gelap' ? 'aktif' : ''}`}
            title="Mode Gelap (Sleek Dark)"
            onClick={() => setMode('gelap')}
          >
            <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
            </svg>
            <span>Gelap</span>
          </button>
          <button
            type="button"
            className={`tombol-mode ${mode === 'sistem' ? 'aktif' : ''}`}
            title="Ikuti Setelan Sistem"
            onClick={() => setMode('sistem')}
          >
            <svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
              <line x1="8" y1="21" x2="16" y2="21" />
              <line x1="12" y1="17" x2="12" y2="21" />
            </svg>
            <span>Sistem</span>
          </button>
        </div>
      </div>

      <div className="pemilih-tema__baris">
        <span className="pemilih-tema__label">Warna Aksen</span>
        <div className="daftar-titik-aksen">
          {DAFTAR_AKSEN.map((item) => (
            <button
              key={item.id}
              type="button"
              className={`tombol-titik-aksen ${aksen === item.id ? 'aktif' : ''}`}
              style={{ backgroundColor: item.warna }}
              title={item.label}
              onClick={() => setAksen(item.id)}
            />
          ))}
        </div>
      </div>
    </div>
  );
}
