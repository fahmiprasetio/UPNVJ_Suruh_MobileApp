using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using UpnvjSuruh.Api.Contracts;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Data;

/// <summary>Aturan bersama untuk pengulangan aman pembuatan order Jalur A dan B.</summary>
public static class IdempotensiOrder
{
    public const string NamaHeader = "Idempotency-Key";
    public const int PanjangKeyMaksimal = 128;

    private static readonly JsonSerializerOptions OpsiJson = new(JsonSerializerDefaults.Web)
    {
        Converters = { new JsonStringEnumConverter() },
    };

    public static bool CobaBacaKey(HttpRequest request, out string? key)
    {
        key = request.Headers[NamaHeader].ToString().Trim();
        if (string.IsNullOrEmpty(key))
        {
            key = null;
            return true;
        }

        return key.Length <= PanjangKeyMaksimal;
    }

    public static string HashJalurA(BuatOrderJalurARequest request) => Hash(
        "A",
        request.ServiceType.ToString(),
        request.JarakKm?.ToString("R", CultureInfo.InvariantCulture),
        request.Deskripsi?.Trim(),
        request.AlamatJemput?.Trim(),
        request.AlamatTujuan?.Trim());

    public static string HashJalurB(BuatPermintaanJalurBRequest request) => Hash(
        "B",
        request.ServiceType.ToString(),
        request.Deskripsi.Trim(),
        request.JadwalMulai.ToUniversalTime().ToString("O", CultureInfo.InvariantCulture),
        request.HargaUsulan.ToString(CultureInfo.InvariantCulture),
        request.AlamatTujuan?.Trim(),
        request.JumlahRunnerDibutuhkan.ToString(CultureInfo.InvariantCulture));

    public static string HashPenawaran(Guid orderId, BuatPenawaranRequest request) => Hash(
        "PENAWARAN",
        orderId.ToString("D"),
        request.Harga.ToString(CultureInfo.InvariantCulture),
        request.EstimasiDurasiMenit.ToString(CultureInfo.InvariantCulture),
        request.JadwalMulai.ToUniversalTime().ToString("O", CultureInfo.InvariantCulture),
        request.Catatan?.Trim());

    public static string HashTerima(Guid orderId) => Hash("TERIMA", orderId.ToString("D"));

    public static string SimpanRespons<T>(T respons) => JsonSerializer.Serialize(respons, OpsiJson);

    public static T? BacaRespons<T>(IdempotensiPembuatanOrder jejak) =>
        BacaRespons<T>(jejak.ResponseJson);

    public static T? BacaRespons<T>(IdempotensiPembuatanPenawaran jejak) =>
        BacaRespons<T>(jejak.ResponseJson);

    public static T? BacaRespons<T>(IdempotensiTerimaOrder jejak) =>
        BacaRespons<T>(jejak.ResponseJson);

    private static T? BacaRespons<T>(string responseJson) =>
        JsonSerializer.Deserialize<T>(responseJson, OpsiJson);

    private static string Hash(params string?[] bagian)
    {
        // Panjang setiap bagian ikut ditulis agar batas field tidak membuat dua kombinasi
        // berbeda berakhir pada teks gabungan yang sama.
        var normal = string.Join("|", bagian.Select(b => $"{b?.Length ?? -1}:{b}"));
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(normal)));
    }
}
