using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Caching.Memory;

namespace UpnvjSuruh.Api.Auth;

/// <summary>Mengikat verifikasi password ke satu verifikasi OTP berikutnya.</summary>
public class PenyimpanTantanganMasuk(IMemoryCache cache, TimeProvider waktu)
{
    public static readonly TimeSpan MasaBerlaku = TimeSpan.FromMinutes(5);

    private sealed record Tantangan(byte[] Sidik, string? PasswordHashBaru);

    public (string Nilai, DateTime KedaluwarsaPada) Simpan(string noHp, string? passwordHashBaru = null)
    {
        var nilai = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        var kedaluwarsa = waktu.GetUtcNow().Add(MasaBerlaku);
        cache.Set(
            Kunci(noHp),
            new Tantangan(Sidik(nilai), passwordHashBaru),
            kedaluwarsa);
        return (nilai, kedaluwarsa.UtcDateTime);
    }

    public bool Cocok(string noHp, string nilai) =>
        cache.TryGetValue(Kunci(noHp), out Tantangan? tantangan)
        && tantangan is not null
        && CryptographicOperations.FixedTimeEquals(tantangan.Sidik, Sidik(nilai));

    public bool Pakai(string noHp, string nilai, out string? passwordHashBaru)
    {
        passwordHashBaru = null;
        if (!cache.TryGetValue(Kunci(noHp), out Tantangan? tantangan)
            || tantangan is null
            || !CryptographicOperations.FixedTimeEquals(tantangan.Sidik, Sidik(nilai)))
        {
            return false;
        }

        cache.Remove(Kunci(noHp));
        passwordHashBaru = tantangan.PasswordHashBaru;
        return true;
    }

    public static string TantanganPalsu() => Convert.ToHexString(RandomNumberGenerator.GetBytes(32));

    private static string Kunci(string noHp) => $"masuk-2-langkah:{noHp}";

    private static byte[] Sidik(string nilai) => SHA256.HashData(Encoding.UTF8.GetBytes(nilai));
}
