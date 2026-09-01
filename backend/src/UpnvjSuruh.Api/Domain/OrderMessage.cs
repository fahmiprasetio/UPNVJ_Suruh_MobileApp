namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Satu pesan di ruang chat sebuah order.
///
/// Tidak ada chat yang berdiri sendiri: setiap pesan menempel pada satu order. Tanpa aturan
/// itu, ruang chat pelan-pelan berubah jadi WhatsApp versi lebih jelek, persis masalah yang
/// mau ditinggalkan mitra.
/// </summary>
public class OrderMessage
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required Guid OrderId { get; set; }
    public Order? Order { get; set; }

    public required Guid SenderId { get; set; }

    /// <summary>
    /// Jalur obrolan pribadi milik runner ini pada tahap tawar-menawar Jalur B, atau
    /// <c>null</c> kalau pesan ini bukan bagian dari tawar-menawar (chat umum Jalur A, atau
    /// chat Jalur B sesudah satu runner terpilih).
    ///
    /// Selama beberapa runner menawar bersamaan pada order yang sama, masing-masing punya
    /// obrolannya sendiri dengan klien; nilai ini yang memisahkannya, supaya runner satu
    /// tidak pernah membaca tawar-menawar runner lain pada order yang sama. Klien boleh
    /// melihat semuanya karena ialah yang memilih di antaranya; runner cuma boleh melihat
    /// miliknya sendiri, dijaga di <see cref="Data.PesanTerlihat"/>.
    /// </summary>
    public Guid? RunnerPenawarId { get; set; }

    /// <summary>
    /// Peran pengirim pada order ini, saat pesannya dikirim.
    ///
    /// Diturunkan server dari hubungannya dengan order, tidak pernah diterima dari badan
    /// permintaan. Peran penulis yang disebutkan pemanggil berarti siapa pun bisa menulis
    /// atas nama admin, dan pesan yang tampak dari admin adalah pesan yang dipercaya orang.
    ///
    /// Disimpan, bukan dihitung ulang saat dibaca, karena ini catatan sejarah: pesan ini
    /// memang dikirim oleh seseorang yang saat itu berdiri sebagai peran tersebut. Kalau
    /// dihitung ulang, mencabut peran seseorang akan ikut mengubah label percakapan yang
    /// sudah lewat, dan percakapan yang berubah setelah terjadi tidak bisa dipakai
    /// menyelesaikan perselisihan.
    /// </summary>
    public UserRole SenderRole { get; set; }

    public string? Text { get; set; }
    public string? PhotoUrl { get; set; }
    public string? VoiceNoteUrl { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
