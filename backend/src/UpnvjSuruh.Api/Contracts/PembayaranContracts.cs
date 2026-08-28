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
