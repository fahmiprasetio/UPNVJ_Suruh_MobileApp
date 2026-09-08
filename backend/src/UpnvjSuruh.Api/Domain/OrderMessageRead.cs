namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Sampai pesan kapan seorang pengguna sudah membaca satu jalur obrolan sebuah order.
///
/// Satu baris per (order, pengguna, jalur), bukan per pesan: membaca cuma menggeser satu
/// penanda waktu ke depan, tidak menandai pesan satu-satu. Jalur obrolannya mengikuti
/// pembagian yang sama dengan <see cref="OrderMessage.RunnerPenawarId"/> (lihat
/// <see cref="Data.PesanTerlihat"/>) -- klien yang membaca tawar-menawarnya dengan satu
/// runner tidak ikut menandai tawar-menawarnya dengan runner lain sebagai sudah dibaca.
///
/// <see cref="RunnerPenawarId"/> memakai <see cref="Guid.Empty"/> untuk obrolan umum,
/// bukan <c>null</c>. Indeks unik di bawah tidak bisa menyamakan dua NULL sebagai satu
/// nilai (aturan SQL biasa: NULL tidak pernah sama dengan NULL), jadi kolom yang boleh
/// null di sini berarti setiap kali obrolan umum ditandai dibaca, barisnya berpeluang
/// bertambah satu lagi alih-alih menimpa yang lama. Pola yang sama sudah dipakai
/// <c>PengabarOrder.TokenAsync</c> untuk masalah yang persis sama.
/// </summary>
public class OrderMessageRead
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public required Guid OrderId { get; set; }
    public Order? Order { get; set; }

    public required Guid UserId { get; set; }
    public User? User { get; set; }

    public required Guid RunnerPenawarId { get; set; }

    public DateTime LastReadAt { get; set; } = DateTime.UtcNow;
}
