namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Jejak satu pembuatan order yang dapat diulang dengan aman.
/// </summary>
/// <remarks>
/// Key disimpan global, bukan cuma per pengguna. Key yang sama dari akun lain selalu
/// ditolak, sehingga key yang bocor atau salah dipakai tidak pernah mengembalikan order
/// milik orang lain. Respons utuh disimpan agar retry tetap mendapat hasil yang sama meski
/// order atau tarif berubah setelah pembuatan pertama.
/// </remarks>
public class IdempotensiPembuatanOrder
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public required string Key { get; set; }
    public required Guid UserId { get; set; }
    public required string RequestHash { get; set; }
    public required Guid OrderId { get; set; }
    public required OrderTrack Track { get; set; }

    /// <summary>Respons sukses pertama, diserialkan sebagai JSON API.</summary>
    public required string ResponseJson { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
