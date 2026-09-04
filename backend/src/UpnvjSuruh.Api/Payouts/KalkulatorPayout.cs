using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Payouts;

/// <summary>
/// Pembagian satu order: berapa yang diambil organisasi, dan berapa yang diterima tiap runner.
/// </summary>
/// <param name="KomisiOrganisasi">Bagian organisasi, dalam rupiah utuh.</param>
/// <param name="Runner">
/// Bayaran tiap runner, berurutan sesuai urutan yang diberikan pemanggil, dalam rupiah utuh.
/// </param>
/// <remarks>
/// Keduanya dikembalikan bersama, bukan lewat dua pemanggilan terpisah, supaya keduanya tidak
/// mungkin berselisih: <see cref="KomisiOrganisasi"/> didefinisikan sebagai sisa harga order
/// setelah seluruh bayaran runner diambil, jadi jumlah semuanya selalu tepat sama dengan harga
/// ordernya. Dua method terpisah yang masing-masing membulatkan sendiri bisa menghasilkan
/// pasangan angka yang tidak berjumlah utuh, dan selisih itu baru ketahuan di rekap keuangan,
/// tempat paling mahal untuk menemukannya.
/// </remarks>
public record HasilPayout(decimal KomisiOrganisasi, IReadOnlyList<decimal> Runner);

/// <summary>
/// Membagi harga satu order menjadi potongan organisasi dan bayaran tiap runner.
/// </summary>
/// <remarks>
/// Kelas statis dan murni, tanpa basis data, mengikuti <see cref="Pricing.KalkulatorTarif"/>:
/// <see cref="PayoutSetting"/> diterima sebagai parameter, tidak dibaca sendiri, supaya seluruh
/// aturan pembagiannya bisa diuji tanpa menyalakan apa pun.
/// </remarks>
public static class KalkulatorPayout
{
    /// <summary>
    /// Membagi satu order.
    /// </summary>
    /// <param name="hargaOrder">Harga order yang sudah dibayar klien.</param>
    /// <param name="jumlahRunner">Banyak runner yang mengerjakan order ini, minimal satu.</param>
    /// <param name="setting">Rumus bagi hasil yang sedang berlaku.</param>
    /// <remarks>
    /// ## Bagi rata
    ///
    /// Sisanya dibagi rata antar runner. Pertanyaan "uangnya dibagi rata atau ada penanggung
    /// jawab yang dapat lebih" belum dijawab mitra (rencana capstone bagian 14.7d); rata adalah
    /// pilihan yang tidak mengistimewakan siapa pun, dan kalau nanti ada jawaban lain, yang
    /// berubah cuma isi method ini.
    ///
    /// ## Kenapa sisa pembagiannya dibagikan satu-satu, bukan dibulatkan begitu saja
    ///
    /// Rp25.000 untuk tiga runner adalah Rp8.333,33 per orang. Dibulatkan ke bawah, ketiganya
    /// menerima Rp24.999 dan satu rupiah menguap dari pembukuan; dibulatkan ke atas, ketiganya
    /// menerima Rp25.002 dan organisasi membayar dua rupiah yang tidak pernah ada asalnya.
    /// Angkanya kecil, tapi keduanya sama-sama membuat "total bayaran seluruh runner" tidak
    /// pernah bisa dicocokkan dengan harga ordernya, dan rekap yang tidak bisa dicocokkan adalah
    /// rekap yang tidak bisa dipercaya siapa pun yang memeriksanya.
    ///
    /// Jadi sisanya dibagikan: tiap runner menerima bagian bulat ke bawah, lalu sisa rupiahnya
    /// (selalu lebih sedikit dari banyaknya runner) diberikan satu per satu dari urutan
    /// terdepan. Rp25.000 untuk tiga orang jadi Rp8.334, Rp8.333, Rp8.333.
    ///
    /// Urutannya ditentukan pemanggil dan harus tetap (di sini: urutan runner menerima order),
    /// bukan urutan yang kebetulan dikembalikan basis data. Urutan yang berubah-ubah berarti
    /// siapa yang menerima rupiah lebih ikut berubah tiap kali dihitung ulang, dan itu
    /// pertanyaan yang tidak enak dijawab justru karena jawabannya "kebetulan".
    ///
    /// ## Kenapa bagian runner dibulatkan ke bawah lebih dulu
    ///
    /// Rupiah tidak punya satuan yang lebih kecil dari satu, jadi bayaran harus bilangan bulat.
    /// Pecahan yang tersisa dari harga order yang tidak utuh (mungkin pada order Jalur B, yang
    /// harganya datang dari penawaran runner, bukan dari kalkulator tarif) tidak bisa dibayarkan
    /// kepada siapa pun, jadi ia tinggal pada organisasi lewat definisi
    /// <see cref="HasilPayout.KomisiOrganisasi"/> sebagai sisa. Selisihnya selalu kurang dari
    /// satu rupiah, dan yang lebih penting: ia tercatat, bukan hilang.
    ///
    /// ## Potongan tetap yang lebih besar dari harga order
    ///
    /// Hanya mungkin pada <see cref="ModeKomisi.Tetap"/>: potongan Rp10.000 pada order seharga
    /// Rp8.000 akan menghasilkan bayaran runner negatif, yaitu runner berutang karena sudah
    /// bekerja. Tidak ada penjagaan di sisi penyimpanan rumus yang bisa mencegahnya, karena yang
    /// menentukan bukan rumusnya melainkan harga order yang datang belakangan; jadi
    /// penjagaannya memang tempatnya di sini. Akibatnya (organisasi mengambil semuanya, runner
    /// menerima nol) kelihatan apa adanya di rekap, bukan tersembunyi sebagai angka minus yang
    /// mustahil dibayarkan.
    /// </remarks>
    public static HasilPayout Bagi(decimal hargaOrder, int jumlahRunner, PayoutSetting setting)
    {
        if (jumlahRunner < 1)
        {
            throw new ArgumentOutOfRangeException(
                nameof(jumlahRunner), jumlahRunner, "Order yang selesai selalu punya minimal satu runner.");
        }

        // Order gratis atau berharga minus tidak punya apa pun untuk dibagi. Dijawab di sini,
        // bukan dibiarkan lewat, karena Math.Clamp di bawah melempar kalau batas atasnya lebih
        // kecil dari batas bawahnya, dan harga minus akan membuatnya begitu.
        if (hargaOrder <= 0)
        {
            return new HasilPayout(0, [.. Enumerable.Repeat(0m, jumlahRunner)]);
        }

        var komisiDiminta = setting.Mode switch
        {
            ModeKomisi.Persen => hargaOrder * setting.KomisiPersen / 100m,
            ModeKomisi.Tetap => setting.KomisiTetap,
            _ => throw new ArgumentOutOfRangeException(nameof(setting), setting.Mode, null),
        };

        var kolamRunner = decimal.Floor(Math.Clamp(hargaOrder - komisiDiminta, 0m, hargaOrder));

        // Ke bawah, bukan ke terdekat: pembulatan ke terdekat bisa membuat bagian dasar dikali
        // banyaknya runner melebihi kolam yang tersedia, dan sisa yang dibagikan jadi negatif.
        var dasar = decimal.Floor(kolamRunner / jumlahRunner);

        // Bulat dan selalu di bawah jumlahRunner, karena kolamRunner sudah bilangan bulat.
        var sisa = kolamRunner - dasar * jumlahRunner;

        return new HasilPayout(
            hargaOrder - kolamRunner,
            [.. Enumerable.Range(0, jumlahRunner).Select(i => i < sisa ? dasar + 1 : dasar)]);
    }
}
