using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Carinderia.API.Models
{
    public enum PaymentMethod
    {
        Cash,
        QRCode
    }

    public enum OrderStatus
    {
        PendingPayment,
        Preparing,
        ReadyForPickup,
        Completed,
        Cancelled
    }

    public class Order
    {
        public int Id { get; set; }
        public int TableNumber { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public PaymentMethod PaymentMethod { get; set; }
        public OrderStatus Status { get; set; }
        public decimal TotalAmount { get; set; }

        public List<OrderItem> OrderItems { get; set; } = new();
    }
}