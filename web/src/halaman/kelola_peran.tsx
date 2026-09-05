import { useCallback, useEffect, useState, type FormEvent } from 'react';

import { useSesi, usePengguna } from '../auth/sesi';
import {
  cariPengguna,
  pelepasanOrder,
  pulihkanAkun,
  riwayatPenangguhan,
  riwayatPeran,
  tangguhkanAkun,
  tetapkanPeran,
} from '../inti/api_admin';
import { formatTanggalJam, formatWaktuRelatif } from '../inti/format';
import { gunakanMuat } from '../inti/gunakan_muat';
import { gunakanTunda } from '../inti/gunakan_tunda';
import type { Pengguna, Peran } from '../inti/tipe';
import { Kosong, KotakGalat, Memuat, pesanGalat } from '../komponen/keadaan';

/**
 * Kelola peran pengguna: mencari akun, lalu mengubah peran yang dipegangnya.
 *
 * Satu-satunya jalan seseorang bisa menjadi runner atau admin (lihat `AdminPenggunaController`
 * di backend). Endpoint pencarian tidak menyediakan "ambil satu pengguna lewat id", cuma
 * pencarian kata kunci yang mengembalikan larik, jadi layar ini sengaja tidak dibuat sebagai
 * dua rute terpisah (`/pengguna` dan `/pengguna/:id`) seperti pantauan order: itu akan
 * menjanjikan tautan langsung ke satu pengguna yang tidak bisa dipulihkan sesudah dimuat
 * ulang. Pengguna yang sedang dikelola cuma hidup sebagai state di komponen ini, berasal
 * dari baris yang diklik di hasil pencarian.
 */

const PANJANG_KATA_KUNCI_MINIMAL = 3;

const seluruhPeran: Peran[] = ['Klien', 'Runner', 'Admin'];

export function HalamanKelolaPeran() {
  const { api } = useSesi();
  const [kataKunci, setKataKunci] = useState('');
  const kataKunciTertunda = gunakanTunda(kataKunci.trim(), 300);
  const [hanyaTertangguh, setHanyaTertangguh] = useState(false);
  const [dipilih, setDipilih] = useState<Pengguna | null>(null);

  // Kata kunci wajib hanya saat mencari di seluruh pengguna. Daftar akun tertangguh
  // adalah himpunan kecil yang memang perlu ditinjau seluruhnya, jadi ia layak diminta
  // tanpa kata kunci sama sekali — dan tanpa itu, admin yang diminta memulihkan sebuah
  // akun harus mengingat namanya lebih dulu.
  const layakDicari =
    hanyaTertangguh || kataKunciTertunda.length >= PANJANG_KATA_KUNCI_MINIMAL;

  const ambil = useCallback(
    (sinyal: AbortSignal) =>
      layakDicari
        ? cariPengguna(api, kataKunciTertunda, hanyaTertangguh, sinyal)
        : Promise.resolve([]),
    [api, kataKunciTertunda, hanyaTertangguh, layakDicari],
  );

  const { data: hasil, memuat, galat, muatUlang } = gunakanMuat(ambil);

  return (
    <section className="kelola-peran">
      <header>
        <h1>Kelola Peran</h1>
      </header>

      <div className="kelola-peran__kolom">
        <div className="kartu">
          <label htmlFor="kataKunci">Cari nama atau nomor HP</label>
          <input
            id="kataKunci"
            type="search"
            value={kataKunci}
            onChange={(e) => setKataKunci(e.target.value)}
            placeholder="Minimal 3 huruf..."
          />

          {kataKunciTertunda.length > 0 && !layakDicari && (
            <p className="kelola-peran__petunjuk">
              Isi minimal {PANJANG_KATA_KUNCI_MINIMAL} huruf dari nama atau nomor HP-nya.
            </p>
          )}

          {/* Di sebelah kotak pencarian, bukan sebagai daftar tersendiri di layar lain.
              Yang dilakukan admin sesudah menemukan akun tertangguh sama persis dengan
              yang ia lakukan sesudah mencarinya lewat nama: membuka panelnya, lalu
              memulihkan atau menyunting perannya. */}
          <label className="cek">
            <input
              type="checkbox"
              checked={hanyaTertangguh}
              onChange={(e) => setHanyaTertangguh(e.target.checked)}
            />
            Hanya akun yang ditangguhkan
          </label>

          {galat !== null && <KotakGalat galat={galat} cobaLagi={muatUlang} />}
          {layakDicari && memuat && hasil === null && <Memuat />}
          {layakDicari && hasil !== null && hasil.length === 0 && (
            <Kosong
              keterangan={
                hanyaTertangguh
                  ? 'Tidak ada akun yang sedang ditangguhkan.'
                  : 'Tidak ada akun yang cocok.'
              }
            />
          )}

          {hasil !== null && hasil.length > 0 && (
            <ul className="daftar-pengguna">
              {hasil.map((pengguna) => (
                <li key={pengguna.id}>
                  <button
                    type="button"
                    className={
                      pengguna.id === dipilih?.id
                        ? 'daftar-pengguna__baris daftar-pengguna__baris--aktif'
                        : 'daftar-pengguna__baris'
                    }
                    onClick={() => setDipilih(pengguna)}
                  >
                    <span className="daftar-pengguna__nama">{pengguna.nama}</span>
                    <span className="daftar-pengguna__hp">{pengguna.noHp}</span>
                    <span className="daftar-pengguna__peran">
                      {pengguna.roles.length > 0 ? pengguna.roles.join(', ') : 'tanpa peran'}
                    </span>
                    {/* Ditandai juga di hasil pencarian biasa, bukan cuma saat penyaringnya
                        menyala: admin yang mencari nama untuk mengubah perannya perlu tahu
                        akun itu sedang berhenti sebelum ia mengkliknya, bukan sesudahnya. */}
                    {pengguna.ditangguhkanPada !== null && (
                      <span className="daftar-pengguna__tanda">ditangguhkan</span>
                    )}
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        {dipilih && (
          <PanelPengguna
            key={dipilih.id}
            pengguna={dipilih}
            onBerubah={(diperbarui) => setDipilih(diperbarui)}
          />
        )}
      </div>
    </section>
  );
}

function PanelPengguna({
  pengguna,
  onBerubah,
}: {
  pengguna: Pengguna;
  onBerubah: (diperbarui: Pengguna) => void;
}) {
  const { api } = useSesi();
  const pengirim = usePengguna();

  const [rolesDipilih, setRolesDipilih] = useState<Peran[]>(pengguna.roles);
  const [alasan, setAlasan] = useState('');
  const [sibuk, setSibuk] = useState(false);
  const [galat, setGalat] = useState<unknown>(null);
  const [penandaRiwayat, setPenandaRiwayat] = useState(0);
  const [penandaPenangguhan, setPenandaPenangguhan] = useState(0);

  // Peran yang ditampilkan mengikuti pengguna yang sedang dipilih, bukan menyisakan
  // pilihan dari akun sebelumnya. Efeknya cuma berjalan saat identitas pengguna berganti
  // (dijaga lewat `key={dipilih.id}` di pemanggilnya), bukan setiap kali objeknya
  // dibangun ulang, jadi tidak menimpa perubahan checkbox yang sedang diketik admin.
  useEffect(() => {
    setRolesDipilih(pengguna.roles);
    setAlasan('');
    setGalat(null);
  }, [pengguna]);

  function tukarPeran(peran: Peran) {
    setRolesDipilih((sebelumnya) =>
      sebelumnya.includes(peran)
        ? sebelumnya.filter((p) => p !== peran)
        : [...sebelumnya, peran],
    );
  }

  const adaPerubahan =
    rolesDipilih.length !== pengguna.roles.length ||
    !rolesDipilih.every((p) => pengguna.roles.includes(p));

  const mengubahDiriSendiri = pengirim?.id === pengguna.id;

  async function simpan(peristiwa: FormEvent) {
    peristiwa.preventDefault();
    setSibuk(true);
    setGalat(null);
    try {
      const diperbarui = await tetapkanPeran(api, pengguna.id, rolesDipilih, alasan.trim());
      onBerubah(diperbarui);
      setAlasan('');
      // Riwayat dimuat ulang lewat penanda, bukan langsung menyisipkan barisnya di sini:
      // baris yang benar (id, waktu server) cuma diketahui setelah diminta ulang, dan
      // menambahkan tebakan sendiri berarti ada dua sumber kebenaran untuk hal yang sama.
      setPenandaRiwayat((n) => n + 1);
    } catch (salah) {
      setGalat(salah);
    } finally {
      setSibuk(false);
    }
  }

  return (
    <div className="kartu kartu--panel-pengguna">
      <h2>{pengguna.nama}</h2>
      <p className="panel-pengguna__hp">{pengguna.noHp}</p>

      {/* Berdiri paling atas, sebelum apa pun yang bisa diubah admin. Peran akun yang
          sedang ditangguhkan tetap boleh disunting — itu bukan kontradiksi, tapi admin
          harus tahu lebih dulu bahwa akunnya memang sedang berhenti, supaya ia tidak
          mengira perubahan peran yang ia simpan akan langsung dipakai orangnya. */}
      {pengguna.ditangguhkanPada !== null && (
        <p className="keadaan keadaan--galat" role="status">
          Akun ini ditangguhkan {formatWaktuRelatif(pengguna.ditangguhkanPada)}.
          {pengguna.alasanPenangguhan !== null && ` Alasannya: ${pengguna.alasanPenangguhan}`}
        </p>
      )}

      <form onSubmit={simpan} className="panel-pengguna__form">
        <fieldset>
          <legend>Peran</legend>
          {seluruhPeran.map((peran) => (
            <label key={peran} className="cek">
              <input
                type="checkbox"
                checked={rolesDipilih.includes(peran)}
                onChange={() => tukarPeran(peran)}
                disabled={sibuk}
              />
              {peran}
            </label>
          ))}
        </fieldset>

        {mengubahDiriSendiri && rolesDipilih.length > 0 && !rolesDipilih.includes('Admin') && (
          <p className="panel-pengguna__peringatan">
            {/* Backend menolak ini (admin tidak boleh mencabut peran adminnya sendiri), tapi
                menunggu penolakan server untuk hal yang sudah pasti ditolak cuma membuang
                satu bolak-balik jaringan. Peringatan ini bukan pengganti penjagaan backend,
                cuma menghindarkan kejutannya. */}
            Ini akun kamu sendiri. Mencabut peran admin dari akun sendiri akan ditolak server.
          </p>
        )}

        <label htmlFor="alasan">Alasan perubahan</label>
        <textarea
          id="alasan"
          rows={2}
          maxLength={2000}
          required
          value={alasan}
          disabled={sibuk}
          onChange={(e) => setAlasan(e.target.value)}
        />

        <button
          type="submit"
          className="tombol"
          disabled={sibuk || !adaPerubahan || alasan.trim().length === 0}
        >
          {sibuk ? 'Menyimpan...' : 'Simpan perubahan peran'}
        </button>
      </form>

      {galat !== null && (
        <p className="keadaan keadaan--galat" role="alert">
          {pesanGalat(galat)}
        </p>
      )}

      <PanelPenangguhan
        pengguna={pengguna}
        mengubahDiriSendiri={mengubahDiriSendiri}
        onBerubah={(diperbarui) => {
          onBerubah(diperbarui);
          setPenandaPenangguhan((n) => n + 1);
        }}
      />

      {/* Menempel langsung di bawah tombolnya, bukan di antara dua daftar audit lain di
          bawah, karena inilah yang paling dibutuhkan orang yang jarinya sedang berada di
          atas tombol itu: akun yang sudah tiga kali dihentikan lalu dikembalikan adalah
          keputusan yang berbeda dari akun yang baru pertama kali dipersoalkan. */}
      <RiwayatPenangguhan userId={pengguna.id} penanda={penandaPenangguhan} />

      {/* Berdiri di atas riwayat peran, bukan di bawahnya, dan urutannya disengaja:
          ini bukti yang dipakai memutuskan, sedangkan riwayat peran catatan keputusan
          yang sudah diambil. Yang membuka panel ini biasanya sedang menimbang, bukan
          sedang menelusuri apa yang pernah ia lakukan sendiri. */}
      <PelepasanRunner userId={pengguna.id} />

      <RiwayatPeran userId={pengguna.id} penanda={penandaRiwayat} />
    </div>
  );
}

/**
 * Order yang pernah dilepas runner ini sesudah menerimanya.
 *
 * Ditampilkan untuk setiap akun, bukan cuma yang berperan runner, dan itu bukan
 * kelalaian: runner yang perannya baru saja dicabut adalah persis akun yang paling
 * mungkin sedang dipersoalkan, dan menyembunyikan catatannya karena perannya sudah
 * hilang berarti menyembunyikannya tepat saat ia paling dibutuhkan.
 */
function PelepasanRunner({ userId }: { userId: string }) {
  const { api } = useSesi();

  const ambil = useCallback(
    (sinyal: AbortSignal) => pelepasanOrder(api, userId, { ukuran: 20 }, sinyal),
    [api, userId],
  );

  const { data, memuat, galat, muatUlang } = gunakanMuat(ambil);

  return (
    <div className="riwayat-peran">
      <h3>Order yang pernah dilepas{data !== null && data.total > 0 && ` (${data.total})`}</h3>

      {galat !== null && <KotakGalat galat={galat} cobaLagi={muatUlang} />}
      {memuat && data === null && <Memuat />}
      {data !== null && data.isi.length === 0 && (
        <Kosong keterangan="Akun ini belum pernah melepas order yang sudah diterimanya." />
      )}

      {data !== null && data.isi.length > 0 && (
        <ol className="riwayat-peran__daftar">
          {data.isi.map((baris) => (
            <li key={baris.id}>
              <p className="riwayat-peran__perubahan">{baris.kodeOrder}</p>
              <p className="riwayat-peran__alasan">{baris.alasan}</p>
              <time dateTime={baris.dilepasPada}>{formatTanggalJam(baris.dilepasPada)}</time>
            </li>
          ))}
        </ol>
      )}
    </div>
  );
}

/**
 * Riwayat penangguhan dan pemulihan akun ini.
 *
 * Kolom penangguhan di akunnya cuma menyimpan yang terakhir: menangguhkan ulang menimpanya,
 * dan memulihkan mengosongkannya. Daftar ini satu-satunya tempat yang bisa menjawab "sudah
 * berapa kali", dan satu-satunya tempat alasan memulihkan bisa dibaca sama sekali.
 */
function RiwayatPenangguhan({ userId, penanda }: { userId: string; penanda: number }) {
  const { api } = useSesi();

  const ambil = useCallback(
    (sinyal: AbortSignal) => riwayatPenangguhan(api, userId, { ukuran: 20 }, sinyal),
    [api, userId],
  );

  const { data, memuat, galat, muatUlang } = gunakanMuat(ambil);

  // Alasannya sama dengan riwayat peran: `muatUlang` dibuat ulang setiap render oleh
  // gunakanMuat, jadi memasukkannya ke dependensi berarti mengambil ulang setiap render.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (penanda > 0) muatUlang();
  }, [penanda]);

  return (
    <div className="riwayat-peran">
      <h3>Riwayat penangguhan{data !== null && data.total > 0 && ` (${data.total})`}</h3>

      {galat !== null && <KotakGalat galat={galat} cobaLagi={muatUlang} />}
      {memuat && data === null && <Memuat />}
      {data !== null && data.isi.length === 0 && (
        <Kosong keterangan="Akun ini belum pernah ditangguhkan." />
      )}

      {data !== null && data.isi.length > 0 && (
        <ol className="riwayat-peran__daftar">
          {data.isi.map((baris) => (
            <li key={baris.id}>
              <p className="riwayat-peran__perubahan">
                {baris.ditangguhkan ? 'Ditangguhkan' : 'Dipulihkan'}
              </p>
              <p className="riwayat-peran__alasan">{baris.alasan}</p>
              <time dateTime={baris.diubahPada}>{formatTanggalJam(baris.diubahPada)}</time>{' '}
              <span className="riwayat-peran__oleh">oleh {baris.namaAdmin}</span>
            </li>
          ))}
        </ol>
      )}
    </div>
  );
}

function RiwayatPeran({ userId, penanda }: { userId: string; penanda: number }) {
  const { api } = useSesi();

  const ambil = useCallback(
    (sinyal: AbortSignal) => riwayatPeran(api, userId, { ukuran: 20 }, sinyal),
    [api, userId],
  );

  const { data, memuat, galat, muatUlang } = gunakanMuat(ambil);

  // Riwayat dimuat ulang setiap `penanda` berubah, yaitu setiap kali perubahan peran baru
  // berhasil disimpan. `muatUlang` sengaja tidak dimasukkan ke daftar dependensi: ia
  // dibuat ulang setiap render oleh gunakanMuat, dan memasukkannya akan memicu pengambilan
  // setiap render, bukan cuma saat penandanya berganti.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (penanda > 0) muatUlang();
  }, [penanda]);

  return (
    <div className="riwayat-peran">
      <h3>Riwayat perubahan</h3>

      {galat !== null && <KotakGalat galat={galat} cobaLagi={muatUlang} />}
      {memuat && data === null && <Memuat />}
      {data !== null && data.isi.length === 0 && (
        <Kosong keterangan="Belum ada perubahan peran untuk akun ini." />
      )}

      {data !== null && data.isi.length > 0 && (
        <ol className="riwayat-peran__daftar">
          {data.isi.map((baris) => (
            <li key={baris.id}>
              <p className="riwayat-peran__perubahan">
                {baris.sebelum.join(', ') || 'tanpa peran'} &rarr;{' '}
                {baris.sesudah.join(', ') || 'tanpa peran'}
              </p>
              <p className="riwayat-peran__alasan">{baris.alasan}</p>
              <time dateTime={baris.diubahPada}>{formatTanggalJam(baris.diubahPada)}</time>{' '}
              <span className="riwayat-peran__oleh">oleh {baris.namaAdmin}</span>
            </li>
          ))}
        </ol>
      )}
    </div>
  );
}

/**
 * Menghentikan sebuah akun, atau memulihkannya.
 *
 * Berdiri terpisah dari form peran, dan bukan sekadar demi tata letak: mengubah peran
 * mempersempit apa yang bisa dikerjakan seseorang, sedangkan ini menghentikannya sama
 * sekali. Menyatukan keduanya di satu tombol simpan berarti satu kesalahan klik bisa
 * menghentikan orang yang sebenarnya cuma mau diubah perannya.
 *
 * Formnya tertutup sampai diminta, mengikuti panel pembatalan di layar detail order: yang
 * tidak mencarinya tidak akan tersenggol, dan yang mencarinya menemukannya.
 */
function PanelPenangguhan({
  pengguna,
  mengubahDiriSendiri,
  onBerubah,
}: {
  pengguna: Pengguna;
  mengubahDiriSendiri: boolean;
  onBerubah: (diperbarui: Pengguna) => void;
}) {
  const { api } = useSesi();
  const [terbuka, setTerbuka] = useState(false);
  const [alasan, setAlasan] = useState('');
  const [sibuk, setSibuk] = useState(false);
  const [galat, setGalat] = useState<unknown>(null);

  const ditangguhkan = pengguna.ditangguhkanPada !== null;

  // Backend menolaknya (admin tidak boleh menangguhkan akunnya sendiri), dan alasannya sama
  // dengan peringatan di form peran: menunggu penolakan server untuk hal yang sudah pasti
  // ditolak cuma membuang satu bolak-balik jaringan.
  if (mengubahDiriSendiri && !ditangguhkan) {
    return (
      <p className="panel-pengguna__peringatan">
        Ini akun kamu sendiri, jadi tidak bisa ditangguhkan dari sini.
      </p>
    );
  }

  async function kirim(peristiwa: FormEvent) {
    peristiwa.preventDefault();
    setSibuk(true);
    setGalat(null);
    try {
      const diperbarui = ditangguhkan
        ? await pulihkanAkun(api, pengguna.id, alasan.trim())
        : await tangguhkanAkun(api, pengguna.id, alasan.trim());
      onBerubah(diperbarui);
      setAlasan('');
      setTerbuka(false);
    } catch (salah) {
      setGalat(salah);
    } finally {
      setSibuk(false);
    }
  }

  return (
    <div className="panel-pengguna__penangguhan">
      {!terbuka ? (
        <button
          type="button"
          className="tombol tombol--halus"
          onClick={() => setTerbuka(true)}
        >
          {ditangguhkan ? 'Pulihkan akun ini' : 'Tangguhkan akun ini'}
        </button>
      ) : (
        <form onSubmit={kirim}>
          <label htmlFor="alasanTangguh">
            {ditangguhkan ? 'Alasan memulihkan' : 'Alasan menangguhkan'}
          </label>
          <textarea
            id="alasanTangguh"
            rows={2}
            maxLength={2000}
            required
            autoFocus
            value={alasan}
            disabled={sibuk}
            placeholder={
              ditangguhkan
                ? 'Misal: sudah dijelaskan, ternyata salah paham.'
                : 'Misal: memesan lalu minta batal berulang kali.'
            }
            onChange={(e) => setAlasan(e.target.value)}
          />
          <div className="pembatalan__tombol">
            <button
              type="submit"
              className="tombol"
              disabled={sibuk || alasan.trim().length === 0}
            >
              {sibuk
                ? 'Menyimpan...'
                : ditangguhkan
                  ? 'Ya, pulihkan akun ini'
                  : 'Ya, tangguhkan akun ini'}
            </button>
            <button
              type="button"
              className="tombol tombol--halus"
              disabled={sibuk}
              onClick={() => {
                setTerbuka(false);
                setAlasan('');
                setGalat(null);
              }}
            >
              Urungkan
            </button>
          </div>
          {!ditangguhkan && (
            <p className="panel-pengguna__peringatan">
              Berlaku seketika: orangnya langsung keluar dari aplikasi, tanpa menunggu
              sesinya habis. Ordernya tidak ikut terhapus.
            </p>
          )}
          {galat !== null && (
            <p className="keadaan keadaan--galat" role="alert">
              {pesanGalat(galat)}
            </p>
          )}
        </form>
      )}
    </div>
  );
}
