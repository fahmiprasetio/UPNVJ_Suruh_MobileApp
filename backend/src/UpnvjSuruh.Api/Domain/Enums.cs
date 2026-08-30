namespace UpnvjSuruh.Api.Domain;

public enum UserRole
{
    Klien,
    Runner,
    Admin
}

public enum ServiceType
{
    AnterJemput,
    JastipMakanan,
    JastipBarang,
    BantuPindahKos,
    BersihKos,
    BersihKamarMandi,
    PermintaanLain
}

public enum OrderTrack
{
    JalurA,
    JalurB
}

public enum OrderStatus
{
    Permintaan,
    MenungguPersetujuanKlien,
    MenungguPembayaran,
    MencariRunner,
    Dikerjakan,
    Selesai,
    Batal
}

public enum OfferStatus
{
    Pending,
    Disetujui,
    Ditolak,
    DinegoUlang
}

public enum PaymentStatus
{
    Pending,
    Berhasil,
    Gagal,
    Kedaluwarsa,

    /// <summary>
    /// Uangnya masuk, tapi bukan sebesar yang ditagihkan.
    ///
    /// Bukan Gagal, karena gagal berarti tidak ada uang yang berpindah dan ordernya boleh
    /// ditagihkan ulang begitu saja. Di sini ada uang yang sudah diterima dan harus
    /// dipertanggungjawabkan, entah dikembalikan atau dilengkapi, dan itu keputusan orang.
    /// Menandainya Gagal berarti uang itu hilang dari pembukuan.
    ///
    /// Ditambahkan di ujung, tidak disisipkan di tengah. Nilainya tersimpan sebagai angka di
    /// basis data, jadi menyisipkan anggota baru di tengah akan mengubah arti setiap baris
    /// yang sudah ada tanpa ada yang menyentuhnya.
    /// </summary>
    JumlahTidakCocok
}

public static class OrderStatusExtensions
{
    /// <summary>
    /// Order yang masih berjalan. Selesai dan batal adalah keadaan akhir: tidak ada tindakan
    /// yang boleh menghidupkannya lagi, termasuk mengirim pesan ke chatnya.
    /// </summary>
    public static bool Aktif(this OrderStatus status) =>
        status is not (OrderStatus.Selesai or OrderStatus.Batal);
}

public static class ServiceTypeExtensions
{
    /// <summary>
    /// Jalur mana yang dipakai satu jenis layanan. Wajib sama persis dengan
    /// <c>ServiceType</c> di aplikasi mobile, yang menaruh pemetaan ini di enum-nya.
    /// </summary>
    public static OrderTrack Track(this ServiceType serviceType) => serviceType switch
    {
        ServiceType.AnterJemput => OrderTrack.JalurA,
        ServiceType.JastipMakanan => OrderTrack.JalurA,
        ServiceType.JastipBarang => OrderTrack.JalurA,
        ServiceType.BantuPindahKos => OrderTrack.JalurB,
        ServiceType.BersihKos => OrderTrack.JalurB,
        ServiceType.BersihKamarMandi => OrderTrack.JalurB,
        ServiceType.PermintaanLain => OrderTrack.JalurB,
        _ => throw new ArgumentOutOfRangeException(nameof(serviceType), serviceType, null),
    };
}
