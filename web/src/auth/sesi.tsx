import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from 'react';

import { masuk as masukApi, saya as sayaApi } from '../inti/api_admin';
import { GalatTidakBerwenang } from '../inti/galat_api';
import { KlienApi } from '../inti/klien_api';
import type { Pengguna } from '../inti/tipe';
import { bacaToken, hapusToken, simpanToken } from './penyimpanan_token';

/**
 * Siapa yang sedang memakai dashboard, dan satu klien API yang sudah membawa tokennya.
 *
 * Keduanya disatukan di sini dengan sengaja. Kalau token disimpan di satu tempat dan klien
 * API dibuat di tempat lain, akan selalu ada layar yang memegang klien API dari sebelum
 * seseorang keluar, dan layar itu tetap bisa mengambil data atas nama akun yang sudah
 * ditinggalkan.
 */

type KeadaanSesi =
  /** Belum tahu: ada token tersimpan, dan pemiliknya sedang ditanyakan ke server. */
  | { tahap: 'memeriksa' }
  | { tahap: 'keluar' }
  | { tahap: 'masuk'; pengguna: Pengguna };

interface IsiSesi {
  keadaan: KeadaanSesi;
  api: KlienApi;
  masuk(noHp: string, kode: string): Promise<Pengguna>;
  keluar(): void;
}

const KonteksSesi = createContext<IsiSesi | null>(null);

export function PenyediaSesi({
  children,
  buatKlien,
}: {
  children: ReactNode;
  /** Disediakan tes untuk menembus jaringan. Pemakaian biasa tidak mengisinya. */
  buatKlien?: (bacaToken: () => string | null) => KlienApi;
}) {
  const [token, setToken] = useState<string | null>(() => bacaToken());
  const [keadaan, setKeadaan] = useState<KeadaanSesi>(() =>
    bacaToken() ? { tahap: 'memeriksa' } : { tahap: 'keluar' },
  );

  // Token dibaca lewat ref, bukan lewat closure atas state.
  //
  // KlienApi dibuat sekali dan dipakai seumur halaman; kalau ia menangkap nilai state,
  // permintaan sesudah masuk masih akan berangkat membawa token yang lama (yaitu tidak
  // ada), dan yang terlihat adalah "sudah masuk tapi semuanya 401".
  const tokenRef = useRef(token);
  tokenRef.current = token;

  const api = useMemo(() => {
    const baca = () => tokenRef.current;
    return buatKlien ? buatKlien(baca) : new KlienApi(baca);
  }, [buatKlien]);

  const keluar = useCallback(() => {
    hapusToken();
    setToken(null);
    setKeadaan({ tahap: 'keluar' });
  }, []);

  // Token yang tersimpan diperiksa ke server, tidak dipercaya begitu saja.
  //
  // Data pengguna ikut disimpan di peramban akan lebih cepat, dan salah: peran admin yang
  // sudah dicabut masih akan terlihat ada, dan orangnya baru tahu setelah menekan sesuatu
  // yang ditolak. Satu permintaan saat dashboard dibuka jauh lebih murah daripada itu.
  useEffect(() => {
    if (keadaan.tahap !== 'memeriksa') return;

    const kendali = new AbortController();
    sayaApi(api, kendali.signal)
      .then((pengguna) => setKeadaan({ tahap: 'masuk', pengguna }))
      .catch((galat) => {
        // Cuma token yang memang tidak berlaku yang mengeluarkan orang. Server yang
        // sedang mati atau jaringan yang putus bukan alasan menghapus token: kalau
        // dihapus, admin harus meminta kode SMS baru hanya karena backend sempat
        // direstart.
        if (galat instanceof GalatTidakBerwenang) {
          keluar();
        } else {
          setKeadaan({ tahap: 'keluar' });
        }
      });

    return () => kendali.abort();
  }, [api, keadaan.tahap, keluar]);

  const masuk = useCallback(
    async (noHp: string, kode: string) => {
      const hasil = await masukApi(api, noHp, kode);
      simpanToken(hasil.token);
      tokenRef.current = hasil.token;
      setToken(hasil.token);
      setKeadaan({ tahap: 'masuk', pengguna: hasil.user });
      return hasil.user;
    },
    [api],
  );

  const isi = useMemo<IsiSesi>(() => ({ keadaan, api, masuk, keluar }), [keadaan, api, masuk, keluar]);

  return <KonteksSesi.Provider value={isi}>{children}</KonteksSesi.Provider>;
}

export function useSesi(): IsiSesi {
  const isi = useContext(KonteksSesi);
  if (!isi) throw new Error('useSesi dipakai di luar PenyediaSesi.');
  return isi;
}

/** Pengguna yang sedang masuk, atau null kalau belum. */
export function usePengguna(): Pengguna | null {
  const { keadaan } = useSesi();
  return keadaan.tahap === 'masuk' ? keadaan.pengguna : null;
}
