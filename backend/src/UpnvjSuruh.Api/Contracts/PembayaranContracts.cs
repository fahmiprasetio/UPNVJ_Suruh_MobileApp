using System.Text.Json.Serialization;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Contracts;

/// <summary>
/// Satu transaksi pembayaran.
/// </summary>
/// <remarks>
/// PERHATIKAN TIDAK ADA PERMINTAAN YANG MENYERTAI PEMBUATANNYA: jumlahnya diambil dari harga
/// ordernya, bukan dari badan permintaan. Klien yang boleh menyebut jumlah yang ia bayar
/// tinggal membuat transaksi seharga satu rupiah untuk order seharga lima puluh ribu.
/// </remarks>
public record TransaksiPembayaranResponse(
    Guid Id,
    Guid OrderId,
    decimal Jumlah,
    string Status,
    string QrisPayload,
    DateTime DibuatPada,
    DateTime KedaluwarsaPada,
    DateTime? DibayarPada)
{
    public static TransaksiPembayaranResponse Dari(Payment pembayaran) => new(
        pembayaran.Id,
        pembayaran.OrderId,
        pembayaran.Amount,
        pembayaran.Status.ToString(),
        pembayaran.QrPayload,
        pembayaran.CreatedAt,
        pembayaran.ExpiresAt,
        pembayaran.SettledAt);
}

/// <summary>
/// Notifikasi HTTP sungguhan dari Midtrans (bukan tiruan <see cref="WebhookPembayaranRequest"/>
/// di atas -- itu format sendiri yang cuma dipakai tes dan tiruan gateway).
///
/// Nama bidangnya snake_case mengikuti persis dokumentasi Midtrans, bukan gaya penamaan yang
/// dipakai di tempat lain proyek ini: ini bentuk yang dikirim pihak luar, bukan kontrak yang
/// dirancang sendiri.
/// </summary>
public record MidtransNotifikasiRequest(
    [property: JsonPropertyName("order_id")] string? OrderId,
    [property: JsonPropertyName("status_code")] string? StatusCode,
    [property: JsonPropertyName("gross_amount")] string? GrossAmount,
    [property: JsonPropertyName("signature_key")] string? SignatureKey,
    [property: JsonPropertyName("transaction_status")] string? TransactionStatus);
