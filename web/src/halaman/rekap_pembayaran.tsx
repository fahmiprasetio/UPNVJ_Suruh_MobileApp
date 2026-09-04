import { useCallback, useEffect, useState, type FormEvent } from 'react';

import { useSesi } from '../auth/sesi';
import {
  perbaruiPayoutSetting,
  rekapPayout,
  rincianPayout,
  tandaiLunas,
} from '../inti/api_admin';
import { formatRupiah, formatTanggalJam, labelLayanan } from '../inti/format';
import { gunakanMuat } from '../inti/gunakan_muat';
import type { ModeKomisi, PayoutSetting, RekapRunner, RincianPayout } from '../inti/tipe';
import { Kosong, KotakGalat, Memuat, pesanGalat } from '../komponen/keadaan';

/**
 * Rekap pembayaran runner: siapa harus dibayar berapa, dan rumus bagi hasil di baliknya.
 *
 * Rumusnya ditaruh di halaman yang sama, bukan di layar tersendiri seperti Kelola Tarif,
 * karena keduanya adalah satu pertanyaan yang sama dari sudut yang berbeda. Rekap ini tidak
 * punya satu angka pun sebelum rumusnya ada, jadi admin yang membukanya untuk pertama kali
 * harus menemukan penyebabnya di halaman yang sedang ia lihat, bukan disuruh mencarinya di
 * menu lain.
 */
export function HalamanRekapPembayaran() {
  const { api } = useSesi();
  const [dipilih, setDipilih] = useState<string | null>(null);

  const ambil = useCallback((sinyal: AbortSignal) => rekapPayout(api, sinyal), [api]);
  const { data: rekap, memuat, galat, muatUlang } = gunakanMuat(ambil);

  return (
    <section className="rekap">
      <header>
        <h1>Rekap Pembayaran Runner</h1>
        <p className="rekap__keterangan">
          Bayaran dihitung sekali saat ordernya selesai dan tidak berubah lagi sesudah itu,
          jadi mengubah rumus di bawah cuma berlaku untuk order yang selesai berikutnya.
        </p>
      </header>

      {galat !== null && <KotakGalat galat={galat} cobaLagi={muatUlang} />}
      {memuat && rekap === null && <Memuat />}

      {rekap !== null && (
        <>
          <FormRumus
            key={rekap.setting.diaturPada ?? 'belum'}
            setting={rekap.setting}
            menunggu={rekap.totalMenungguRumus}
            onDisimpan={muatUlang}
          />

          <TabelRunner
            runner={rekap.runner}
            totalBelumDibayar={rekap.totalBelumDibayar}
            dipilih={dipilih}
            onPilih={setDipilih}
          />

          {dipilih !== null && (
            <PanelRincian
              key={dipilih}
              runnerId={dipilih}
              onDilunasi={() => {
                setDipilih(null);
                muatUlang();
              }}
              onTutup={() => setDipilih(null)}
            />
          )}
        </>
      )}
    </section>
  );
}

/**
 * Rumus bagi hasil.
 *
 * Selama belum pernah disimpan, seluruh kartunya berbicara lebih dulu tentang itu: order
 * yang sudah selesai selama masa itu tidak punya angka bayaran sama sekali, dan angka nol di
 * rekap bukan berarti runner memang tidak dapat apa-apa.
 */
function FormRumus({
  setting,
  menunggu,
  onDisimpan,
}: {
  setting: PayoutSetting;
  menunggu: number;
  onDisimpan: () => void;
}) {
  const { api } = useSesi();

  const [mode, setMode] = useState<ModeKomisi>(setting.mode);
  const [persen, setPersen] = useState(setting.komisiPersen);
  const [tetap, setTetap] = useState(setting.komisiTetap);
  const [sibuk, setSibuk] = useState(false);
  const [galat, setGalat] = useState<unknown>(null);
  const [tersimpan, setTersimpan] = useState(false);

  useEffect(() => {
    setMode(setting.mode);
    setPersen(setting.komisiPersen);
    setTetap(setting.komisiTetap);
  }, [setting]);

  async function simpan(peristiwa: FormEvent) {
    peristiwa.preventDefault();
    setSibuk(true);
    setGalat(null);
    setTersimpan(false);
    try {
      await perbaruiPayoutSetting(api, { mode, komisiPersen: persen, komisiTetap: tetap });
      setTersimpan(true);
      onDisimpan();
    } catch (salah) {
      setGalat(salah);
    } finally {
      setSibuk(false);
    }
  }

  return (
    <form className="kartu rekap__rumus" onSubmit={simpan}>
      <h2>Bagi Hasil</h2>

      {!setting.sudahDiatur && (
        <p className="rekap__peringatan" role="status">
          Rumus bagi hasil belum pernah diatur, jadi belum ada satu pun bayaran yang dihitung.
          {menunggu > 0 && ` ${menunggu} bayaran sedang menunggu rumus ini.`} Begitu disimpan,
          yang menunggu itu ikut dihitung.
        </p>
      )}

      <fieldset>
        <legend>Potongan organisasi tiap order</legend>

        <label className="rekap__pilihan">
          <input
            type="radio"
            name="mode"
            value="Persen"
            checked={mode === 'Persen'}
            disabled={sibuk}
            onChange={() => {
              setMode('Persen');
              setTersimpan(false);
            }}
          />
          <span>Persen dari harga order</span>
          <input
            type="number"
            aria-label="Komisi organisasi (%)"
            min="0"
            max="100"
            step="0.5"
            value={persen}
            disabled={sibuk || mode !== 'Persen'}
            onChange={(e) => {
              setPersen(Number(e.target.value) || 0);
              setTersimpan(false);
            }}
          />
        </label>

        <label className="rekap__pilihan">
          <input
            type="radio"
            name="mode"
            value="Tetap"
            checked={mode === 'Tetap'}
            disabled={sibuk}
            onChange={() => {
              setMode('Tetap');
              setTersimpan(false);
            }}
          />
          <span>Rupiah tetap tiap order</span>
          <input
            type="number"
            aria-label="Komisi organisasi (Rp)"
            min="0"
            step="500"
            value={tetap}
            disabled={sibuk || mode !== 'Tetap'}
            onChange={(e) => {
              setTetap(Number(e.target.value) || 0);
              setTersimpan(false);
            }}
          />
        </label>
      </fieldset>

      <p className="rekap__catatan">
        {/* Batasan yang harus dikatakan, bukan dianggap sudah jelas: order yang dikerjakan
            beberapa runner sekaligus (pindah kos) membagi sisanya rata, karena mitra belum
            menentukan apakah ada penanggung jawab yang dapat lebih (rencana bagian 14.7d). */}
        Sisanya dibagi rata antar runner pada order yang dikerjakan lebih dari satu orang.
      </p>

      <div className="rekap__kaki-rumus">
        <p className="rekap__diubah">
          {setting.diaturPada
            ? `Terakhir diatur ${formatTanggalJam(setting.diaturPada)}`
            : 'Belum pernah diatur'}
        </p>
        <button type="submit" className="tombol" disabled={sibuk}>
          {sibuk ? 'Menyimpan...' : 'Simpan rumus'}
        </button>
      </div>

      {tersimpan && !sibuk && galat === null && (
        <p className="rekap__berhasil" role="status">
          Tersimpan. Berlaku untuk order yang selesai berikutnya; bayaran yang sudah dihitung
          tidak berubah.
        </p>
      )}

      {galat !== null && (
        <p className="keadaan keadaan--galat" role="alert">
          {pesanGalat(galat)}
        </p>
      )}
    </form>
  );
}

function TabelRunner({
  runner,
  totalBelumDibayar,
  dipilih,
  onPilih,
}: {
  runner: RekapRunner[];
  totalBelumDibayar: number;
  dipilih: string | null;
  onPilih: (id: string | null) => void;
}) {
  if (runner.length === 0) {
    return <Kosong keterangan="Belum ada runner yang menyelesaikan order." />;
  }

  return (
    <>
      <table className="tabel rekap__tabel">
        <thead>
          <tr>
            <th>Runner</th>
            <th className="tabel__angka">Order belum dibayar</th>
            <th className="tabel__angka">Harus dibayar</th>
            <th className="tabel__angka">Sudah dibayar</th>
            <th>Terakhir dibayar</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {runner.map((r) => (
            <tr key={r.runnerId}>
              <td>
                <strong>{r.nama}</strong>
                <br />
                <span className="rekap__telepon">{r.telepon}</span>
              </td>
              <td className="tabel__angka">
                {r.jumlahOrderBelumDibayar}
                {r.menungguRumus > 0 && (
                  <>
                    <br />
                    <span className="rekap__menunggu">+{r.menungguRumus} menunggu rumus</span>
                  </>
                )}
              </td>
              <td className="tabel__angka">{formatRupiah(r.totalBelumDibayar)}</td>
              <td className="tabel__angka">{formatRupiah(r.totalSudahDibayar)}</td>
              <td>{r.terakhirDibayarPada ? formatTanggalJam(r.terakhirDibayarPada) : '-'}</td>
              <td>
                <button
                  type="button"
                  className="tombol tombol--halus"
                  onClick={() => onPilih(dipilih === r.runnerId ? null : r.runnerId)}
                >
                  {dipilih === r.runnerId ? 'Tutup' : 'Rincian'}
                </button>
              </td>
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr>
            <td colSpan={2}>Total harus dibayar</td>
            <td className="tabel__angka">
              <strong>{formatRupiah(totalBelumDibayar)}</strong>
            </td>
            <td colSpan={3} />
          </tr>
        </tfoot>
      </table>
    </>
  );
}

/**
 * Order mana saja yang membentuk tagihan seorang runner, dan tombol menandainya lunas.
 *
 * Tiap baris punya centangnya sendiri, semuanya tercentang saat dibuka. Bukan tombol
 * "lunasi semua" tunggal: admin yang cuma sanggup membayar sebagian minggu ini harus bisa
 * mencatat yang sebagian itu, dan yang terkirim ke server persis baris yang tercentang,
 * bukan "semua yang belum lunas pada saat permintaan tiba".
 */
function PanelRincian({
  runnerId,
  onDilunasi,
  onTutup,
}: {
  runnerId: string;
  onDilunasi: () => void;
  onTutup: () => void;
}) {
  const { api } = useSesi();

  const ambil = useCallback(
    (sinyal: AbortSignal) => rincianPayout(api, runnerId, {}, sinyal),
    [api, runnerId],
  );
  const { data: rincian, memuat, galat, muatUlang } = gunakanMuat(ambil);

  return (
    <div className="kartu rekap__panel">
      {galat !== null && <KotakGalat galat={galat} cobaLagi={muatUlang} />}
      {memuat && rincian === null && <Memuat />}
      {rincian !== null && (
        <IsiRincian rincian={rincian} onDilunasi={onDilunasi} onTutup={onTutup} />
      )}
    </div>
  );
}

function IsiRincian({
  rincian,
  onDilunasi,
  onTutup,
}: {
  rincian: RincianPayout;
  onDilunasi: () => void;
  onTutup: () => void;
}) {
  const { api } = useSesi();

  // Cuma baris yang sudah punya angka yang boleh dicentang. Yang belum dihitung memang
  // ditolak server, dan menawarkan centang untuk sesuatu yang pasti ditolak cuma membuat
  // admin menemukan penolakannya sesudah menekan tombol.
  const bisaDilunasi = rincian.belumDibayar.filter((b) => b.jumlah !== null);

  const [tercentang, setTercentang] = useState<string[]>(() =>
    bisaDilunasi.map((b) => b.penugasanId),
  );
  const [sibuk, setSibuk] = useState(false);
  const [galat, setGalat] = useState<unknown>(null);

  const total = bisaDilunasi
    .filter((b) => tercentang.includes(b.penugasanId))
    .reduce((jumlah, b) => jumlah + (b.jumlah ?? 0), 0);

  function ubahCentang(id: string) {
    setTercentang((sebelumnya) =>
      sebelumnya.includes(id) ? sebelumnya.filter((x) => x !== id) : [...sebelumnya, id],
    );
    setGalat(null);
  }

  async function lunasi() {
    setSibuk(true);
    setGalat(null);
    try {
      await tandaiLunas(api, rincian.runnerId, tercentang);
      onDilunasi();
    } catch (salah) {
      setGalat(salah);
      setSibuk(false);
    }
  }

  return (
    <>
      <header className="rekap__panel-kepala">
        <h2>{rincian.nama}</h2>
        <button type="button" className="tombol tombol--halus" onClick={onTutup}>
          Tutup
        </button>
      </header>

      {rincian.belumDibayar.length === 0 ? (
        <Kosong keterangan="Tidak ada bayaran yang menunggu diserahkan." />
      ) : (
        <>
          <table className="tabel tabel--rapat">
            <thead>
              <tr>
                <th />
                <th>Order</th>
                <th>Layanan</th>
                <th>Selesai</th>
                <th className="tabel__angka">Bayaran</th>
              </tr>
            </thead>
            <tbody>
              {rincian.belumDibayar.map((b) => (
                <tr key={b.penugasanId}>
                  <td>
                    <input
                      type="checkbox"
                      aria-label={`Bayaran order ${b.kodeOrder}`}
                      checked={tercentang.includes(b.penugasanId)}
                      disabled={sibuk || b.jumlah === null}
                      onChange={() => ubahCentang(b.penugasanId)}
                    />
                  </td>
                  <td className="tautan-kode">{b.kodeOrder}</td>
                  <td>{labelLayanan(b.layanan)}</td>
                  <td>{b.selesaiPada ? formatTanggalJam(b.selesaiPada) : '-'}</td>
                  <td className="tabel__angka">
                    {b.jumlah === null ? (
                      <span className="rekap__menunggu">menunggu rumus</span>
                    ) : (
                      formatRupiah(b.jumlah)
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>

          <div className="rekap__kaki-panel">
            <p className="rekap__diubah">
              {/* Yang ditandai di sini adalah pengakuan bahwa uang sudah berpindah tangan
                  di luar sistem, bukan perintah membayar. Itu harus tertulis, karena
                  tombolnya sendiri terbaca seperti perintah membayar. */}
              Menandai lunas hanya mencatat bahwa uangnya sudah diserahkan; tidak ada uang
              yang dikirim aplikasi ini.
            </p>
            <button
              type="button"
              className="tombol"
              disabled={sibuk || tercentang.length === 0}
              onClick={lunasi}
            >
              {sibuk
                ? 'Menyimpan...'
                : `Tandai ${tercentang.length} bayaran lunas (${formatRupiah(total)})`}
            </button>
          </div>

          {galat !== null && (
            <p className="keadaan keadaan--galat" role="alert">
              {pesanGalat(galat)}
            </p>
          )}
        </>
      )}

      {rincian.sudahDibayar.isi.length > 0 && (
        <details className="rekap__riwayat">
          <summary>
            Sudah dibayar: {formatRupiah(rincian.totalSudahDibayar)} dari{' '}
            {rincian.sudahDibayar.total} order
          </summary>
          <table className="tabel tabel--rapat">
            <thead>
              <tr>
                <th>Order</th>
                <th>Layanan</th>
                <th>Dibayar</th>
                <th className="tabel__angka">Bayaran</th>
              </tr>
            </thead>
            <tbody>
              {rincian.sudahDibayar.isi.map((b) => (
                <tr key={b.penugasanId}>
                  <td className="tautan-kode">{b.kodeOrder}</td>
                  <td>{labelLayanan(b.layanan)}</td>
                  <td>{b.dibayarPada ? formatTanggalJam(b.dibayarPada) : '-'}</td>
                  <td className="tabel__angka">{formatRupiah(b.jumlah)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </details>
      )}
    </>
  );
}
