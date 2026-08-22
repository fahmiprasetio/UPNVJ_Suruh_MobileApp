using Microsoft.AspNetCore.SignalR;

namespace UpnvjSuruh.Api.Hubs;

/// <summary>
/// Realtime channel runners stay connected to. Server-side code pushes "OrderBroadcast"
/// when a paid order needs a runner, and "OrderTaken" once someone accepts it — this is
/// what removes the WA admin-relay step from Jalur A (see rencana capstone bagian 2 &amp; 4).
/// </summary>
public class OrderHub : Hub
{
    public const string RunnersGroup = "runners";

    public override async Task OnConnectedAsync()
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, RunnersGroup);
        await base.OnConnectedAsync();
    }
}
