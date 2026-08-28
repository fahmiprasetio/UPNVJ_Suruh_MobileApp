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
    Kedaluwarsa
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
