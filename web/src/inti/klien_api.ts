import { GalatJaringan, GalatServer, galatDari } from './galat_api';

/**
 * Alamat backend, diisi saat build lewat berkas `.env`, bukan ditulis mati di sini.
 *
 * Alasannya sama dengan `KonfigurasiApi` di sisi mobile: alamat server pengembangan yang
 * ikut ter-commit akan terbawa ke build siapa pun yang lupa menggantinya, dan dashboard
 * yang diam-diam bicara ke server yang salah adalah kegagalan yang tidak terlihat sampai
 * ada yang memeriksa lalu lintasnya.
 */
export const alamatApi: string =
  (import.meta.env?.VITE_API_BASE_URL as string | undefined)?.replace(/\/+$/, '') ??
  'http://localhost:5059';

/**
 * Batas sabar menunggu satu permintaan.
 *
 * Tanpa batas, permintaan yang tidak pernah dijawab menggantung layarnya selamanya dalam
 * keadaan memuat, dan satu-satunya jalan keluar bagi yang memakainya adalah memuat ulang
 * peramban. Angkanya disamakan dengan sisi mobile supaya dua permukaan tidak menyerah
 * pada waktu yang berbeda untuk server yang sama.
 */
export const batasWaktuMilidetik = 20_000;

export interface OpsiPermintaan {
  metode?: 'GET' | 'POST' | 'PUT' | 'DELETE';
  /** Dikirim sebagai JSON. */
  badan?: unknown;
  /** Parameter kueri; yang bernilai undefined atau null dibuang, bukan dikirim kosong. */
  kueri?: Record<string, string | number | boolean | undefined | null>;
  /** Untuk membatalkan permintaan yang layarnya sudah ditinggalkan. */
  sinyal?: AbortSignal;
}

/**
 * Satu-satunya tempat di dashboard ini yang memanggil `fetch`.
 *
 * Dipusatkan bukan demi kerapian melainkan demi tiga hal yang harus berlaku untuk
 * *setiap* permintaan, dan yang akan terlewat kalau setiap layar memanggil fetch sendiri:
 * token ikut terbawa, jawaban galat diterjemahkan jadi jenis yang seragam, dan tidak ada
 * permintaan yang boleh menggantung tanpa batas waktu.
 *
 * Token dibaca lewat fungsi, bukan disimpan sebagai field yang diisi sekali saat kelas
 * ini dibuat. Bedanya nyata: token bisa berubah (masuk, keluar, kedaluwarsa) selama
 * halaman yang sama terbuka, dan salinan yang diambil saat pembuatan akan tetap dipakai
 * sesudah token itu tidak berlaku lagi.
 */
export class KlienApi {
  constructor(
    private readonly bacaToken: () => string | null,
    private readonly alamat: string = alamatApi,
    private readonly fetchImpl: typeof fetch = globalThis.fetch.bind(globalThis),
  ) {}

  async minta<T>(jalur: string, opsi: OpsiPermintaan = {}): Promise<T> {
    const kendali = new AbortController();
    const pewaktu = setTimeout(() => kendali.abort(), batasWaktuMilidetik);
    const batalkan = () => kendali.abort();
    opsi.sinyal?.addEventListener('abort', batalkan);

    const kepala: Record<string, string> = { Accept: 'application/json' };
    const token = this.bacaToken();
    if (token) kepala.Authorization = `Bearer ${token}`;
    if (opsi.badan !== undefined) kepala['Content-Type'] = 'application/json';

    let jawaban: Response;
    try {
      jawaban = await this.fetchImpl(this.alamat + jalur + kueriDari(opsi.kueri), {
        method: opsi.metode ?? 'GET',
        headers: kepala,
        body: opsi.badan === undefined ? undefined : JSON.stringify(opsi.badan),
        signal: kendali.signal,
      });
    } catch {
      // Semua kegagalan sebelum ada jawaban bermuara ke sini, termasuk kelewat batas
      // waktu dan pembatalan. Dibedakan lebih jauh tidak menolong siapa pun: yang
      // membacanya tidak bisa berbuat apa-apa selain mencoba lagi.
      throw new GalatJaringan();
    } finally {
      clearTimeout(pewaktu);
      opsi.sinyal?.removeEventListener('abort', batalkan);
    }

    if (!jawaban.ok) {
      throw galatDari(jawaban.status, await badanJson(jawaban));
    }

    if (jawaban.status === 204) return undefined as T;

    const isi = await badanJson(jawaban);
    if (isi === null) {
      // Jawaban 200 yang badannya bukan JSON berarti yang menjawab bukan API ini,
      // biasanya halaman galat dari proxy atau alamat yang salah ketik. Menyerahkannya
      // ke layar sebagai `null` membuat galatnya muncul jauh dari sebabnya.
      throw new GalatServer('Jawaban server tidak bisa dibaca.');
    }

    return isi as T;
  }
}

function kueriDari(kueri: OpsiPermintaan['kueri']): string {
  if (!kueri) return '';

  const parameter = new URLSearchParams();
  for (const [kunci, nilai] of Object.entries(kueri)) {
    if (nilai === undefined || nilai === null || nilai === '') continue;
    parameter.set(kunci, String(nilai));
  }

  const teks = parameter.toString();
  return teks ? `?${teks}` : '';
}

async function badanJson(jawaban: Response): Promise<unknown> {
  try {
    const teks = await jawaban.text();
    return teks.length === 0 ? null : JSON.parse(teks);
  } catch {
    return null;
  }
}
