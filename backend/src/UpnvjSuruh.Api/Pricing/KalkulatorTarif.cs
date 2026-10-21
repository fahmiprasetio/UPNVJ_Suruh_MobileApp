using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Pricing;

/// <summary>
/// Menghitung harga Jalur A di server.
///
/// Aplikasi punya kalkulator yang sama supaya klien melihat rinciannya sebelum memesan,
/// tapi angka itu tidak pernah dipercaya. Yang mengikat adalah hasil hitungan di sini.
/// Server yang menerima harga jadi dari badan permintaan berarti siapa pun bisa memesan
/// seharga satu rupiah, dan yang seperti itu tidak ketahuan sampai uangnya dihitung.
///
/// Yang diterima dari klien cuma jaraknya, dan itu pun dijepit ke rentang yang wajar.
/// Jarak diisi sendiri karena alamatnya teks bebas, bukan pin peta (bagian 14.8), jadi
/// tanpa peta sistem memang tidak punya cara menghitungnya sendiri.
///
/// <see cref="TarifSetting"/> diterima sebagai parameter, bukan dibaca dari konstanta
/// statis: angkanya sekarang bisa diubah admin lewat dashboard, dan kalkulator ini tetap
/// murni dan gampang diuji kalau tidak perlu tahu dari mana angkanya datang. Tidak ada
/// nilai bawaan untuk parameter ini dengan sengaja — pemanggil yang lupa memuat tarif
/// sekarang dari basis data akan gagal saat kompilasi, bukan diam-diam menghitung dengan
/// angka yang salah.
/// </summary>
public class KalkulatorTarif
{
    public HasilTarif Hitung(
        ServiceType serviceType,
        double? jarakKm,
        TarifSetting tarif,
        int jumlahRunner = 1,
        MovingVehicleType? jenisKendaraan = null)
    {
        if (serviceType.Track() != OrderTrack.JalurA)
        {
            throw new ArgumentException(
                $"{serviceType} adalah Jalur B, harganya ditentukan lewat penawaran runner.",
                nameof(serviceType));
        }

        return serviceType switch
        {
            ServiceType.AnterJemput => AnterJemput(WajibJarak(serviceType, jarakKm), tarif),
            ServiceType.JastipBarang => JastipBarang(WajibJarak(serviceType, jarakKm), tarif),
            ServiceType.JastipMakanan => JastipMakanan(tarif),
            ServiceType.BantuPindahKos => PindahKos(
                WajibJarak(serviceType, jarakKm), jumlahRunner, jenisKendaraan, tarif),
            ServiceType.BersihKos => TarifTetap("Jasa bersih-bersih kos", tarif.BersihKosFee),
            ServiceType.BersihKamarMandi => TarifTetap(
                "Jasa bersih kamar mandi", tarif.BersihKamarMandiFee),
            _ => throw new ArgumentOutOfRangeException(nameof(serviceType), serviceType, null),
        };
    }

    private static double WajibJarak(ServiceType serviceType, double? jarakKm)
    {
        if (jarakKm is null)
        {
            throw new ArgumentException($"{serviceType} butuh jarak untuk dihitung.", nameof(jarakKm));
        }

        if (double.IsNaN(jarakKm.Value) || double.IsInfinity(jarakKm.Value))
        {
            throw new ArgumentException("Jarak bukan angka yang sah.", nameof(jarakKm));
        }

        return jarakKm.Value;
    }

    private static HasilTarif AnterJemput(double jarakDiminta, TarifSetting tarif)
    {
        // Dijepit, bukan ditolak. Jarak di bawah minimal tetap order yang wajar, dan jarak
        // di atas maksimal sudah di luar wilayah layanan sehingga ditagih pada batasnya
        // lalu diselesaikan admin. Yang penting angka apa pun yang dikirim tidak bisa
        // membuat harganya nol atau meledak.
        var jarakDipakai = Math.Clamp(jarakDiminta, tarif.AnjemJarakMinimalKm, tarif.AnjemJarakMaksimalKm);
        var ongkosJarak = Math.Round((decimal)jarakDipakai * tarif.AnjemTarifPerKm, MidpointRounding.AwayFromZero);

        return new HasilTarif(
            [
                new RincianTarif("Tarif dasar", tarif.AnjemTarifDasar),
                new RincianTarif($"Jarak {FormatJarak(jarakDipakai)} km", ongkosJarak),
            ],
            tarif.AnjemTarifDasar + ongkosJarak);
    }

    private static HasilTarif JastipBarang(double jarakDiminta, TarifSetting tarif)
    {
        // Batas jarak jastip barang sengaja memakai batas anter jemput yang sama, mengikuti
        // KalkulatorTarif.jastipBarang di aplikasi mobile: mitra belum memberi angka batas
        // sendiri untuk jastip (rencana bagian 14.7a).
        var jarakDipakai = Math.Clamp(jarakDiminta, tarif.AnjemJarakMinimalKm, tarif.AnjemJarakMaksimalKm);
        var ongkosJarak = Math.Round((decimal)jarakDipakai * tarif.JastipBarangTarifPerKm, MidpointRounding.AwayFromZero);

        return new HasilTarif(
            [
                new RincianTarif("Ongkos jasa titip", tarif.JastipBarangFee),
                new RincianTarif($"Jarak {FormatJarak(jarakDipakai)} km", ongkosJarak),
            ],
            tarif.JastipBarangFee + ongkosJarak);
    }

    private static HasilTarif JastipMakanan(TarifSetting tarif) =>
        new([new RincianTarif("Ongkos jasa titip", tarif.JastipMakananFee)], tarif.JastipMakananFee);

    private static HasilTarif PindahKos(
        double jarakDiminta,
        int jumlahRunner,
        MovingVehicleType? jenisKendaraan,
        TarifSetting tarif)
    {
        if (jumlahRunner is < 1 or > 5)
        {
            throw new ArgumentException("Jumlah runner harus 1 sampai 5.", nameof(jumlahRunner));
        }

        if (jenisKendaraan is null)
        {
            throw new ArgumentException("Pilih kendaraan untuk pindahan.", nameof(jenisKendaraan));
        }

        var jarakDipakai = Math.Clamp(
            jarakDiminta, tarif.AnjemJarakMinimalKm, tarif.AnjemJarakMaksimalKm);
        var ongkosJarak = Math.Round(
            (decimal)jarakDipakai * tarif.PindahKosTarifPerKm,
            MidpointRounding.AwayFromZero);
        var tambahanRunner = (jumlahRunner - 1) * tarif.PindahKosTambahanRunner;
        var tambahanKendaraan = jenisKendaraan switch
        {
            MovingVehicleType.Motor => 0m,
            MovingVehicleType.Mobil => tarif.PindahKosTambahanMobil,
            MovingVehicleType.Pickup => tarif.PindahKosTambahanPickup,
            _ => throw new ArgumentOutOfRangeException(nameof(jenisKendaraan)),
        };

        var rincian = new List<RincianTarif>
        {
            new("Jasa pindah kos", tarif.PindahKosTarifDasar),
            new($"Jarak {FormatJarak(jarakDipakai)} km", ongkosJarak),
        };
        if (tambahanRunner > 0)
        {
            rincian.Add(new RincianTarif($"Tambahan {jumlahRunner - 1} runner", tambahanRunner));
        }
        if (tambahanKendaraan > 0)
        {
            rincian.Add(new RincianTarif($"Kendaraan {jenisKendaraan}", tambahanKendaraan));
        }

        return new HasilTarif(rincian, rincian.Sum(r => r.Nominal));
    }

    private static HasilTarif TarifTetap(string label, decimal nominal) =>
        new([new RincianTarif(label, nominal)], nominal);

    private static string FormatJarak(double jarak) =>
        jarak == Math.Round(jarak)
            ? jarak.ToString("0")
            : jarak.ToString("0.0").Replace('.', ',');
}
