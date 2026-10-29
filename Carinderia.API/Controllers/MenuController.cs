using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Carinderia.API.Data;
using Carinderia.API.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Carinderia.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class MenuController : ControllerBase
    {
        private readonly AppDbContext _context;

        public MenuController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<Category>>> GetActiveMenu()
        {
            var categories = await _context.Categories
                .Include(c => c.MenuItems)
                .Select(c => new Category
                {
                    Id = c.Id,
                    Name = c.Name,
                    MenuItems = c.MenuItems.Where(m => m.IsAvailableToday).ToList()
                })
                .ToListAsync();

            return Ok(categories);
        }
    }
}