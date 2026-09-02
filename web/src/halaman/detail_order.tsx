import { useCallback, useState, type FormEvent } from 'react';
import { Link, useParams } from 'react-router-dom';

import { useSesi } from '../auth/sesi';
import { ambilOrder, daftarPesan, kirimPesan } from '../inti/api_admin';
import {
  formatDurasi,
  formatJadwal,
  formatRupiah,
  formatTanggalJam,
  formatWaktuRelatif,
  labelLayanan,
} from '../inti/format';
import { gunakanMuat } from '../inti/gunakan_muat';
import type { Order, Penawaran, Pesan, StatusPenawaran } from '../inti/tipe';
import { Kosong, KotakGalat, Memuat, pesanGalat } from '../komponen/keadaan';
import { LencanaJalur, LencanaStatus } from '../komponen/lencana';

/**
 * Satu order, dibaca admin.
 *
 * Layar ini menampilkan, tidak memutuskan. Admin tidak lagi menentukan harga Jalur B (itu
 * pindah jadi tawar-menawar antara klien dan runner), dan pembatalan beserta pengembalian
 * dana belum punya endpoint di backend sama sekali. Jadi yang ada di sini cuma dua: seluruh
 * keterangan order supaya admin bisa menjawab pertanyaan tentangnya, dan chat supaya ia
 * bisa turun tangan saat ordernya macet.
 *
 * Tombol yang tidak ada sengaja tidak dipalsukan. Tombol batalkan yang selalu dijawab 404
 * lebih buruk daripada tidak ada tombol sama sekali: yang pertama membuat orang mengira
 * pekerjaannya sudah selesai.
 */
export function HalamanDetailOrder() {
  const { id = '' } = useParams();
  const { api } = useSesi();

  const ambil = useCallback((sinyal: AbortSignal) => ambilOrder(api, id, sinyal), [api, id]);
  const { data: order, memuat, galat, muatUlang } = gunakanMuat(ambil, { segarkanBerkala: true });

  if (galat !== null && order === null) return <KotakGalat galat={galat} cobaLagi={muatUlang} />;
  if (memuat && order === null) return <Memuat />;
  if (order === null) return null;

  return (
    <section className="detail">
      <nav className="detail__jejak">
        <Link to="/order">&larr; Pantauan Order</Link>
      </nav>

      <header className="detail__kepala">
        <div>
          <h1>{order.kodeOrder}</h1>
          <p className="detail__ringkas">
            {labelLayanan(order.serviceType)} &middot; {order.namaKlien}
          </p>
        </div>
        <div className="detail__lencana">
          <LencanaStatus status={order.status} />
          <LencanaJalur jalur={order.track} />
        </div>
      </header>

      <div className="detail__kolom">
        <div className="detail__utama">
          <RincianOrder order={order} />
          <DaftarPenawaran order={order} />
        </div>
        <PanelChat order={order} />
      </div>
    </section>
  );
}

function RincianOrder({ order }: { order: Order }) {
  return (
    <article className="kartu">
      <h2>Rincian</h2>
      <dl className="rincian">
        <Baris label="Masuk">
          {formatTanggalJam(order.dibuatPada)} ({formatWaktuRelatif(order.dibuatPada)})
        </Baris>
        <Baris label="Harga disepakati">{formatRupiah(order.harga)}</Baris>
        {order.hargaUsulan !== null && (
          <Baris label="Harga usulan klien">{formatRupiah(order.hargaUsulan)}</Baris>
        )}
        {order.jarakKm !== null && <Baris label="Jarak">{order.jarakKm} km</Baris>}
        {order.alamatJemput && <Baris label="Alamat jemput">{order.alamatJemput}</Baris>}
        {order.alamatTujuan && <Baris label="Alamat tujuan">{order.alamatTujuan}</Baris>}
        {order.deskripsi && <Baris label="Kebutuhan klien">{order.deskripsi}</Baris>}
        {order.jadwalMulai && <Baris label="Jadwal">{formatJadwal(order.jadwalMulai)}</Baris>}
        {order.estimasiDurasiMenit !== null && (
          <Baris label="Estimasi durasi">{formatDurasi(order.estimasiDurasiMenit)}</Baris>
        )}
        <Baris label="Runner">
          {/* Yang dipunya API cuma id runnernya, bukan namanya, jadi yang ditampilkan
              apa adanya jumlahnya berbanding kuota. Menampilkan id mentah tidak menolong
              siapa pun, dan nama runner butuh endpoint yang belum ada. */}
          {order.runnerIds.length} dari {order.jumlahRunnerDibutuhkan} terisi
        </Baris>
        {order.dibayarPada && <Baris label="Dibayar">{formatTanggalJam(order.dibayarPada)}</Baris>}
        {order.selesaiPada && <Baris label="Selesai">{formatTanggalJam(order.selesaiPada)}</Baris>}
        {order.catatanSerahTerima && (
          <Baris label="Catatan serah terima">{order.catatanSerahTerima}</Baris>
        )}
      </dl>

      {order.fotoBuktiUrl && (
        <p className="detail__bukti">
          {/* Sengaja tautan, bukan gambar yang langsung digambar. Berkasnya dilayani
              BerkasBuktiController yang menuntut token di header Authorization, dan tag
              img tidak bisa mengirim header; yang muncul cuma gambar rusak. Membukanya di
              tab baru pun akan meminta masuk, dan itu kabar yang jujur, bukan kotak kosong. */}
          Foto bukti tersimpan di server. Butuh sesi yang sama untuk membukanya:{' '}
          <code>{order.fotoBuktiUrl}</code>
        </p>
      )}
    </article>
  );
}

function DaftarPenawaran({ order }: { order: Order }) {
  if (order.track !== 'JalurB') return null;

  return (
    <article className="kartu">
      <h2>Penawaran runner</h2>
      {order.penawaran.length === 0 ? (
        <Kosong keterangan="Belum ada runner yang menawar permintaan ini." />
      ) : (
        <table className="tabel tabel--rapat">
          <thead>
            <tr>
              <th scope="col">Harga</th>
              <th scope="col">Durasi</th>
              <th scope="col">Jadwal</th>
              <th scope="col">Status</th>
              <th scope="col">Diajukan</th>
            </tr>
          </thead>
          <tbody>
            {order.penawaran.map((penawaran) => (
              <BarisPenawaran key={penawaran.id} penawaran={penawaran} />
            ))}
          </tbody>
        </table>
      )}
    </article>
  );
}

function BarisPenawaran({ penawaran }: { penawaran: Penawaran }) {
  return (
    <tr>
      <td className="tabel__angka">{formatRupiah(penawaran.harga)}</td>
      <td>{formatDurasi(penawaran.estimasiDurasiMenit)}</td>
      <td>{formatJadwal(penawaran.jadwalMulai)}</td>
      <td>{labelStatusPenawaran(penawaran.status)}</td>
      <td title={penawaran.dibuatPada}>{formatWaktuRelatif(penawaran.dibuatPada)}</td>
    </tr>
  );
}

/**
 * "Ditutup" dan "Ditolak" sengaja disebut berbeda, mengikuti backend.
 *
 * Ditolak berarti klien menolak penawaran itu secara khusus; ditutup berarti klien memilih
 * runner lain dan penawaran ini gugur tanpa pernah disentuh. Untuk runner yang menanyakan
 * kenapa tawarannya tidak jadi, keduanya jawaban yang berbeda.
 */
function labelStatusPenawaran(status: StatusPenawaran): string {
  switch (status) {
    case 'Pending':
      return 'Menunggu jawaban klien';
    case 'Disetujui':
      return 'Disetujui';
    case 'Ditolak':
      return 'Ditolak klien';
    case 'DinegoUlang':
      return 'Diminta hitung ulang';
    case 'Ditutup':
      return 'Gugur, klien pilih runner lain';
  }
}

function PanelChat({ order }: { order: Order }) {
  const { api } = useSesi();
  const [draf, setDraf] = useState('');
  const [sibuk, setSibuk] = useState(false);
  const [galatKirim, setGalatKirim] = useState<unknown>(null);

  const ambil = useCallback(
    (sinyal: AbortSignal) => daftarPesan(api, order.id, 1, 50, sinyal),
    [api, order.id],
  );
  const { data, memuat, galat, muatUlang } = gunakanMuat(ambil, { segarkanBerkala: true });

  const chatDitutup = order.status === 'Selesai' || order.status === 'Batal';

  async function kirim(peristiwa: FormEvent) {
    peristiwa.preventDefault();
    const isi = draf.trim();
    if (isi.length === 0) return;

    setSibuk(true);
    setGalatKirim(null);
    try {
      await kirimPesan(api, order.id, isi);
      setDraf('');
      muatUlang();
    } catch (salah) {
      setGalatKirim(salah);
    } finally {
      setSibuk(false);
    }
  }

  return (
    <aside className="kartu kartu--chat">
      <h2>Obrolan umum</h2>
      <p className="chat__keterangan">
        {/* Keterbatasan yang harus disebut, bukan disembunyikan: backend cuma memberi admin
            obrolan umum. Jalur pribadi antara klien dan tiap runner yang sedang menawar
            tidak terlihat dari sini, dan untuk Jalur B yang masih menunggu tawaran, obrolan
            umumnya memang biasanya kosong. Admin yang tidak diberi tahu ini akan menyangka
            chatnya rusak. */}
        Admin cuma melihat obrolan umum order ini. Tawar-menawar antara klien dan tiap runner
        terjadi di jalur pribadi masing-masing, dan tidak tampil di sini.
      </p>

      {galat !== null && <KotakGalat galat={galat} cobaLagi={muatUlang} />}
      {memuat && data === null && <Memuat />}
      {data !== null && data.isi.length === 0 && <Kosong keterangan="Belum ada pesan." />}

      {data !== null && data.isi.length > 0 && (
        <ol className="chat">
          {data.isi.map((pesan) => (
            <Gelembung key={pesan.id} pesan={pesan} />
          ))}
        </ol>
      )}

      {chatDitutup ? (
        <p className="chat__ditutup">
          Order ini sudah {order.status.toLowerCase()}, chatnya ditutup. Kalau masih ada urusan,
          urusan itu butuh order baru.
        </p>
      ) : (
        <form className="chat__kirim" onSubmit={kirim}>
          <label className="tersembunyi" htmlFor="pesan">
            Tulis pesan
          </label>
          <textarea
            id="pesan"
            rows={3}
            maxLength={1000}
            value={draf}
            disabled={sibuk}
            placeholder="Tulis sebagai admin..."
            onChange={(e) => setDraf(e.target.value)}
          />
          <button type="submit" className="tombol" disabled={sibuk || draf.trim().length === 0}>
            {sibuk ? 'Mengirim...' : 'Kirim'}
          </button>
        </form>
      )}

      {galatKirim !== null && (
        <p className="keadaan keadaan--galat" role="alert">
          {pesanGalat(galatKirim)}
        </p>
      )}
    </aside>
  );
}

function Gelembung({ pesan }: { pesan: Pesan }) {
  return (
    <li className={'gelembung gelembung--' + pesan.peranPengirim.toLowerCase()}>
      <span className="gelembung__peran">{pesan.peranPengirim}</span>
      <p>{pesan.isi}</p>
      <time dateTime={pesan.dikirimPada}>{formatTanggalJam(pesan.dikirimPada)}</time>
    </li>
  );
}

function Baris({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <>
      <dt>{label}</dt>
      <dd>{children}</dd>
    </>
  );
}
