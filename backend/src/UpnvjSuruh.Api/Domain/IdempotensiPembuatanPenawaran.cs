namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Jejak satu pembuatan penawaran yang dapat diulang dengan aman.
/// </summary>
/// <remarks>
/// Key berlaku per runner, bukan per order: runner yang sama dapat memakai key yang sama
/// hanya untuk retry request yang sama, sedangkan runner lain tetap bebas menawar order yang
/// sama dengan key miliknya sendiri.
/// </remarks>
public class IdempotensiPembuatanPenawaran
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public required string Key { get; set; }
    public required Guid RunnerId { get; set; }
    public required Guid OrderId { get; set; }
    public required string RequestHash { get; set; }
    public required Guid OfferId { get; set; }

    /// <summary>Respons sukses pertama, diserialkan sebagai JSON API.</summary>
    public required string ResponseJson { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
