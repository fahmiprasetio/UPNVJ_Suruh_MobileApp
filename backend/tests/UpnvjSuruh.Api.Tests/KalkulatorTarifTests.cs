using UpnvjSuruh.Api.Domain;
using UpnvjSuruh.Api.Pricing;

namespace UpnvjSuruh.Api.Tests;

/// <summary>
/// Harga Jalur A dihitung server, tidak pernah diterima dari klien. Yang diuji di sini:
/// angka apa pun yang dikirim klien tidak bisa membuat harganya nol, negatif, atau meledak.
/// </summary>
public class KalkulatorTarifTests
{
    private readonly KalkulatorTarif _kalkulator = new();

    /// <summary>
    /// Tarif bawaan untuk tes, angkanya persis <see cref="TarifConfig"/>. Bukan baris
    /// basis data sungguhan — kalkulatornya sendiri tidak tahu dan tidak peduli dari mana
    /// [TarifSetting] datang, jadi tes murninya tidak butuh basis data sama sekali.
    /// </summary>
    private static TarifSetting Bawaan() => new()
    {
        AnjemTarifDasar = TarifConfig.AnjemTarifDasar,
        AnjemTarifPerKm = TarifConfig.AnjemTarifPerKm,
        AnjemJarakMinimalKm = TarifConfig.AnjemJarakMinimalKm,
        AnjemJarakMaksimalKm = TarifConfig.AnjemJarakMaksimalKm,
        JastipMakananFee = TarifConfig.JastipMakananFee,
        JastipBarangFee = TarifConfig.JastipBarangFee,
        JastipBarangTarifPerKm = TarifConfig.JastipBarangTarifPerKm,
        PindahKosTarifDasar = TarifConfig.PindahKosTarifDasar,
        PindahKosTarifPerKm = TarifConfig.PindahKosTarifPerKm,
        PindahKosTambahanRunner = TarifConfig.PindahKosTambahanRunner,
        PindahKosTambahanMobil = TarifConfig.PindahKosTambahanMobil,
        PindahKosTambahanPickup = TarifConfig.PindahKosTambahanPickup,
        BersihKosFee = TarifConfig.BersihKosFee,
        BersihKamarMandiFee = TarifConfig.BersihKamarMandiFee,
    };

    [Fact]
    public void AnterJemputMenjumlahkanTarifDasarDanOngkosJarak()
    {
        var hasil = _kalkulator.Hitung(ServiceType.AnterJemput, jarakKm: 3, Bawaan());

        Assert.Equal(5000m + 6000m, hasil.Total);
        Assert.Equal(2, hasil.Rincian.Count);
    }

    [Fact]
    public void JastipMakananTidakBergantungJarak()
    {
        var tanpaJarak = _kalkulator.Hitung(ServiceType.JastipMakanan, jarakKm: null, Bawaan());
        var denganJarak = _kalkulator.Hitung(ServiceType.JastipMakanan, jarakKm: 12, Bawaan());

        Assert.Equal(TarifConfig.JastipMakananFee, tanpaJarak.Total);
        Assert.Equal(tanpaJarak.Total, denganJarak.Total);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-5)]
    [InlineData(0.1)]
    public void JarakDiBawahMinimalDitagihPadaBatasBawah(double jarak)
    {
        // Tanpa penjepitan, jarak nol atau negatif membuat ongkos jaraknya hilang atau
        // malah mengurangi tarif dasar.
        var hasil = _kalkulator.Hitung(ServiceType.AnterJemput, jarak, Bawaan());

        Assert.Equal(5000m + 1000m, hasil.Total);
        Assert.True(hasil.Total > 0);
    }

    [Theory]
    [InlineData(100)]
    [InlineData(1_000_000)]
    [InlineData(double.MaxValue)]
    public void JarakDiAtasMaksimalDitagihPadaBatasAtas(double jarak)
    {
        var hasil = _kalkulator.Hitung(ServiceType.AnterJemput, jarak, Bawaan());

        Assert.Equal(5000m + 30000m, hasil.Total);
    }

    [Theory]
    [InlineData(double.NaN)]
    [InlineData(double.PositiveInfinity)]
    [InlineData(double.NegativeInfinity)]
    public void JarakYangBukanAngkaDitolak(double jarak)
    {
        Assert.Throws<ArgumentException>(() => _kalkulator.Hitung(ServiceType.AnterJemput, jarak, Bawaan()));
    }

    [Fact]
    public void AnterJemputTanpaJarakDitolak()
    {
        Assert.Throws<ArgumentException>(() => _kalkulator.Hitung(ServiceType.AnterJemput, null, Bawaan()));
    }

    [Fact]
    public void LayananJalurBTidakBisaDihitungOtomatis()
    {
        // Harganya datang dari penawaran admin. Menghitungnya di sini berarti memberi harga
        // pada pekerjaan yang belum dilihat siapa pun.
        Assert.Throws<ArgumentException>(() =>
            _kalkulator.Hitung(ServiceType.PermintaanLain, jarakKm: 3, Bawaan()));
    }

    [Fact]
    public void PindahKosMenghitungJarakRunnerDanKendaraan()
    {
        var hasil = _kalkulator.Hitung(
            ServiceType.BantuPindahKos,
            jarakKm: 2,
            Bawaan(),
            jumlahRunner: 2,
            jenisKendaraan: MovingVehicleType.Pickup);

        Assert.Equal(25_000m + 6_000m + 20_000m + 40_000m, hasil.Total);
    }

    [Theory]
    [InlineData(ServiceType.BersihKos, 30_000)]
    [InlineData(ServiceType.BersihKamarMandi, 20_000)]
    public void LayananKebersihanMemakaiTarifTetap(ServiceType layanan, decimal harga)
    {
        Assert.Equal(harga, _kalkulator.Hitung(layanan, null, Bawaan()).Total);
    }

    [Fact]
    public void SetiapLayananJalurAPunyaRumus()
    {
        // Menambah layanan Jalur A baru tanpa rumusnya akan gagal di sini, bukan nanti saat
        // ada klien yang memesannya.
        var jalurA = Enum.GetValues<ServiceType>().Where(s => s.Track() == OrderTrack.JalurA);

        foreach (var layanan in jalurA)
        {
            var hasil = _kalkulator.Hitung(
                layanan,
                jarakKm: 2,
                Bawaan(),
                jenisKendaraan: layanan == ServiceType.BantuPindahKos
                    ? MovingVehicleType.Motor
                    : null);
            Assert.True(hasil.Total > 0, $"{layanan} menghasilkan harga {hasil.Total}");
        }
    }

    [Fact]
    public void TarifBaruDipakaiSaatDiberikan()
    {
        // Bukti bahwa kalkulator sungguh membaca dari parameter, bukan diam-diam masih
        // memakai TarifConfig di baliknya.
        var tarifBerbeda = Bawaan();
        tarifBerbeda.AnjemTarifDasar = 99_000m;

        var hasil = _kalkulator.Hitung(ServiceType.AnterJemput, jarakKm: 1, tarifBerbeda);

        Assert.Equal(99_000m + 2000m, hasil.Total);
    }
}
