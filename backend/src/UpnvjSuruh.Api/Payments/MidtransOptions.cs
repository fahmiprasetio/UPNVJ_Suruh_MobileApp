using System.Security.Cryptography;
using System.Text;

namespace UpnvjSuruh.Api.Payments;

/// <summary>
/// Kredensial Midtrans. Sama seperti <see cref="Auth.WebhookOptions"/>, tidak boleh ditulis
/// di appsettings mana pun -- lewat <c>dotnet user-secrets</c> di mesin pengembang.
/// </summary>
public class MidtransOptions
{
    public const string Section = "Midtrans";

    /// <summary>Dipakai server: Basic Auth ke Core API, dan menghitung ulang tanda tangan
    /// notifikasi webhook. Tidak pernah ke aplikasi klien.</summary>
    public string ServerKey { get; set; } = string.Empty;

    /// <summary>Belum dipakai sisi server sekarang (QRIS lewat Core API tidak menuntutnya),
    /// disimpan untuk metode pembayaran lain yang mungkin butuh Snap di masa depan.</summary>
    public string ClientKey { get; set; } = string.Empty;

    /// <summary>Salah (bawaan) berarti Sandbox. Sengaja bukan diturunkan dari
    /// <c>Environment.IsDevelopment()</c>: mesin pengembang ini pun perlu bisa mencoba jalur
    /// Production kalau suatu saat diminta, dan server produksi tidak boleh diam-diam jatuh ke
    /// Sandbox hanya karena bendera ini lupa disetel.</summary>
    public bool Production { get; set; }

    /// <summary>
    /// Sah kalau <paramref name="signatureKey"/> yang dikirim Midtrans cocok dengan
    /// SHA512(order_id+status_code+gross_amount+ServerKey), persis rumus di dokumentasi
    /// Midtrans.
    ///
    /// Gagal tertutup kalau <see cref="ServerKey"/> belum diisi: string kosong bukan rahasia,
    /// jadi tanpa penjagaan ini siapa pun bisa menghitung SHA512 dengan kunci kosong sendiri
    /// dan memalsukan notifikasi lunas persis di mesin yang belum memasang Midtrans sama
    /// sekali -- kejadian yang sama dengan alasan <see cref="Auth.WebhookOptions"/> mewajibkan
    /// rahasianya diisi sebelum server menyala.
    /// </summary>
    public bool SignatureValid(string orderId, string statusCode, string grossAmount, string? signatureKey)
    {
        if (string.IsNullOrEmpty(ServerKey)) return false;
        if (string.IsNullOrEmpty(signatureKey)) return false;

        var bahan = Encoding.UTF8.GetBytes($"{orderId}{statusCode}{grossAmount}{ServerKey}");
        var dihitung = Convert.ToHexStringLower(SHA512.HashData(bahan));

        var a = Encoding.UTF8.GetBytes(dihitung);
        var b = Encoding.UTF8.GetBytes(signatureKey.ToLowerInvariant());

        // Perbandingan waktu tetap, sama alasannya dengan WebhookOptions.Cocok: perbandingan
        // string biasa berhenti di karakter pertama yang beda, dan selisih waktunya cukup
        // untuk menebak tanda tangan satu karakter demi satu.
        return a.Length == b.Length && CryptographicOperations.FixedTimeEquals(a, b);
    }
}
