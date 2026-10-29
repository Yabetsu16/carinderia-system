using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Carinderia.API.Models
{
    public class TableSession
    {
        public int Id { get; set; }
        public int TableNumber { get; set; }
        public bool IsOccupied { get; set; } = false;
        public string SessionToken { get; set; } = Guid.NewGuid().ToString();
    }
}