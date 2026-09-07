using System.Globalization;
using UpnvjSuruh.Api.Domain;

namespace UpnvjSuruh.Api.Notifikasi;

/// <summary>
/// Siapa yang perlu diberi tahu tentang satu kabar.
/// </summary>
/// <param name="UserId">Akun tertentu, biasanya klien pemilik order atau runner yang memegangnya.</param>
/// <param name="SemuaRunner">
/// Benar untuk siaran ke seluruh runner yang berlaku. Dipisahkan dari daftar akun karena yang
/// dituju memang tidak bisa disebutkan satu per satu di sini: daftarnya kueri, bukan sesuatu
/// yang diketahui dari ordernya.
/// </param>
public record SasaranKabar(IReadOnlyCollection<Guid> UserId, bool SemuaRunner)
{
    public static SasaranKabar Akun(params Guid[] userId) => new(userId, SemuaRunner: false);

    public static readonly SasaranKabar SeluruhRunner = new([], SemuaRunner: true);
}

public record Kabar(SasaranKabar Sasaran, PesanNotifikasi Pesan);

/// <summary>
/// Menerjemahkan satu perpindahan status order jadi kabar-kabar yang layak muncul di layar
/// kunci orang.
///
/// ## Kenapa terpisah dari yang mengirimnya
///
/// Fungsi murni: masuknya ordernya beserta status asalnya, keluarnya daftar kabar. Tidak
/// menyentuh basis data, tidak menyentuh jaringan, jadi seluruh keputusan "siapa dikabari
/// apa" -- bagian yang paling mudah keliru dan paling sulit dilihat kalau keliru -- bisa
/// diuji tanpa Postgres maupun Firebase.
///
/// ## Kenapa tidak setiap perpindahan berujung kabar
///
/// Notifikasi yang datang untuk hal yang tidak menuntut apa-apa adalah cara tercepat membuat
/// orang mematikan notifikasi aplikasi ini seluruhnya, dan begitu dimatikan, kabar yang
/// benar-benar mendesak ikut mati bersamanya. Karena itu pemicu tindakannya sendiri tidak
/// pernah dikabari kembali: runner yang barusan menekan terima sudah tahu ia menerima.
/// </summary>
public static class KabarOrder
{
    /// <summary>
    /// Rupiah tanpa bergantung pada culture yang terpasang di mesin. Pemisah ribuan titik
    /// ditulis terang-terangan supaya jawabannya sama di laptop Windows dan di CI Linux.
    /// </summary>
    private static readonly NumberFormatInfo FormatRupiah = new() { NumberGroupSeparator = "." };

    private static string Rupiah(decimal? harga) =>
        harga is null ? "-" : "Rp" + harga.Value.ToString("#,##0", FormatRupiah);

    public static IReadOnlyList<Kabar> Susun(Order order, OrderStatus dari, Guid? aktor)
    {
        var kode = order.OrderCode;
        var klien = order.ClientId;

        // Runner yang penawarannya dimenangkan klien, kalau ordernya Jalur B. Null untuk
        // Jalur A, yang tidak punya penawaran sama sekali.
        var pemenang = order.Offers
            .SingleOrDefault(f => f.Status == OfferStatus.Disetujui)?.CreatedByRunnerId;

        var siaranOrderBaru = new Kabar(
            SasaranKabar.SeluruhRunner,
            new PesanNotifikasi(
                "Order baru: " + order.ServiceType.NamaTampilan(),
                $"{kode}, {Rupiah(order.Price)}. Buka aplikasi untuk mengambilnya.",
                order.Id));

        return (dari, order.Status) switch
        {
            // Klien menyetujui satu penawaran Jalur B. Yang perlu tahu runner pemenangnya:
            // ia baru saja terikat pekerjaan, dan sampai kabar ini ia cuma tahu tawarannya
            // sedang menunggu jawaban.
            (_, OrderStatus.MenungguPembayaran) when pemenang is not null =>
            [
                new Kabar(
                    SasaranKabar.Akun(pemenang.Value),
                    new PesanNotifikasi(
                        "Penawaranmu diterima",
                        $"Klien memilih penawaranmu untuk {kode}. Order jalan begitu pembayarannya masuk.",
                        order.Id)),
            ],

            // Pembayaran masuk, dan ordernya butuh runner. Dua kabar sekaligus, ke dua pihak
            // yang menunggu hal yang berbeda: klien menunggu kepastian uangnya diterima,
            // runner menunggu pekerjaan.
            (OrderStatus.MenungguPembayaran, OrderStatus.MencariRunner) =>
            [
                new Kabar(
                    SasaranKabar.Akun(klien),
                    new PesanNotifikasi(
                        "Pembayaran diterima",
                        $"{kode} sedang dicarikan runner.",
                        order.Id)),
                siaranOrderBaru,
            ],

            // Jalur B berkuota satu: pemenang tawaran langsung memegangnya begitu lunas,
            // tanpa lewat siaran. Justru karena tidak ada siaran, runner itu tidak akan tahu
            // dari mana pun bahwa ia sudah boleh mulai bekerja.
            (OrderStatus.MenungguPembayaran, OrderStatus.Dikerjakan) =>
            [
                new Kabar(
                    SasaranKabar.Akun(klien),
                    new PesanNotifikasi(
                        "Pembayaran diterima",
                        $"{kode} langsung dikerjakan runner pilihanmu.",
                        order.Id)),
                .. pemenang is null
                    ? Array.Empty<Kabar>()
                    : new Kabar[]
                    {
                        new(
                            SasaranKabar.Akun(pemenang.Value),
                            new PesanNotifikasi(
                                "Order sudah dibayar",
                                $"{kode} siap kamu kerjakan sekarang.",
                                order.Id)),
                    },
            ],

            // Runner melepas order yang sudah dipegangnya. Klien perlu tahu supaya jeda yang
            // tiba-tiba muncul tidak terbaca sebagai aplikasi yang diam.
            (OrderStatus.Dikerjakan, OrderStatus.MencariRunner) =>
            [
                new Kabar(
                    SasaranKabar.Akun(klien),
                    new PesanNotifikasi(
                        "Runner melepas ordermu",
                        $"{kode} kembali dicarikan runner lain.",
                        order.Id)),
                siaranOrderBaru,
            ],

            (_, OrderStatus.Dikerjakan) =>
            [
                new Kabar(
                    SasaranKabar.Akun(klien),
                    new PesanNotifikasi(
                        "Runner sudah menerima",
                        $"{kode} mulai dikerjakan.",
                        order.Id)),
            ],

            (_, OrderStatus.Selesai) =>
            [
                new Kabar(
                    SasaranKabar.Akun(klien),
                    new PesanNotifikasi(
                        "Ordermu selesai",
                        $"Runner menutup {kode} dengan foto bukti.",
                        order.Id)),
            ],

            // Pembatalan dikabari ke semua yang terikat order ini kecuali pelakunya sendiri.
            // Runner yang sedang memegangnya paling perlu: ia bisa saja sedang di jalan.
            (_, OrderStatus.Batal) =>
            [
                .. order.RunnerAssignments
                    .Select(a => a.RunnerId)
                    .Where(id => id != aktor)
                    .Select(id => new Kabar(
                        SasaranKabar.Akun(id),
                        new PesanNotifikasi(
                            "Order dibatalkan",
                            $"{kode} yang kamu pegang dibatalkan.",
                            order.Id))),
                .. klien == aktor
                    ? Array.Empty<Kabar>()
                    : new Kabar[]
                    {
                        new(
                            SasaranKabar.Akun(klien),
                            new PesanNotifikasi(
                                "Ordermu dibatalkan",
                                $"{kode} dibatalkan admin.",
                                order.Id)),
                    },
            ],

            _ => [],
        };
    }
}
