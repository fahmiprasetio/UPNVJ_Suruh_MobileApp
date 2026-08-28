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

    [Fact]
    public void AnterJemputMenjumlahkanTarifDasarDanOngkosJarak()
    {
        var hasil = _kalkulator.Hitung(ServiceType.AnterJemput, jarakKm: 3);

        Assert.Equal(5000m + 6000m, hasil.Total);
        Assert.Equal(2, hasil.Rincian.Count);
    }

    [Fact]
    public void JastipMakananTidakBergantungJarak()
    {
        var tanpaJarak = _kalkulator.Hitung(ServiceType.JastipMakanan, jarakKm: null);
        var denganJarak = _kalkulator.Hitung(ServiceType.JastipMakanan, jarakKm: 12);

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
        var hasil = _kalkulator.Hitung(ServiceType.AnterJemput, jarak);

        Assert.Equal(5000m + 1000m, hasil.Total);
        Assert.True(hasil.Total > 0);
    }

    [Theory]
    [InlineData(100)]
    [InlineData(1_000_000)]
    [InlineData(double.MaxValue)]
    public void JarakDiAtasMaksimalDitagihPadaBatasAtas(double jarak)
    {
        var hasil = _kalkulator.Hitung(ServiceType.AnterJemput, jarak);

        Assert.Equal(5000m + 30000m, hasil.Total);
    }

    [Theory]
    [InlineData(double.NaN)]
    [InlineData(double.PositiveInfinity)]
    [InlineData(double.NegativeInfinity)]
    public void JarakYangBukanAngkaDitolak(double jarak)
    {
        Assert.Throws<ArgumentException>(() => _kalkulator.Hitung(ServiceType.AnterJemput, jarak));
    }

    [Fact]
    public void AnterJemputTanpaJarakDitolak()
    {
        Assert.Throws<ArgumentException>(() => _kalkulator.Hitung(ServiceType.AnterJemput, null));
    }

    [Theory]
    [InlineData(ServiceType.BantuPindahKos)]
    [InlineData(ServiceType.BersihKos)]
    [InlineData(ServiceType.BersihKamarMandi)]
    [InlineData(ServiceType.PermintaanLain)]
    public void LayananJalurBTidakBisaDihitungOtomatis(ServiceType serviceType)
    {
        // Harganya datang dari penawaran admin. Menghitungnya di sini berarti memberi harga
        // pada pekerjaan yang belum dilihat siapa pun.
        Assert.Throws<ArgumentException>(() => _kalkulator.Hitung(serviceType, jarakKm: 3));
    }

    [Fact]
    public void SetiapLayananJalurAPunyaRumus()
    {
        // Menambah layanan Jalur A baru tanpa rumusnya akan gagal di sini, bukan nanti saat
        // ada klien yang memesannya.
        var jalurA = Enum.GetValues<ServiceType>().Where(s => s.Track() == OrderTrack.JalurA);

        foreach (var layanan in jalurA)
        {
            var hasil = _kalkulator.Hitung(layanan, jarakKm: 2);
            Assert.True(hasil.Total > 0, $"{layanan} menghasilkan harga {hasil.Total}");
        }
    }
}
