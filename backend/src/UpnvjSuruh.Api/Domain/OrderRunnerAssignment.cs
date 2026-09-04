namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// One row per runner who accepted an order. Uniqueness on (OrderId, RunnerId) stops
/// a runner double-accepting; RequiredRunnerCount vs row count (checked inside a
/// transaction against Order.Version) stops two runners racing for the last slot.
/// </summary>
public class OrderRunnerAssignment
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required Guid OrderId { get; set; }
    public Order? Order { get; set; }

    public required Guid RunnerId { get; set; }
    public User? Runner { get; set; }

    public DateTime AcceptedAt { get; set; } = DateTime.UtcNow;
    public DateTime? MarkedDoneAt { get; set; }
    public string? CompletionPhotoUrl { get; set; }

    /// <summary>
    /// Bayaran runner ini untuk order ini, dibekukan saat ordernya selesai.
    /// </summary>
    /// <remarks>
    /// Dibekukan, bukan dihitung ulang tiap kali dibaca, dengan alasan yang sama seperti
    /// <see cref="Order.Price"/>: rumus bagi hasilnya bisa diubah admin kapan saja
    /// (<see cref="PayoutSetting"/>), dan bayaran yang ikut berubah surut berarti runner yang
    /// sudah mengerjakan order minggu lalu bisa mendapati bayarannya berkurang tanpa ada yang
    /// menyentuh ordernya. Yang sudah dijanjikan tetap seperti yang dijanjikan.
    ///
    /// Null berarti belum dihitung, dan itu keadaan yang sah: order yang selesai selagi rumus
    /// bagi hasilnya belum pernah diatur admin menunggu di sini sampai rumus itu disimpan
    /// pertama kali. Null sengaja tidak diperlakukan sebagai nol — lihat
    /// <see cref="PayoutSetting.DiaturPada"/>.
    /// </remarks>
    public decimal? PayoutAmount { get; set; }

    /// <summary>
    /// Kapan bayaran ini benar-benar diserahkan organisasi ke runner, dan null selama belum.
    /// </summary>
    /// <remarks>
    /// Satu kolom waktu, bukan sepasang penanda benar/salah ditambah waktunya. Dua kolom yang
    /// menyatakan satu hal yang sama bisa berselisih (tertanda lunas tanpa tanggal, atau
    /// bertanggal tanpa tertanda lunas), dan yang membaca keduanya harus memutuskan sendiri
    /// mana yang dipercaya. Satu kolom tidak bisa berselisih dengan dirinya sendiri.
    ///
    /// Penyerahannya sendiri terjadi di luar sistem: tunai atau transfer antar orang, sesuai
    /// cara mitra bekerja sekarang. Yang dicatat di sini pengakuan admin bahwa itu sudah
    /// terjadi, bukan perpindahan uangnya.
    /// </remarks>
    public DateTime? PayoutSettledAt { get; set; }

    /// <summary>Admin yang menandai bayaran ini sudah diserahkan.</summary>
    public Guid? PayoutSettledByAdminId { get; set; }
}
