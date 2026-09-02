import { describe, expect, it, vi } from 'vitest';

import {
  GalatBentrok,
  GalatDilarang,
  GalatJaringan,
  GalatPermintaan,
  GalatServer,
  GalatTerlaluSering,
  GalatTidakBerwenang,
  GalatTidakDitemukan,
} from '../src/inti/galat_api';
import { KlienApi } from '../src/inti/klien_api';

/** Jawaban palsu, cukup untuk yang dibaca KlienApi. */
function jawaban(status: number, badan?: unknown): Response {
  return new Response(badan === undefined ? '' : JSON.stringify(badan), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function klien(fetchPalsu: typeof fetch, token: string | null = null) {
  return new KlienApi(() => token, 'http://uji', fetchPalsu);
}

/**
 * Argumen panggilan fetch ke-n.
 *
 * Ada karena `noUncheckedIndexedAccess` menyala di tsconfig, dan itu memang yang
 * diinginkan: indeks larik yang dianggap selalu ada adalah cara paling sering
 * memasukkan undefined ke tempat yang tidak menyangkanya.
 */
function panggilan(ambil: ReturnType<typeof vi.fn>, ke = 0): [string, RequestInit] {
  const argumen = ambil.mock.calls[ke];
  if (!argumen) throw new Error(`fetch belum dipanggil sebanyak ${ke + 1} kali.`);
  return argumen as [string, RequestInit];
}

describe('KlienApi', () => {
  it('membawa token di header Authorization kalau ada', async () => {
    const ambil = vi.fn().mockImplementation(() => Promise.resolve(jawaban(200, { ok: true })));
    await klien(ambil as unknown as typeof fetch, 'token-abc').minta('/api/auth/saya');

    const kepala = panggilan(ambil)[1].headers as Record<string, string>;
    expect(kepala.Authorization).toBe('Bearer token-abc');
  });

  it('tidak mengarang header Authorization saat belum masuk', async () => {
    const ambil = vi.fn().mockImplementation(() => Promise.resolve(jawaban(200, {})));
    await klien(ambil as unknown as typeof fetch).minta('/api/auth/minta-kode');

    const kepala = panggilan(ambil)[1].headers as Record<string, string>;
    expect(kepala.Authorization).toBeUndefined();
  });

  it('membaca token setiap permintaan, bukan sekali saat dibuat', async () => {
    // Kalau tokennya disalin saat pembuatan, permintaan sesudah orang masuk masih akan
    // berangkat tanpa token, dan yang terlihat adalah "sudah masuk tapi semuanya 401".
    let token: string | null = null;
    // Setiap panggilan mendapat Response barunya sendiri: badan Response cuma bisa
    // dibaca sekali, jadi satu objek yang dipakai ulang akan terbaca kosong di
    // panggilan kedua.
    const ambil = vi.fn().mockImplementation(() => Promise.resolve(jawaban(200, {})));
    const api = new KlienApi(() => token, 'http://uji', ambil as unknown as typeof fetch);

    await api.minta('/satu');
    token = 'token-baru';
    await api.minta('/dua');

    const kepalaKedua = panggilan(ambil, 1)[1].headers as Record<string, string>;
    expect(kepalaKedua.Authorization).toBe('Bearer token-baru');
  });

  it('membuang parameter kueri yang kosong alih-alih mengirimnya', async () => {
    // Penting untuk daftar order: `status=` yang terkirim kosong ditolak backend sebagai
    // nilai enum yang tidak sah, padahal maksudnya "tanpa penyaring".
    const ambil = vi.fn().mockImplementation(() => Promise.resolve(jawaban(200, {})));
    await klien(ambil as unknown as typeof fetch).minta('/api/admin/orders', {
      kueri: { status: undefined, halaman: 2, ukuran: 20 },
    });

    expect(panggilan(ambil)[0]).toBe('http://uji/api/admin/orders?halaman=2&ukuran=20');
  });

  it('mengembalikan undefined untuk 204, bukan mencoba membaca badan kosong', async () => {
    const ambil = vi.fn().mockResolvedValue(new Response(null, { status: 204 }));
    await expect(klien(ambil as unknown as typeof fetch).minta('/api/auth/minta-kode')).resolves
      .toBeUndefined();
  });

  it('menerjemahkan kode status jadi jenis galat yang menentukan tindakan', async () => {
    const kasus: [number, unknown][] = [
      [400, GalatPermintaan],
      [401, GalatTidakBerwenang],
      [403, GalatDilarang],
      [404, GalatTidakDitemukan],
      [409, GalatBentrok],
      [429, GalatTerlaluSering],
      [500, GalatServer],
    ];

    for (const [status, jenis] of kasus) {
      const ambil = vi.fn().mockResolvedValue(jawaban(status, { title: 'x' }));
      await expect(klien(ambil as unknown as typeof fetch).minta('/apa-pun')).rejects.toBeInstanceOf(
        jenis as never,
      );
    }
  });

  it('memakai kalimat ProblemDetails dari server apa adanya', async () => {
    // Backend menulis judul dan detail untuk dibaca orang, dan keduanya saling
    // melengkapi: judul menyebut apa yang ditolak, detail menyebut apa yang harus
    // dilakukan. Menggantinya dengan karangan sendiri membuang separuh yang berguna.
    const ambil = vi.fn().mockResolvedValue(
      jawaban(400, {
        title: 'Ini admin terakhir',
        detail: 'Angkat admin lain dulu sebelum mencabut yang ini.',
      }),
    );

    await expect(klien(ambil as unknown as typeof fetch).minta('/apa-pun')).rejects.toThrow(
      'Ini admin terakhir. Angkat admin lain dulu sebelum mencabut yang ini.',
    );
  });

  it('tidak meneruskan isi jawaban 5xx ke layar', async () => {
    // Jejak galat backend yang sampai ke layar adalah bocoran gratis tentang bentuk
    // dalam sistem, dan tidak menolong siapa pun yang sedang memantau order.
    const ambil = vi.fn().mockResolvedValue(
      jawaban(500, { title: 'NpgsqlException', detail: 'relation "orders" does not exist' }),
    );

    const galat = await klien(ambil as unknown as typeof fetch)
      .minta('/apa-pun')
      .catch((e: Error) => e);

    expect((galat as Error).message).not.toContain('Npgsql');
  });

  it('menyebut kegagalan sebelum ada jawaban sebagai galat jaringan', async () => {
    const ambil = vi.fn().mockRejectedValue(new TypeError('failed to fetch'));
    await expect(klien(ambil as unknown as typeof fetch).minta('/apa-pun')).rejects.toBeInstanceOf(
      GalatJaringan,
    );
  });

  it('menolak jawaban 200 yang badannya bukan JSON', async () => {
    // Biasanya berarti yang menjawab bukan API ini, melainkan halaman galat dari proxy
    // atau alamat yang salah ketik. Diserahkan ke layar sebagai null, galatnya muncul
    // jauh dari sebabnya.
    const ambil = vi.fn().mockResolvedValue(new Response('<html>bukan json</html>', { status: 200 }));
    await expect(klien(ambil as unknown as typeof fetch).minta('/apa-pun')).rejects.toBeInstanceOf(
      GalatServer,
    );
  });
});
