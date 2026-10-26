import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';

export type ModeTema = 'terang' | 'gelap' | 'sistem';
export type AksenTema = 'hijau' | 'biru' | 'ungu' | 'jingga' | 'mawar';

export interface KonteksTemaNilai {
  mode: ModeTema;
  setMode: (mode: ModeTema) => void;
  aksen: AksenTema;
  setAksen: (aksen: AksenTema) => void;
  temaAktif: 'terang' | 'gelap';
  gantiTemaCepat: () => void;
}

const KonteksTema = createContext<KonteksTemaNilai | null>(null);

const KUNCI_MODE = 'admin_mode_tema';
const KUNCI_AKSEN = 'admin_aksen_tema';

export function PenyediaTema({ children }: { children: ReactNode }) {
  const [mode, setModeState] = useState<ModeTema>(() => {
    const simpanan = localStorage.getItem(KUNCI_MODE);
    if (simpanan === 'terang' || simpanan === 'gelap' || simpanan === 'sistem') {
      return simpanan;
    }
    // Bawaan awal terang agar fresh, modern, dan tidak terjebak gelap terus-menerus
    return 'terang';
  });

  const [aksen, setAksenState] = useState<AksenTema>(() => {
    const simpanan = localStorage.getItem(KUNCI_AKSEN);
    if (
      simpanan === 'hijau' ||
      simpanan === 'biru' ||
      simpanan === 'ungu' ||
      simpanan === 'jingga' ||
      simpanan === 'mawar'
    ) {
      return simpanan;
    }
    return 'hijau';
  });

  const [sistemGelap, setSistemGelap] = useState<boolean>(() => {
    if (typeof window === 'undefined') return false;
    return window.matchMedia('(prefers-color-scheme: dark)').matches;
  });

  useEffect(() => {
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const handler = (e: MediaQueryListEvent) => setSistemGelap(e.matches);
    mq.addEventListener('change', handler);
    return () => mq.removeEventListener('change', handler);
  }, []);

  const temaAktif: 'terang' | 'gelap' =
    mode === 'sistem' ? (sistemGelap ? 'gelap' : 'terang') : mode;

  useEffect(() => {
    const root = document.documentElement;
    root.setAttribute('data-tema', temaAktif);
    root.setAttribute('data-aksen', aksen);
    root.style.colorScheme = temaAktif;
  }, [temaAktif, aksen]);

  function setMode(baru: ModeTema) {
    setModeState(baru);
    localStorage.setItem(KUNCI_MODE, baru);
  }

  function setAksen(baru: AksenTema) {
    setAksenState(baru);
    localStorage.setItem(KUNCI_AKSEN, baru);
  }

  function gantiTemaCepat() {
    // Tombol saklar instan terang <-> gelap
    const berikutnya: ModeTema = temaAktif === 'gelap' ? 'terang' : 'gelap';
    setMode(berikutnya);
  }

  return (
    <KonteksTema.Provider
      value={{
        mode,
        setMode,
        aksen,
        setAksen,
        temaAktif,
        gantiTemaCepat,
      }}
    >
      {children}
    </KonteksTema.Provider>
  );
}

export function useTema(): KonteksTemaNilai {
  const ctx = useContext(KonteksTema);
  if (!ctx) {
    throw new Error('useTema harus dipakai di dalam PenyediaTema.');
  }
  return ctx;
}
