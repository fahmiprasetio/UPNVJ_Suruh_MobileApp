using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Payments;

/// <summary>
/// Isi QR selama gateway sungguhan belum dipasang. Hidup cuma di Development (lihat
/// pendaftarannya di <c>Program.cs</c>) -- terdaftar di produksi berarti order bisa "dibayar"
/// tanpa uang sungguhan berpindah sama sekali.
///
/// Sengaja tidak menyerupai payload QRIS resmi. String yang mirip aslinya tapi palsu akan
/// lolos pandangan sekilas dan menipu penguji; yang seperti ini gagal dipindai aplikasi bank,
/// dan memang seharusnya begitu.
/// </summary>
public class PembayaranGatewaySimulasi : IPembayaranGateway
{
    public Task<(string ReferensiGateway, string QrPayload)> BuatTransaksiAsync(
        Order order,
        Guid paymentId,
        decimal jumlah,
        CancellationToken batal) => Task.FromResult((
        $"sim-{paymentId:N}",
        $"SIMULASI-QRIS|order={order.OrderCode}|jumlah={jumlah:0}"));
}
