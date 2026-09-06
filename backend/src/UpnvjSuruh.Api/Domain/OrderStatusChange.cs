namespace UpnvjSuruh.Api.Domain;

/// <summary>
/// Catatan setiap kali status sebuah order berpindah.
///
/// ## Kenapa tidak cukup kolom di ordernya
///
/// <see cref="Order.Status"/> menjawab "sedang di tahap apa order ini sekarang", tapi cuma
/// itu -- riwayat perpindahannya sendiri tidak tersimpan di mana pun. Order yang mundur dari
/// <see cref="OrderStatus.Dikerjakan"/> ke <see cref="OrderStatus.MencariRunner"/> lalu maju
/// lagi terlihat persis sama di basis data dengan order yang cuma sekali berpindah, padahal
/// yang pertama adalah order yang runnernya melepas di tengah jalan -- pola yang pantas
/// diketahui admin yang sedang menimbang layak-tidaknya menangguhkan sebuah akun runner,
/// sama seperti alasan <see cref="OrderRelease"/> dan <see cref="UserSuspensionChange"/> ada.
///
/// ## Kenapa aktornya boleh kosong
///
/// Kebanyakan perpindahan dipicu satu orang yang jelas: admin membatalkan, klien menyetujui
/// penawaran, runner menerima atau menyelesaikan. Tapi dua perpindahan lahir dari webhook
/// pembayaran yang tidak pernah masuk lewat token siapa pun -- order yang lunas berpindah
/// sendiri, dipicu gateway, bukan orang. Memaksa kolom ini wajib diisi berarti salah satu
/// dari dua hal buruk: mencatat aktor yang bohong, atau menolak mencatat perpindahan yang
/// justru paling penting diketahui persis kapan terjadinya.
///
/// Isinya tidak pernah diubah maupun dihapus, sama seperti <see cref="UserRoleChange"/>,
/// <see cref="OrderRelease"/>, dan <see cref="UserSuspensionChange"/>. Catatan yang bisa
/// disunting bukan catatan.
/// </summary>
public class OrderStatusChange
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Order yang berpindah statusnya.</summary>
    public required Guid OrderId { get; set; }
    public Order? Order { get; set; }

    public required OrderStatus FromStatus { get; set; }
    public required OrderStatus ToStatus { get; set; }

    /// <summary>
    /// Siapa yang memicu perpindahan ini, atau <c>null</c> kalau bukan tindakan seseorang --
    /// lihat penjelasannya di atas soal webhook pembayaran.
    /// </summary>
    public Guid? ChangedByUserId { get; set; }
    public User? ChangedByUser { get; set; }

    public DateTime ChangedAt { get; set; } = DateTime.UtcNow;

    /// <summary>
    /// Mencatat satu perpindahan status sekaligus benar-benar memindahkannya.
    ///
    /// Satu titik ini dipanggil dari kedelapan tempat status order pernah berubah, supaya
    /// tidak ada satu pun yang lupa mencatat sambil memindahkan -- kesalahan yang, kalau
    /// ditulis manual di tiap pemanggil, cuma ketahuan belakangan lewat baris yang hilang.
    /// </summary>
    public static OrderStatusChange Catat(Order order, OrderStatus statusBaru, Guid? aktorUserId)
    {
        var perubahan = new OrderStatusChange
        {
            OrderId = order.Id,
            FromStatus = order.Status,
            ToStatus = statusBaru,
            ChangedByUserId = aktorUserId,
        };
        order.Status = statusBaru;
        return perubahan;
    }
}
