using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Carinderia.API.Models
{
    public class OrderItem
    {
        public int Id { get; set; }
        public int OrderId { get; set; }
        public Order? Order { get; set; }

        public int MenuItemId { get; set; }
        public MenuItem? MenuItem { get; set; }

        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public string? SpecialInstruction { get; set; }
    }
}