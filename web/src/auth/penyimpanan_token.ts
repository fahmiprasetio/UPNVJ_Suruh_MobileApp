/**
 * Tempat token sesi disimpan selama dashboard dibuka.
 *
 * Dipilih `sessionStorage`, bukan `localStorage`, dan bukan pula cuma variabel di memori.
 *
 * Bedanya dengan localStorage: isi sessionStorage hilang begitu tab ditutup. Dashboard ini
 * dipakai di laptop yang sering dipakai bergantian, dan token admin yang bertahan berhari-hari
 * di peramban adalah kunci ke seluruh order dan nomor HP pelanggan bagi siapa pun yang
 * berikutnya membuka laptop itu.
 *
 * Bedanya dengan menyimpan di memori saja: tanpa penyimpanan, satu tekan F5 mengeluarkan
 * admin dari dashboard. Kode masuk dikirim lewat SMS dan berbiaya per pesan (lihat
 * PembatasOtp di backend), jadi memaksa masuk ulang setiap muat ulang bukan cuma menjengkelkan,
 * tapi juga menghabiskan uang mitra.
 *
 * Yang harus ditulis terbuka: penyimpanan mana pun yang bisa dibaca JavaScript tidak
 * menahan XSS. Yang menjaga dari itu bukan berkas ini melainkan tidak adanya HTML kiriman
 * orang yang digambar mentah di dashboard. Kalau nanti dibutuhkan penjagaan yang sungguh,
 * bentuknya cookie HttpOnly, dan itu menuntut perubahan di backend, bukan di sini.
 */

const kunci = 'upnvj-suruh.token-admin';

export function bacaToken(): string | null {
  try {
    return window.sessionStorage.getItem(kunci);
  } catch {
    // Peramban yang menolak penyimpanan (mode privasi tertentu, setelan yang diperketat)
    // melempar di sini. Dashboard tetap harus bisa dipakai, cukup dengan konsekuensi
    // bahwa muat ulang berarti masuk lagi.
    return null;
  }
}

export function simpanToken(token: string): void {
  try {
    window.sessionStorage.setItem(kunci, token);
  } catch {
    /* lihat alasan di bacaToken */
  }
}

export function hapusToken(): void {
  try {
    window.sessionStorage.removeItem(kunci);
  } catch {
    /* lihat alasan di bacaToken */
  }
}
