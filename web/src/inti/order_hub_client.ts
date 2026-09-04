import * as signalR from '@microsoft/signalr';

import { alamatApi } from './klien_api';

/**
 * Bentuk publik `OrderHubClient`, dipisahkan sebagai antarmuka supaya tes bisa memberi
 * tiruan yang tidak sungguhan menyambung ke mana pun.
 *
 * Kelasnya sendiri tidak bisa langsung ditiru lewat objek literal: field privatnya
 * membuat TypeScript menuntut tiruan itu berasal dari kelas yang sama persis. Antarmuka
 * ini yang jadi titik sambungnya, dan `PenyediaSesi` menerima ini lewat `buatHub`, bukan
 * `OrderHubClient` secara langsung.
 */
export interface KontrakOrderHub {
  mulai(): void;
  berhenti(): Promise<void>;
  onPerubahan(pendengar: () => void): () => void;
}

/**
 * Sambungan tunggal ke `OrderHub`, sisi grup admin.
 *
 * Kembaran `OrderHubClient` di mobile (`mobile/lib/core/realtime/order_hub_client.dart`),
 * tapi jauh lebih tipis: mobile menulis Protokol Hub JSON sendiri di atas
 * `web_socket_channel` karena paket `signalr_netcore` tidak mencantumkan dukungan web di
 * pub.dev, sementara dashboard ini berjalan di peramban sungguhan, jadi paket resmi
 * `@microsoft/signalr` cukup dipakai apa adanya — tidak ada alasan menulis ulang framing,
 * jabat tangan, atau ping yang sudah dikerjakan paket itu.
 *
 * ## Kabar apa pun cukup jadi sinyal "ambil ulang"
 *
 * Sama seperti sisi mobile (rencana capstone bagian 37.2): isi kabarnya (id order) tidak
 * dibaca kelas ini sama sekali, cuma diteruskan sebagai pertanda bahwa sesuatu berubah.
 * Layar yang mendengarkan memuat ulang daftarnya sendiri lewat endpoint biasa, jadi tidak
 * ada bentuk data hub yang perlu dijaga sama dengan `OrderResponse` di dua tempat.
 *
 * ## Bukan satu-satunya sumber kebenaran
 *
 * Dipakai sebagai jaring penyegar tambahan, bukan pengganti pengambilan berkala 15 detik
 * yang sudah ada (`gunakanMuat(..., { segarkanBerkala: true })`). Kalau koneksi hub putus
 * (jaringan kampus yang goyah, tab yang lama tidak difokuskan), pengambilan berkala itu
 * tetap membuat layar tidak basi selamanya menunggu koneksi pulih.
 *
 * ## Kenapa disambungkan lewat token, bukan cookie
 *
 * Server mensyaratkan `[Authorize]` di seluruh hub dan menerima token lewat query string
 * `access_token` untuk jalur WebSocket, karena WebSocket tidak bisa membawa header
 * `Authorization` (lihat `TokenLewatQueryStringDiterimaUntukJalurHub` di
 * `HubKeamananTests.cs`). `accessTokenFactory` di bawah ini yang menanganinya; paket
 * SignalR yang menyusun query string-nya sendiri, bukan kelas ini.
 */
export class OrderHubClient implements KontrakOrderHub {
  private koneksi: signalR.HubConnection | null = null;
  private readonly pendengar = new Set<() => void>();

  constructor(
    private readonly bacaToken: () => string | null,
    private readonly alamat: string = alamatApi,
  ) {}

  /**
   * Menyambung. Dipanggil ulang setiap kali status masuk berubah (lihat `PenyediaSesi`),
   * bukan sekali saat dashboard dibuka — token yang dibawa harus token akun yang sedang
   * masuk sekarang, dan sesi yang berganti butuh sambungan baru dengan token baru.
   *
   * Aman dipanggil dua kali; panggilan kedua tidak melakukan apa-apa selama sambungan
   * pertama masih ada, supaya efek React yang berjalan dua kali di mode pengembangan
   * tidak membuka dua koneksi untuk akun yang sama.
   */
  mulai(): void {
    if (this.koneksi) return;

    const koneksi = new signalR.HubConnectionBuilder()
      .withUrl(`${this.alamat}/hubs/orders`, {
        accessTokenFactory: () => this.bacaToken() ?? '',
      })
      // Jaring pengaman untuk putus sesaat, mengikuti alasan yang sama dengan sisi mobile:
      // koneksi hub boleh hilang sewaktu-waktu, dan pengambilan berkala di bawahnya tetap
      // menjaga layar tidak basi selama itu. `withAutomaticReconnect` cukup memakai nilai
      // bawaannya (percobaan pada 0, 2, 10, 30 detik), tidak ada alasan menalanya sendiri.
      .withAutomaticReconnect()
      .build();

    koneksi.on('OrderChanged', () => this.pancarkan());

    // Kegagalan pertama kali menyambung sengaja tidak dilempar ke pemanggil. Dashboard
    // tetap harus bisa dipakai lewat pengambilan berkala kalau hub-nya untuk suatu sebab
    // tidak bisa dijangkau (misalnya `/hubs/orders` diblokir proksi kampus), dan
    // melemparnya ke atas berarti setiap pemanggil `mulai()` harus ikut menangani galat
    // yang sebenarnya bukan urusannya.
    koneksi.start().catch(() => {
      // Dibiarkan diam. `withAutomaticReconnect` cuma menangani putus SESUDAH tersambung;
      // kegagalan start pertama ini tidak akan dicoba ulang sendiri oleh paketnya.
    });

    this.koneksi = koneksi;
  }

  /** Memutus sambungan. Dipanggil saat pengguna keluar. */
  async berhenti(): Promise<void> {
    const koneksi = this.koneksi;
    this.koneksi = null;
    await koneksi?.stop();
  }

  /**
   * Mendengarkan kabar "ada order yang berubah". Mengembalikan fungsi untuk berhenti
   * mendengarkan, dipanggil dari `useEffect` di layar yang memakainya.
   */
  onPerubahan(pendengar: () => void): () => void {
    this.pendengar.add(pendengar);
    return () => {
      this.pendengar.delete(pendengar);
    };
  }

  private pancarkan(): void {
    for (const pendengar of this.pendengar) pendengar();
  }
}
