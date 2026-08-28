using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Caching.Memory;

namespace UpnvjSuruh.Api.Auth;

public interface IPenyimpanOtp
{
    /// <summary>Menyimpan kode untuk satu nomor, menimpa kode sebelumnya kalau ada.</summary>
    void Simpan(string noHp, string kode);

    /// <summary>
    /// Memeriksa kode sekali pakai. Benar berarti kodenya cocok dan belum kedaluwarsa, dan
    /// kode itu langsung hangus apa pun hasilnya kalau jatah percobaannya habis.
    /// </summary>
    bool Pakai(string noHp, string kode);
}

/// <summary>
/// Penyimpan OTP di memori proses.
///
/// BATASNYA: hanya benar selama servernya satu proses. Begitu ada dua instansi di belakang
/// load balancer, kode yang dibuat instansi A tidak dikenal instansi B dan separuh percobaan
/// masuk akan gagal tanpa sebab yang terlihat. Kalau sampai ke sana, yang diganti cukup kelas
/// ini, dengan Redis atau satu tabel di Postgres.
/// </summary>
public class PenyimpanOtpMemori(IMemoryCache cache) : IPenyimpanOtp
{
    public static readonly TimeSpan MasaBerlaku = TimeSpan.FromMinutes(5);

    /// <summary>
    /// Kode enam angka punya sejuta kemungkinan, jadi tanpa batas percobaan ia bisa ditebak
    /// habis-habisan. Lima kali cukup untuk salah ketik, jauh dari cukup untuk menebak.
    /// </summary>
    public const int MaksimalPercobaan = 5;

    private sealed class Tantangan
    {
        public required byte[] SidikKode { get; init; }
        public int Percobaan { get; set; }
    }

    public void Simpan(string noHp, string kode)
    {
        cache.Set(
            Kunci(noHp),
            new Tantangan { SidikKode = Sidik(kode) },
            MasaBerlaku);
    }

    public bool Pakai(string noHp, string kode)
    {
        if (!cache.TryGetValue(Kunci(noHp), out Tantangan? tantangan) || tantangan is null)
        {
            return false;
        }

        tantangan.Percobaan++;
        if (tantangan.Percobaan > MaksimalPercobaan)
        {
            cache.Remove(Kunci(noHp));
            return false;
        }

        // Perbandingan waktu tetap. Perbandingan biasa berhenti di byte pertama yang beda,
        // dan selisih waktunya cukup untuk menebak kode satu angka demi satu angka.
        if (!CryptographicOperations.FixedTimeEquals(tantangan.SidikKode, Sidik(kode)))
        {
            return false;
        }

        // Sekali pakai. Kode yang tetap sah setelah dipakai berarti siapa pun yang sempat
        // melihatnya sekali bisa memakainya lagi nanti.
        cache.Remove(Kunci(noHp));
        return true;
    }

    private static string Kunci(string noHp) => $"otp:{noHp}";

    // Kode disimpan sebagai sidik, bukan apa adanya, supaya dump memori atau log diagnostik
    // tidak langsung menyerahkan kode yang sedang berlaku.
    private static byte[] Sidik(string kode) => SHA256.HashData(Encoding.UTF8.GetBytes(kode));
}
