using Microsoft.AspNetCore.SignalR;
using System.Threading.Tasks;

namespace Carinderia.API.Hubs
{
    public class OrderHub : Hub
    {
        public async Task JoinTable(int tableNumber)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"Table_{tableNumber}");
        }

        public async Task LeaveTable(int tableNumber)
        {
            await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"Table_{tableNumber}");
        }

        public async Task JoinKitchen()
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, "Kitchen");
        }
    }
}