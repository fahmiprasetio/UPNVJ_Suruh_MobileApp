using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Payouts;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Pembagian harga order menjadi komisi organisasi dan bayaran runner.
///
/// Yang dijaga paling ketat di sini bukan besarnya masing-masing bagian, melainkan bahwa
/// keduanya selalu berjumlah tepat sama dengan harga ordernya. Rekap yang selisih satu rupiah
/// sama merepotkannya dengan yang selisih sejuta: dua-duanya menuntut orang menelusurinya, dan
/// selisih yang lahir dari pembulatan adalah selisih yang paling sulit ditelusuri karena tidak
/// ada satu pun langkah yang kelihatan salah.
/// </summary>
public class KalkulatorPayoutTests
{
    private static PayoutSetting Persen(decimal persen) => new()
    {
        Mode = ModeKomisi.Persen,
        KomisiPersen = persen,
        DiaturPada = DateTime.UtcNow,
    };

    private static PayoutSetting Tetap(decimal rupiah) => new()
    {
        Mode = ModeKomisi.Tetap,
        KomisiTetap = rupiah,
        DiaturPada = DateTime.UtcNow,
    };

    // --- Mode persen ---

    [Fact]
    public void PersenMengambilBagiannyaDanSisanyaKeRunner()
    {
        var hasil = KalkulatorPayout.Bagi(100_000m, 1, Persen(20m));

        Assert.Equal(20_000m, hasil.KomisiOrganisasi);
        Assert.Equal([80_000m], hasil.Runner);
    }

    [Fact]
    public void NolPersenBerartiRunnerMenerimaSeluruhnya()
    {
        var hasil = KalkulatorPayout.Bagi(15_000m, 1, Persen(0m));

        Assert.Equal(0m, hasil.KomisiOrganisasi);
        Assert.Equal([15_000m], hasil.Runner);
    }

    [Fact]
    public void SeratusPersenBerartiRunnerMenerimaNol()
    {
        var hasil = KalkulatorPayout.Bagi(15_000m, 1, Persen(100m));

        Assert.Equal(15_000m, hasil.KomisiOrganisasi);
        Assert.Equal([0m], hasil.Runner);
    }

    // --- Mode rupiah tetap ---

    [Fact]
    public void TetapMengambilRupiahYangSamaBerapaPunHargaOrdernya()
    {
        var murah = KalkulatorPayout.Bagi(20_000m, 1, Tetap(5_000m));
        var mahal = KalkulatorPayout.Bagi(200_000m, 1, Tetap(5_000m));

        Assert.Equal(5_000m, murah.KomisiOrganisasi);
        Assert.Equal(5_000m, mahal.KomisiOrganisasi);
        Assert.Equal([15_000m], murah.Runner);
        Assert.Equal([195_000m], mahal.Runner);
    }

    /// <summary>
    /// Potongan tetap yang lebih besar dari harga ordernya tidak boleh melahirkan bayaran
    /// negatif, yaitu runner yang berutang kepada organisasi karena sudah bekerja. Ini
    /// satu-satunya jalan yang bisa menghasilkannya, dan tidak ada penjagaan di sisi form
    /// rumusnya yang bisa mencegahnya: yang menentukan bukan rumusnya melainkan harga order
    /// yang datang belakangan.
    /// </summary>
    [Fact]
    public void PotonganTetapYangLebihBesarDariHargaTidakMembuatBayaranMinus()
    {
        var hasil = KalkulatorPayout.Bagi(8_000m, 1, Tetap(10_000m));

        Assert.Equal(8_000m, hasil.KomisiOrganisasi);
        Assert.Equal([0m], hasil.Runner);
    }

    // --- Pembagian antar runner ---

    [Fact]
    public void HabisDibagiBerartiSemuaRunnerMenerimaSamaBanyak()
    {
        var hasil = KalkulatorPayout.Bagi(30_000m, 3, Persen(0m));

        Assert.Equal([10_000m, 10_000m, 10_000m], hasil.Runner);
    }

    /// <summary>
    /// Rp25.000 untuk tiga orang adalah Rp8.333,33 per orang, angka yang tidak bisa dibayarkan.
    /// Yang diperiksa di sini bukan siapa menerima berapa, melainkan bahwa sisa rupiahnya
    /// dibagikan, bukan dibulatkan ke bawah (satu rupiah menguap) atau ke atas (dua rupiah
    /// lahir dari ketiadaan).
    /// </summary>
    [Fact]
    public void SisaPembagianDibagikanSatuSatuDariUrutanTerdepan()
    {
        var hasil = KalkulatorPayout.Bagi(25_000m, 3, Persen(0m));

        Assert.Equal([8_334m, 8_333m, 8_333m], hasil.Runner);
        Assert.Equal(25_000m, hasil.Runner.Sum());
    }

    [Fact]
    public void SetiapBayaranSelaluRupiahBulat()
    {
        var hasil = KalkulatorPayout.Bagi(25_000m, 7, Persen(13m));

        Assert.All(hasil.Runner, b => Assert.Equal(decimal.Floor(b), b));
    }

    /// <summary>
    /// Satu-satunya aturan yang harus benar untuk setiap kombinasi, bukan cuma untuk yang
    /// kebetulan dipilih jadi contoh: tidak ada rupiah yang hilang dan tidak ada yang lahir.
    /// </summary>
    [Theory]
    [InlineData(25000, 3, 0)]
    [InlineData(25000, 3, 20)]
    [InlineData(100000, 7, 13)]
    [InlineData(1, 3, 0)]
    [InlineData(99999, 4, 33)]
    [InlineData(7777, 6, 17.5)]
    public void JumlahKomisiDanSeluruhBayaranSelaluSamaDenganHargaOrder(
        decimal harga, int runner, decimal persen)
    {
        var hasil = KalkulatorPayout.Bagi(harga, runner, Persen(persen));

        Assert.Equal(harga, hasil.KomisiOrganisasi + hasil.Runner.Sum());
    }

    /// <summary>
    /// Harga yang tidak bulat cuma mungkin pada order Jalur B, yang harganya datang dari
    /// penawaran runner, bukan dari kalkulator tarif. Pecahannya tidak bisa dibayarkan kepada
    /// siapa pun, jadi ia tinggal pada organisasi — yang penting ia tercatat di sana, bukan
    /// hilang dari penjumlahan.
    /// </summary>
    [Fact]
    public void HargaYangTidakBulatMenyisakanPecahannyaPadaOrganisasi()
    {
        var hasil = KalkulatorPayout.Bagi(10_000.75m, 2, Persen(0m));

        Assert.Equal([5_000m, 5_000m], hasil.Runner);
        Assert.Equal(0.75m, hasil.KomisiOrganisasi);
        Assert.Equal(10_000.75m, hasil.KomisiOrganisasi + hasil.Runner.Sum());
    }

    // --- Batas ---

    [Fact]
    public void OrderTanpaHargaTidakMelahirkanBayaranApaPun()
    {
        var hasil = KalkulatorPayout.Bagi(0m, 2, Persen(20m));

        Assert.Equal(0m, hasil.KomisiOrganisasi);
        Assert.Equal([0m, 0m], hasil.Runner);
    }

    [Fact]
    public void TanpaRunnerAdalahKesalahanPemanggil()
    {
        Assert.Throws<ArgumentOutOfRangeException>(
            () => KalkulatorPayout.Bagi(10_000m, 0, Persen(20m)));
    }
}
