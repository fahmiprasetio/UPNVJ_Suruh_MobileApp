using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using UpnvjSuruh.Api.Auth;

namespace UpnvjSuruh.Api.Hubs;

/// <summary>
/// Saluran realtime tempat runner menunggu. Kode sisi server mengirim "OrderBroadcast"
/// ketika order berbayar butuh runner, dan "OrderTaken" begitu ada yang menerimanya, ini
/// yang menghapus langkah relay admin lewat WA di Jalur A (rencana capstone bagian 2 dan 4).
///
/// Siarannya membawa nama klien beserta alamat jemput dan alamat tujuan. Karena itu hub ini
/// tertutup untuk yang belum masuk, dan grup runner hanya diisi akun yang memang memegang
/// peran runner. Sebelumnya setiap koneksi anonim langsung dimasukkan ke grup itu, yang
/// artinya siapa pun yang bisa menjangkau alamat servernya akan menerima alamat rumah
/// pelanggan.
/// </summary>
[Authorize]
public class OrderHub : Hub
{
    public const string RunnersGroup = "runners";

    public override async Task OnConnectedAsync()
    {
        if (Context.User?.IsInRole(Peran.Runner) == true)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, RunnersGroup);
        }

        await base.OnConnectedAsync();
    }
}
