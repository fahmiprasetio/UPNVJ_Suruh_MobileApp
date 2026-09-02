import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

// Port dipatok, tidak dibiarkan mencari yang kosong.
//
// Backend hanya mengizinkan asal loopback saat Development (lihat CORS di Program.cs),
// jadi port mana pun di localhost sebenarnya diterima. Yang dipatok di sini demi hal
// lain: alamat dashboard yang berpindah-pindah membuat tautan yang ditempel di catatan
// atau di laporan mati begitu ada instans lain sedang menyala.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    strictPort: true,
  },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./vitest.setup.ts'],
    include: ['tes/**/*.tes.ts', 'tes/**/*.tes.tsx'],
  },
});
