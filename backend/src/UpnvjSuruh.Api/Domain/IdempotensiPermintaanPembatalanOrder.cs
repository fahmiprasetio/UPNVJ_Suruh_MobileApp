namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Jejak permintaan pembatalan yang berhasil agar retry klien tidak menggandakan pesan,
/// penanda permintaan, atau pemberitahuan perubahan order.
/// </summary>
public class IdempotensiPermintaanPembatalanOrder
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public required string Key { get; set; }
    public required Guid UserId { get; set; }
    public required Guid OrderId { get; set; }
    public required string RequestHash { get; set; }
    public required string ResponseJson { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
