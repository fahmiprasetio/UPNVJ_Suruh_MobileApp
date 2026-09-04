import type { KontrakOrderHub } from '../src/inti/order_hub_client';

/**
 * Sambungan hub tiruan untuk tes layar.
 *
 * `PenyediaSesi` menyalakan `OrderHubClient` sungguhan begitu ada yang masuk (lihat
 * `auth/sesi.tsx`), dan `OrderHubClient` sungguhan mencoba menghubungi server sungguhan.
 * Tanpa tiruan ini, setiap tes yang melewati layar masuk memicu percobaan jaringan yang
 * pasti gagal di `jsdom` — bukan cuma sia-sia, tapi berisik di keluaran tes dan
 * memperlambatnya tanpa alasan.
 *
 * Namanya sengaja bukan `*.tes.ts`: berkas ini bukan suite tes, cuma perlengkapannya, dan
 * pola berkas tes di `vite.config.ts` cuma mencocokkan yang berakhiran itu.
 */
export function buatTiruanHub(): KontrakOrderHub {
  return {
    mulai() {},
    async berhenti() {},
    onPerubahan() {
      return () => {};
    },
  };
}

/**
 * Tiruan hub yang bisa dipicu dari tes, untuk layar yang sungguh menguji perilaku
 * "kabar dari hub memuat ulang layarnya".
 *
 * `picu()` memanggil setiap pendengar yang sedang terdaftar, persis seperti kabar
 * "OrderChanged" sungguhan sampai ke `OrderHubClient` lalu diteruskan ke seluruh
 * pendengarnya.
 */
export function buatKendaliHub(): { hub: KontrakOrderHub; picu: () => void } {
  const pendengar = new Set<() => void>();

  const hub: KontrakOrderHub = {
    mulai() {},
    async berhenti() {},
    onPerubahan(satu) {
      pendengar.add(satu);
      return () => {
        pendengar.delete(satu);
      };
    },
  };

  const picu = () => {
    for (const satu of pendengar) satu();
  };

  return { hub, picu };
}
