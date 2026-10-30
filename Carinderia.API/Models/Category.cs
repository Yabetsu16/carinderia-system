using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Carinderia.API.Models
{
    public class Category
    {
        public int Id { get; set; }
        public required string Name { get; set; }
        public List<MenuItem> MenuItems { get; set; } = new();
    }
}