namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Order yang tidak ditangani lebih dari batas waktu yang ditentukan (1 hari).
/// </summary>
/// <remarks>
/// Order yang tidak kunjung diambil oleh runner (pada Jalur A setelah dibayar) atau tidak kunjung
/// ditawar (pada Jalur B) selama lebih dari 1 hari dianggap kedaluwarsa sehingga tidak lagi
/// disiarkan ke runner di daftar order tersedia.
/// </remarks>
public static class OrderKedaluwarsa
{
    /// <summary>
    /// Batas waktu maksimal order menganggur sebelum dianggap kedaluwarsa (1 hari / 24 jam).
    /// </summary>
    public static readonly TimeSpan Ambang = TimeSpan.FromDays(1);

    /// <summary>
    /// Memeriksa apakah satu order tertentu sudah kedaluwarsa karena tidak ditangani lebih dari 1 hari.
    /// </summary>
    public static bool ApakahKedaluwarsa(Order order, DateTime sekarang)
    {
        var batas = sekarang - Ambang;

        if (order.Status == OrderStatus.MencariRunner)
        {
            var waktuMulai = order.PaidAt ?? order.CreatedAt;
            return waktuMulai < batas;
        }

        if (order.Status == OrderStatus.Permintaan)
        {
            return order.CreatedAt < batas;
        }

        return false;
    }
}
