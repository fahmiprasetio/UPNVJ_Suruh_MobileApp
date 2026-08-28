namespace UpnvjSuruh.Api.Domain;

public class Payment
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required Guid OrderId { get; set; }
    public Order? Order { get; set; }

    public decimal Amount { get; set; }
    public required string GatewayReference { get; set; }
    public PaymentStatus Status { get; set; } = PaymentStatus.Pending;

    /// <summary>
    /// Isi mentah kode QR yang digambar aplikasi.
    ///
    /// Di produksi ini string QRIS resmi dari gateway; aplikasi tidak pernah menyusunnya
    /// sendiri, cuma menggambar apa yang diberikan. Selama gateway belum dipilih, isinya
    /// sengaja ditandai sebagai simulasi dan sengaja tidak menyerupai QRIS asli: string yang
    /// mirip aslinya tapi palsu akan lolos pandangan sekilas dan menipu penguji, sedangkan
    /// yang seperti ini gagal dipindai aplikasi bank, dan memang seharusnya begitu.
    /// </summary>
    public required string QrPayload { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>Batas waktu membayar. Lewat itu transaksinya hangus sendiri.</summary>
    public DateTime ExpiresAt { get; set; }

    public DateTime? SettledAt { get; set; }

    public bool Menunggu => Status == PaymentStatus.Pending;
}
