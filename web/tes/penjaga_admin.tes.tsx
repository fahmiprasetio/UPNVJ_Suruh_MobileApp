import { render, screen } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { PerluAdmin } from '../src/auth/penjaga_admin';
import { PenyediaSesi } from '../src/auth/sesi';
import { KlienApi } from '../src/inti/klien_api';
import type { Pengguna } from '../src/inti/tipe';

/**
 * Penjaga ini bukan penjagaan keamanan; yang menjaga data ada di backend. Yang diuji di
 * sini adalah janji yang lain: orang tidak dilempar ke layar yang seluruh isinya akan
 * dijawab 403, dan orang yang salah akun diberi tahu apa yang sebenarnya kurang alih-alih
 * diputar-putar di antara dua layar.
 */

function pasangSesi(jawabanSaya: () => Promise<Response>) {
  const ambil = vi.fn().mockImplementation(jawabanSaya);
  const buatKlien = (bacaToken: () => string | null) =>
    new KlienApi(bacaToken, 'http://uji', ambil as unknown as typeof fetch);

  return render(
    <MemoryRouter initialEntries={['/order']}>
      <PenyediaSesi buatKlien={buatKlien}>
        <Routes>
          <Route path="/masuk" element={<p>Halaman masuk</p>} />
          <Route
            path="/order"
            element={
              <PerluAdmin>
                <p>Isi dashboard</p>
              </PerluAdmin>
            }
          />
        </Routes>
      </PenyediaSesi>
    </MemoryRouter>,
  );
}

function pengguna(roles: Pengguna['roles']): Response {
  const isi: Pengguna = {
    id: '11111111-1111-1111-1111-111111111111',
    nama: 'Jiro',
    noHp: '08123',
    alamat: null,
    roles,
  };
  return new Response(JSON.stringify(isi), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

afterEach(() => {
  window.sessionStorage.clear();
});

describe('PerluAdmin', () => {
  it('melempar yang belum masuk ke halaman masuk', async () => {
    pasangSesi(() => Promise.resolve(pengguna(['Admin'])));

    expect(await screen.findByText('Halaman masuk')).toBeInTheDocument();
  });

  it('meloloskan akun yang menyandang peran admin', async () => {
    window.sessionStorage.setItem('upnvj-suruh.token-admin', 'token-uji');
    pasangSesi(() => Promise.resolve(pengguna(['Admin', 'Runner'])));

    expect(await screen.findByText('Isi dashboard')).toBeInTheDocument();
  });

  it('menahan akun tanpa peran admin tanpa melemparnya ke layar masuk', async () => {
    // Masuk ulang tidak akan menambah peran. Melemparnya ke halaman masuk cuma membuat
    // orang berputar-putar tanpa pernah diberi tahu apa yang kurang.
    window.sessionStorage.setItem('upnvj-suruh.token-admin', 'token-uji');
    pasangSesi(() => Promise.resolve(pengguna(['Runner'])));

    expect(await screen.findByText('Dashboard ini khusus admin')).toBeInTheDocument();
    expect(screen.queryByText('Halaman masuk')).not.toBeInTheDocument();
  });

  it('mengeluarkan orang saat tokennya sudah tidak berlaku', async () => {
    window.sessionStorage.setItem('upnvj-suruh.token-admin', 'token-basi');
    pasangSesi(() => Promise.resolve(new Response('', { status: 401 })));

    expect(await screen.findByText('Halaman masuk')).toBeInTheDocument();
    expect(window.sessionStorage.getItem('upnvj-suruh.token-admin')).toBeNull();
  });

  it('tidak membuang token hanya karena server sedang mati', async () => {
    // Kode masuk dikirim lewat SMS dan berbiaya per pesan. Menghapus token setiap kali
    // backend sempat direstart berarti menyuruh admin membeli kode baru tanpa sebab.
    window.sessionStorage.setItem('upnvj-suruh.token-admin', 'token-baik');
    pasangSesi(() => Promise.reject(new TypeError('failed to fetch')));

    expect(await screen.findByText('Halaman masuk')).toBeInTheDocument();
    expect(window.sessionStorage.getItem('upnvj-suruh.token-admin')).toBe('token-baik');
  });
});
