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
