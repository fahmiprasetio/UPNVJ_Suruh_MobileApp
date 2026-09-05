import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';

import { useSesi } from '../auth/sesi';
import { daftarOrder } from '../inti/api_admin';
import { formatRupiah, formatWaktuRelatif, labelLayanan, menitSejak } from '../inti/format';
import { gunakanMuat } from '../inti/gunakan_muat';
import type { Order, StatusOrder } from '../inti/tipe';
import { Kosong, KotakGalat, Memuat } from '../komponen/keadaan';
import { LencanaJalur, LencanaStatus } from '../komponen/lencana';

/**
 * Pantauan order: seluruh order yang ada di sistem, disaring statusnya.
 *
 * Layar pertama yang dibuka admin, dan gunanya satu: menemukan order yang macet sebelum
 * kliennya yang menemukannya lebih dulu. Karena itu urutannya terbaru di atas (ikut
 * backend), penyaring statusnya ada di depan, dan lama menunggu ditulis sebagai "12 menit
 * lalu", bukan sebagai jam dinding yang harus dihitung sendiri.
 */

const UKURAN_HALAMAN = 20;

/**
 * Penyaring yang disediakan, beserta urutannya.
 *
 * Bukan seluruh anggota StatusOrder. `MenungguPersetujuanKlien` tidak pernah lagi
 * diproduksi backend sejak Jalur B jadi tawar-menawar, jadi tombolnya cuma akan
 * menghasilkan daftar kosong selamanya; order lama yang masih menyandangnya tetap
 * terlihat lewat penyaring "Semua".
 */
const penyaringStatus: { nilai: StatusOrder | undefined; label: string }[] = [
  { nilai: undefined, label: 'Semua' },
  { nilai: 'Permintaan', label: 'Menunggu Tawaran' },
  { nilai: 'MenungguPembayaran', label: 'Menunggu Pembayaran' },
  { nilai: 'MencariRunner', label: 'Mencari Runner' },
  { nilai: 'Dikerjakan', label: 'Dikerjakan' },
  { nilai: 'Selesai', label: 'Selesai' },
  { nilai: 'Batal', label: 'Batal' },
];

/**
 * Berapa lama sebuah order boleh menganggur sebelum ditandai di layar ini.
 *
 * Angka milik dashboard, bukan aturan sistem. Backend belum punya batas order menganggur
 * sama sekali (bagian 14.7e rencana proyek masih terbuka), jadi tidak ada yang menegur
 * siapa pun kalau kebetulan tidak ada admin yang sedang melihat layar ini. Penandaan di
 * sini tambalan sementara untuk itu, dan sengaja disebut begitu supaya tidak ada yang
 * mengiranya penjagaan yang sungguh-sungguh.
 */
const AMBANG_MACET_MENIT = 10;

export function HalamanPantauanOrder() {
  const { api, hub } = useSesi();
  const [status, setStatus] = useState<StatusOrder | undefined>(undefined);
  // Berdiri terpisah dari `status`, bukan salah satu nilainya, karena menunggu keputusan
  // pembatalan bukan status order: ordernya tetap MencariRunner atau Dikerjakan sementara
  // permintaannya menunggu. Keduanya boleh menyala bersamaan dan menyempit bersama.
  const [mintaBatal, setMintaBatal] = useState(false);
  const [halaman, setHalaman] = useState(1);

  const ambil = useCallback(
    (sinyal: AbortSignal) =>
      daftarOrder(api, { status, mintaBatal, halaman, ukuran: UKURAN_HALAMAN }, sinyal),
    [api, status, mintaBatal, halaman],
  );

  const { data, memuat, galat, muatUlang } = gunakanMuat(ambil, { segarkanBerkala: true });

  // Jaring penyegar tambahan, bukan pengganti `segarkanBerkala` di atas. Begitu ada order
  // yang berubah, dashboard ini biasanya tahu dalam hitungan detik, bukan menunggu sampai
  // lima belas detik habis; kalau sambungan hub-nya putus untuk suatu sebab (jaringan
  // kampus yang goyah, tab yang lama tidak difokuskan), pengambilan berkala tadi tetap
  // menjaga layar ini tidak basi selamanya.
  useEffect(() => hub.onPerubahan(muatUlang), [hub, muatUlang]);

  const labelPenyaringAktif = penyaringStatus.find((p) => p.nilai === status)?.label;

  return (
    <section className="pantauan">
      <header className="pantauan__kepala">
        <h1>Pantauan Order</h1>
        {data && (
          <p className="pantauan__hitungan">
            {data.total} order{status ? ' berstatus ' + labelPenyaringAktif : ''}
            {mintaBatal ? ' yang meminta dibatalkan' : ''}
          </p>
        )}
      </header>

      <div className="pantauan__penyaring" role="group" aria-label="Saring menurut status">
        {penyaringStatus.map((penyaring) => (
          <button
            key={penyaring.label}
            type="button"
            className={penyaring.nilai === status ? 'cip cip--aktif' : 'cip'}
            aria-pressed={penyaring.nilai === status}
            onClick={() => {
              setStatus(penyaring.nilai);
              // Halaman dikembalikan ke satu setiap penyaring berganti. Tanpa ini, admin
              // yang sedang di halaman 3 lalu menyaring ke status yang cuma punya satu
              // halaman akan melihat daftar kosong dan menyangka ordernya tidak ada.
              setHalaman(1);
            }}
          >
            {penyaring.label}
          </button>
        ))}
      </div>

      {/* Berdiri sendiri, terpisah dari deretan status di atasnya, karena isinya
          berbeda jenis: penyaring status memilah order menurut keadaannya, sedangkan yang
          ini satu-satunya antrean di dashboard yang menuntut jawaban. Di ujungnya ada uang
          yang dikembalikan atau tidak, dan klien yang sedang menunggu jawabannya. */}
      <div className="pantauan__penyaring">
        <button
          type="button"
          className={mintaBatal ? 'cip cip--aktif' : 'cip'}
          aria-pressed={mintaBatal}
          onClick={() => {
            setMintaBatal((sebelumnya) => !sebelumnya);
            setHalaman(1);
          }}
        >
          Minta dibatalkan
        </button>
      </div>

      {galat !== null && <KotakGalat galat={galat} cobaLagi={muatUlang} />}
      {memuat && data === null && <Memuat />}
      {data !== null && data.isi.length === 0 && (
        <Kosong
          keterangan={
            mintaBatal
              ? 'Tidak ada permintaan pembatalan yang menunggu jawaban.'
              : 'Tidak ada order yang cocok dengan penyaring ini.'
          }
        />
      )}

      {data !== null && data.isi.length > 0 && (
        <>
          <table className="tabel">
            <thead>
              <tr>
                <th scope="col">Kode</th>
                <th scope="col">Layanan</th>
                <th scope="col">Klien</th>
                <th scope="col">Status</th>
                <th scope="col">Harga</th>
                <th scope="col">Masuk</th>
                <th scope="col">Chat</th>
              </tr>
            </thead>
            <tbody>
              {data.isi.map((order) => (
                <BarisOrder key={order.id} order={order} />
              ))}
            </tbody>
          </table>

          <nav className="halaman-nav" aria-label="Halaman">
            <button
              type="button"
              className="tombol tombol--halus"
              disabled={halaman <= 1}
              onClick={() => setHalaman((n) => n - 1)}
            >
              Sebelumnya
            </button>
            <span>
              Halaman {data.halaman} dari {Math.max(data.totalHalaman, 1)}
            </span>
            <button
              type="button"
              className="tombol tombol--halus"
              disabled={halaman >= data.totalHalaman}
              onClick={() => setHalaman((n) => n + 1)}
            >
              Berikutnya
            </button>
          </nav>
        </>
      )}
    </section>
  );
}

function BarisOrder({ order }: { order: Order }) {
  const macet = sedangMacet(order);

  return (
    <tr className={macet ? 'tabel__baris--macet' : undefined}>
      <td>
        <Link to={'/order/' + order.id} className="tautan-kode">
          {order.kodeOrder}
        </Link>{' '}
        <LencanaJalur jalur={order.track} />
      </td>
      <td>{labelLayanan(order.serviceType)}</td>
      <td>{order.namaKlien}</td>
      <td>
        <LencanaStatus status={order.status} />
        {order.mintaBatalPada !== null && (
          // Ditandai di kolom status, bukan kolom tersendiri, karena inilah yang paling
          // menentukan apa yang harus dilakukan admin terhadap baris ini — lebih menentukan
          // daripada statusnya sendiri.
          <span className="tanda-macet" title={'Diminta ' + formatWaktuRelatif(order.mintaBatalPada)}>
            minta batal
          </span>
        )}
        {macet && (
          <span
            className="tanda-macet"
            title={'Belum bergerak lebih dari ' + AMBANG_MACET_MENIT + ' menit.'}
          >
            macet
          </span>
        )}
      </td>
      <td className="tabel__angka">
        {/* Harga usulan klien ditulis miring supaya tidak terbaca sebagai harga yang sudah
            disepakati. Selama Jalur B masih menunggu tawaran, yang ada baru titik awal
            tawar-menawar, bukan harga. */}
        {order.harga !== null ? (
          formatRupiah(order.harga)
        ) : order.hargaUsulan !== null ? (
          <em title="Harga usulan klien, belum disepakati">{formatRupiah(order.hargaUsulan)}</em>
        ) : (
          '-'
        )}
      </td>
      <td title={order.dibuatPada}>{formatWaktuRelatif(order.dibuatPada)}</td>
      <td className="tabel__angka">{order.jumlahPesan > 0 ? order.jumlahPesan : '-'}</td>
    </tr>
  );
}

/**
 * Order yang sudah terlalu lama berada di keadaan yang seharusnya cepat berlalu.
 *
 * Cuma dua status yang dihitung. `MencariRunner` berarti klien sudah membayar dan belum ada
 * yang mengambil, dan itu keadaan terburuk yang bisa dialami sistem ini: uangnya sudah
 * masuk, pekerjaannya belum dimulai, kliennya menunggu. `Permintaan` berarti Jalur B yang
 * belum ditawar siapa pun.
 *
 * `MenungguPembayaran` sengaja tidak dihitung. Yang ditunggu di sana klien, bukan
 * organisasi, dan menandainya macet berarti menyuruh admin mengejar sesuatu yang memang
 * bukan urusannya.
 */
export function sedangMacet(order: Order, sekarang: Date = new Date()): boolean {
  if (order.status !== 'MencariRunner' && order.status !== 'Permintaan') return false;
  return menitSejak(order.dibuatPada, sekarang) >= AMBANG_MACET_MENIT;
}

export { AMBANG_MACET_MENIT };
