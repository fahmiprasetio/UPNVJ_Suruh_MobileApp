namespace UpnvjSuruh.Api.Data;

/// <summary>
/// Batas panjang teks. Kembaran <c>lib/core/config/batas_masukan.dart</c> di aplikasi
/// mobile, dan angkanya wajib sama.
///
/// Dipasang sampai ke definisi kolom, bukan berhenti di pemeriksaan C#. Basis data adalah
/// penjaga terakhir yang tidak bisa dilewati jalur mana pun: bukan lewat endpoint yang
/// lupa memeriksa, bukan lewat skrip perbaikan data, bukan lewat versi berikutnya yang
/// menambah jalan masuk baru.
/// </summary>
public static class BatasMasukan
{
    public const int PesanChat = 1000;
    public const int Deskripsi = 2000;
    public const int Alamat = 200;
    public const int CatatanSerahTerima = 500;
    public const int Nama = 100;
    public const int NomorHp = 20;
    public const int ReferensiGateway = 200;
    public const int Url = 500;
    public const int KodeOrder = 20;
}
