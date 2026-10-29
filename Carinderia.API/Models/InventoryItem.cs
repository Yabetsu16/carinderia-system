using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Carinderia.API.Models
{
    public class InventoryItem
    {
        public int Id { get; set; }
        public string ItemName { get; set; } = string.Empty;
        public double Quantity { get; set; }
        public string UnitPrice { get; set; } = string.Empty;
        public double ReorderLevel { get; set; }
    }
}