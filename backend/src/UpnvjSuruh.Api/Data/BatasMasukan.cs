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
    public const int QrPayload = 1000;

    /// <summary>
    /// Token perangkat dari Firebase. Panjangnya sekarang sekitar 160 karakter dan tidak
    /// pernah dijanjikan tetap, jadi angkanya dilebihkan: kolom yang kesempitan berarti
    /// perangkat yang gagal mendaftar tanpa ada yang tahu, dan yang dijaga di sini cuma
    /// baris yang membengkak, bukan masukan yang dikarang orang.
    /// </summary>
    public const int TokenPerangkat = 512;
}
