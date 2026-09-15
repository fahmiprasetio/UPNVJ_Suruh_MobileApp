using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Payments;

/// <summary>
/// Membuat satu transaksi QRIS di gateway pembayaran.
///
/// Dua implementasi: <see cref="PembayaranGatewaySimulasi"/> selama gateway sungguhan belum
/// dipasang, dan <see cref="MidtransPembayaranGateway"/> begitu <c>Midtrans:ServerKey</c>
/// terisi. <see cref="Controllers.PembayaranController"/> tidak pernah tahu yang mana yang
/// sedang aktif.
/// </summary>
public interface IPembayaranGateway
{
    /// <param name="order">Order yang dibayar. Cuma dibaca (kode order, tidak pernah harganya
    /// -- itu selalu <paramref name="jumlah"/>), tidak pernah diubah di sini.</param>
    /// <param name="paymentId">Id baris <see cref="Payment"/> yang akan dibuat pemanggil,
    /// dibangkitkan lebih dulu supaya bisa dipakai sebagai referensi ke gateway sebelum baris
    /// itu sendiri disimpan.</param>
    /// <param name="jumlah">Selalu <c>order.Price</c>, tidak pernah dari badan permintaan.</param>
    /// <returns>Referensi transaksi di gateway (dicocokkan lagi saat kabar lunas datang) dan
    /// isi kode QR yang digambar aplikasi.</returns>
    Task<(string ReferensiGateway, string QrPayload)> BuatTransaksiAsync(
        Order order,
        Guid paymentId,
        decimal jumlah,
        CancellationToken batal);
}
