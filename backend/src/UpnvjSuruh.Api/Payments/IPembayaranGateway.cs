using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Payments;

/// <summary>
/// Membuat satu transaksi di gateway pembayaran.
///
/// Implementasinya dapat berupa simulator, Snap, atau QRIS Core. Pemilihan gateway dilakukan
/// di komposisi aplikasi; <see cref="Controllers.PembayaranController"/> tidak pernah tahu
/// yang mana sedang aktif.
/// </summary>
public interface IPembayaranGateway
{
    /// <param name="order">Order yang dibayar. Cuma dibaca (kode order, tidak pernah harganya
    /// -- itu selalu <paramref name="jumlah"/>), tidak pernah diubah di sini.</param>
    /// <param name="paymentId">Id baris <see cref="Payment"/> yang akan dibuat pemanggil,
    /// dibangkitkan lebih dulu supaya bisa dipakai sebagai referensi ke gateway sebelum baris
    /// itu sendiri disimpan.</param>
    /// <param name="jumlah">Selalu <c>order.Price</c>, tidak pernah dari badan permintaan.</param>
    /// <returns>Referensi transaksi di gateway yang dicocokkan saat webhook datang, serta
    /// salah satu dari payload QR atau halaman checkout yang aman dibuka klien.</returns>
    Task<HasilPembuatanPembayaran> BuatTransaksiAsync(
        Order order,
        Guid paymentId,
        decimal jumlah,
        CancellationToken batal);
}

/// <summary>Hasil aman yang disimpan server sebelum dikirim ke aplikasi.</summary>
public sealed record HasilPembuatanPembayaran(
    string ReferensiGateway,
    string QrPayload,
    string? CheckoutUrl);
