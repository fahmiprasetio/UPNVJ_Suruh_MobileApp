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
import { OrderHubClient, type KontrakOrderHub } from '../inti/order_hub_client';
import type { Pengguna } from '../inti/tipe';
import { bacaToken, hapusToken, simpanToken } from './penyimpanan_token';

/**
 * Siapa yang sedang memakai dashboard, satu klien API yang sudah membawa tokennya, dan
 * satu sambungan hub yang siklus hidupnya mengikuti sesi.
 *
 * Ketiganya disatukan di sini dengan sengaja. Kalau token disimpan di satu tempat dan
 * klien API dibuat di tempat lain, akan selalu ada layar yang memegang klien API dari
 * sebelum seseorang keluar, dan layar itu tetap bisa mengambil data atas nama akun yang
 * sudah ditinggalkan. Sambungan hub ikut aturan yang sama, dan alasannya lebih tegas lagi:
 * `OrderHub` mensyaratkan token yang masih berlaku di seluruh permukaannya, jadi sambungan
 * yang dibuat sekali saat dashboard dibuka dan dibiarkan hidup selamanya akan terus
 * membawa token akun yang sudah lama keluar begitu ada pergantian sesi.
 */

type KeadaanSesi =
  /** Belum tahu: ada token tersimpan, dan pemiliknya sedang ditanyakan ke server. */
  | { tahap: 'memeriksa' }
  /**
   * `ditolak` benar kalau sesinya berakhir karena server menolak tokennya, bukan
   * karena adminnya menekan keluar. Dipakai halaman masuk untuk menjelaskan kenapa
   * orangnya tiba-tiba ada di sana; sesi yang berakhir sendiri tanpa keterangan
   * terbaca sebagai dashboard yang rusak, dan yang mengira begitu tidak mencoba
   * masuk lagi.
   */
  | { tahap: 'keluar'; ditolak?: boolean }
  | { tahap: 'masuk'; pengguna: Pengguna };

interface IsiSesi {
  keadaan: KeadaanSesi;
  api: KlienApi;
  hub: KontrakOrderHub;
  masuk(noHp: string, kode: string): Promise<Pengguna>;
  keluar(): void;
}

const KonteksSesi = createContext<IsiSesi | null>(null);

export function PenyediaSesi({
  children,
  buatKlien,
  buatHub,
}: {
  children: ReactNode;
  /**
   * Disediakan tes untuk menembus jaringan. Pemakaian biasa tidak mengisinya.
   *
   * Jalur penolakan sesi ikut dioper, tidak cuma tokennya. Kalau tidak, setiap klien
   * yang disuntik dari luar memutus jalur itu diam-diam: 401 tidak lagi mengeluarkan
   * siapa pun, dan tidak ada yang gagal untuk menandainya.
   */
  buatKlien?: (bacaToken: () => string | null, saatSesiDitolak: () => void) => KlienApi;
  /** Disediakan tes untuk menembus sambungan hub sungguhan. Pemakaian biasa tidak mengisinya. */
  buatHub?: (bacaToken: () => string | null) => KontrakOrderHub;
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

  // Lewat ref, dengan alasan yang sama seperti token di atas: KlienApi dibuat sekali
  // dan dipakai seumur halaman, jadi ia tidak boleh menangkap fungsi yang isinya
  // berubah.
  const sesiDitolakRef = useRef<() => void>(() => {});

  const api = useMemo(() => {
    const baca = () => tokenRef.current;
    const ditolak = () => sesiDitolakRef.current();
    return buatKlien ? buatKlien(baca, ditolak) : new KlienApi(baca, undefined, undefined, ditolak);
  }, [buatKlien]);

  const hub = useMemo(() => {
    const baca = () => tokenRef.current;
    return buatHub ? buatHub(baca) : new OrderHubClient(baca);
  }, [buatHub]);

  // Siklus hidupnya mengikuti tahap sesi: nyala begitu ada yang masuk, mati begitu keluar.
  // Bukan sekali saat dashboard dibuka, karena tokennya bisa berganti (masuk sebagai akun
  // lain sesudah keluar) tanpa dashboard-nya sendiri dimuat ulang, dan sambungan lama akan
  // terus membawa token yang sudah tidak berlaku.
  useEffect(() => {
    if (keadaan.tahap === 'masuk') {
      hub.mulai();
    } else {
      void hub.berhenti();
    }
  }, [keadaan.tahap, hub]);

  useEffect(() => () => void hub.berhenti(), [hub]);

  const keluar = useCallback(() => {
    hapusToken();
    setToken(null);
    setKeadaan({ tahap: 'keluar' });
  }, []);

  sesiDitolakRef.current = () => {
    // Sudah keluar sejak permintaan itu berangkat: dua permintaan gagal beruntun, atau
    // adminnya menekan keluar tepat di sela itu. Menyalakan kalimat "sesimu berakhir"
    // untuk orang yang barusan menekan keluar sendiri jelas salah.
    if (tokenRef.current === null) return;
    hapusToken();
    setToken(null);
    setKeadaan({ tahap: 'keluar', ditolak: true });
  };

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
        //
        // Token yang ditolak tidak lagi ditangani di sini: `KlienApi` sudah
        // melakukannya untuk SETIAP permintaan, termasuk yang ini, lewat jalur yang
        // sama dengan token yang basi di tengah pemakaian. Menanganinya dua kali
        // berarti yang belakangan menimpa keterangan yang baru saja dipasang yang
        // pertama, dan adminnya kembali tidak diberi tahu apa-apa.
        if (galat instanceof GalatTidakBerwenang) return;
        setKeadaan({ tahap: 'keluar' });
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

  const isi = useMemo<IsiSesi>(
    () => ({ keadaan, api, hub, masuk, keluar }),
    [keadaan, api, hub, masuk, keluar],
  );

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
