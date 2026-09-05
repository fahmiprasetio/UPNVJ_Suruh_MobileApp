using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using UpnvjSuruh.Api.Auth;
using UpnvjSuruh.Api.Data;

namespace UpnvjSuruh.Api.Hubs;

/// <summary>
/// Saluran realtime tempat runner, admin, dan klien yang sedang membayar menunggu. Kode
/// sisi server mengirim "OrderBroadcast" ketika order berbayar butuh runner, dan
/// "OrderTaken" begitu ada yang menerimanya, ini yang menghapus langkah relay admin lewat
/// WA di Jalur A (rencana capstone bagian 2 dan 4). "OrderChanged" dikirim ke grup admin
/// setiap kali status sebuah order berubah (rencana capstone bagian 40), menggantikan
/// sebagian pengambilan ulang berkala 15 detik di dashboard dengan kabar seketika.
/// "PaymentChanged" dikirim ke grup satu order tertentu setiap kali tagihannya bergeser
/// dari menunggu (rencana capstone bagian 41), menggantikan sebagian pengambilan ulang
/// berkala 3 detik di layar bayar. "MessageAdded" dikirim ke grup order yang sama setiap
/// kali ada pesan chat baru di order itu (rencana capstone bagian 43), menggantikan
/// sebagian pengambilan ulang berkala 15 detik di layar chat kedua belah pihak.
///
/// Siaran runner membawa nama klien beserta alamat jemput dan alamat tujuan. Karena itu hub
/// ini tertutup untuk yang belum masuk, dan grup runner hanya diisi akun yang memang
/// memegang peran runner. Sebelumnya setiap koneksi anonim langsung dimasukkan ke grup itu,
/// yang artinya siapa pun yang bisa menjangkau alamat servernya akan menerima alamat rumah
/// pelanggan.
///
/// Satu akun boleh masuk ke grup runner dan grup admin sekaligus (founder mitra yang
/// merangkap keduanya, bagian 14.2), karena keanggotaan grup di sini murni soal siaran mana
/// yang ingin didengar, bukan soal siapa boleh apa — penjagaan sungguhan tetap di endpoint
/// HTTP yang dipanggil sesudah kabar ini diterima.
///
/// ## Kenapa grup per-order beda dari dua grup di atas
///
/// Grup runner dan grup admin diisi otomatis begitu koneksinya dibuka, ditentukan semata
/// dari peran di token. Grup per-order tidak bisa begitu: satu orang boleh punya lebih dari
/// satu order yang sedang berjalan sekaligus (klien memesan dua kali sebelum melunasi salah
/// satunya, runner menawar di beberapa order Jalur B), dan yang perlu diikuti cuma order
/// yang layarnya sedang dibuka, bukan seluruh order yang menyangkut dirinya. Karena itu
/// bergabungnya lewat method <see cref="GabungOrder"/> yang dipanggil sisi klien sendiri
/// saat layarnya dibuka, bukan diputuskan otomatis dari peran.
///
/// Keanggotaannya diperiksa terhadap keterkaitan dengan ordernya
/// (<see cref="AksesOrder.BolehLihat"/>), tidak seperti dua grup di atas. Kabar yang
/// disiarkan ke grup ini cuma menyebut id order dan tidak membawa apa pun yang sensitif
/// (sama seperti dua grup lain), tapi membiarkan siapa pun bergabung ke grup order mana pun
/// tetap membocorkan satu hal: kapan order itu berubah, informasi yang bukan urusan orang
/// yang tidak berkepentingan di sana.
/// </summary>
[Authorize]
public class OrderHub(AppDbContext db) : Hub
{
    public const string RunnersGroup = "runners";
    public const string AdminsGroup = "admins";

    /// <summary>Nama grup satu order tertentu, dipakai sisi klien maupun sisi server.</summary>
    public static string GrupOrder(Guid orderId) => $"order-{orderId:N}";

    public override async Task OnConnectedAsync()
    {
        if (Context.User?.IsInRole(Peran.Runner) == true)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, RunnersGroup);
        }

        if (Context.User?.IsInRole(Peran.Admin) == true)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, AdminsGroup);
        }

        await base.OnConnectedAsync();
    }

    /// <summary>
    /// Seseorang yang berkepentingan pada satu order meminta didengarkan untuk order itu:
    /// klien saat layar bayar atau layar detailnya dibuka, runner saat layar chat atau
    /// detail ordernya dibuka.
    /// </summary>
    /// <remarks>
    /// Siapa yang boleh bergabung ditentukan <see cref="AksesOrder.BolehLihat"/>, aturan
    /// yang sama yang menjaga endpoint HTTP order dan chatnya — bukan salinan aturan
    /// tersendiri di sini. Kalau keduanya ditulis terpisah, cepat atau lambat salah satunya
    /// diperbaiki dan yang lain tidak, dan bedanya baru ketahuan kalau ada yang
    /// memeriksanya satu per satu.
    ///
    /// Permintaan bergabung ke order yang bukan urusannya diam-diam diabaikan, tidak
    /// dijawab galat. Method hub ini bisa dipanggil siapa pun yang sudah masuk dengan id
    /// order karangan sendiri, dan menjawabnya beda antara "order ini bukan urusanmu" dan
    /// "order ini tidak ada" akan membuatnya alat menebak-nebak id order siapa saja yang
    /// sedang berjalan.
    /// </remarks>
    public async Task GabungOrder(Guid orderId)
    {
        var order = await db.Orders
            .Include(o => o.RunnerAssignments)
            .Include(o => o.Offers)
            .SingleOrDefaultAsync(o => o.Id == orderId);

        if (order is null || !AksesOrder.BolehLihat(order, Context.User!.Id(), Context.User!)) return;

        await Groups.AddToGroupAsync(Context.ConnectionId, GrupOrder(orderId));
    }

    /// <summary>
    /// Klien berhenti mendengarkan satu order, begitu layar bayarnya ditutup.
    /// </summary>
    /// <remarks>
    /// Tanpa ini, klien yang membuka beberapa layar bayar berturut-turut dalam satu sesi
    /// (order pertama kedaluwarsa, coba lagi dengan order baru) akan terus menumpuk
    /// keanggotaan grup selama koneksinya hidup — satu koneksi dipakai sepanjang sesi,
    /// bukan dibuka ulang tiap layar (bagian 37.5). Tidak perlu pemeriksaan kepemilikan
    /// seperti <see cref="GabungOrder"/>: keluar dari grup yang tidak pernah diikuti bukan
    /// tindakan yang bisa disalahgunakan untuk mengetahui apa pun.
    /// </remarks>
    public async Task TinggalkanOrder(Guid orderId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, GrupOrder(orderId));
    }
}
