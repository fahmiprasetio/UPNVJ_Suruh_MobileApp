using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Pricing;

public interface IKalkulatorTarif
{
    HasilTarif Hitung(ServiceType serviceType, double? jarakKm);
}

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
/// </summary>
public class KalkulatorTarif : IKalkulatorTarif
{
    public HasilTarif Hitung(ServiceType serviceType, double? jarakKm)
    {
        if (serviceType.Track() != OrderTrack.JalurA)
        {
            throw new ArgumentException(
                $"{serviceType} adalah Jalur B, harganya ditentukan admin lewat penawaran.",
                nameof(serviceType));
        }

        return serviceType switch
        {
            ServiceType.AnterJemput => AnterJemput(WajibJarak(serviceType, jarakKm)),
            ServiceType.JastipBarang => JastipBarang(WajibJarak(serviceType, jarakKm)),
            ServiceType.JastipMakanan => JastipMakanan(),
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

        // Dijepit, bukan ditolak. Jarak di bawah minimal tetap order yang wajar, dan jarak
        // di atas maksimal sudah di luar wilayah layanan sehingga ditagih pada batasnya
        // lalu diselesaikan admin. Yang penting angka apa pun yang dikirim tidak bisa
        // membuat harganya nol atau meledak.
        return Math.Clamp(jarakKm.Value, TarifConfig.AnjemJarakMinimalKm, TarifConfig.AnjemJarakMaksimalKm);
    }

    private static HasilTarif AnterJemput(double jarakDipakai)
    {
        var ongkosJarak = Math.Round((decimal)jarakDipakai * TarifConfig.AnjemTarifPerKm, MidpointRounding.AwayFromZero);

        return new HasilTarif(
            [
                new RincianTarif("Tarif dasar", TarifConfig.AnjemTarifDasar),
                new RincianTarif($"Jarak {FormatJarak(jarakDipakai)} km", ongkosJarak),
            ],
            TarifConfig.AnjemTarifDasar + ongkosJarak);
    }

    private static HasilTarif JastipBarang(double jarakDipakai)
    {
        var ongkosJarak = Math.Round((decimal)jarakDipakai * TarifConfig.JastipBarangTarifPerKm, MidpointRounding.AwayFromZero);

        return new HasilTarif(
            [
                new RincianTarif("Ongkos jasa titip", TarifConfig.JastipBarangFee),
                new RincianTarif($"Jarak {FormatJarak(jarakDipakai)} km", ongkosJarak),
            ],
            TarifConfig.JastipBarangFee + ongkosJarak);
    }

    private static HasilTarif JastipMakanan() =>
        new([new RincianTarif("Ongkos jasa titip", TarifConfig.JastipMakananFee)],
            TarifConfig.JastipMakananFee);

    private static string FormatJarak(double jarak) =>
        jarak == Math.Round(jarak)
            ? jarak.ToString("0")
            : jarak.ToString("0.0").Replace('.', ',');
}
