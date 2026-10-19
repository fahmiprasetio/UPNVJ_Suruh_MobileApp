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
    /// Halaman checkout Midtrans Snap. Disimpan bersama transaksi agar membuka ulang layar
    /// tidak menerbitkan token atau tagihan kedua.
    /// </summary>
    public string? CheckoutUrl { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    /// <summary>Batas waktu membayar. Lewat itu transaksinya hangus sendiri.</summary>
    public DateTime ExpiresAt { get; set; }

    public DateTime? SettledAt { get; set; }

    /// <summary>
    /// Kapan pengembaliannya dicatat, admin mana yang mencatatnya, dan kenapa.
    ///
    /// Ketiganya cuma terisi bersamaan dengan <see cref="Status"/> berpindah ke
    /// <see cref="PaymentStatus.Dikembalikan"/>, lewat <c>AdminOrderController.Batalkan</c>.
    /// Tidak ada endpoint lain yang mengisinya, dan itu disengaja: pengembalian dana adalah
    /// tindakan admin yang harus disertai alasan, bukan efek samping transisi status lain.
    /// </summary>
    public DateTime? RefundedAt { get; set; }

    public Guid? RefundedByAdminId { get; set; }

    public string? RefundReason { get; set; }

    public bool Menunggu => Status == PaymentStatus.Pending;
}
