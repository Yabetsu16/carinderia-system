using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Carinderia.API.Data;
using Carinderia.API.DTO;
using Carinderia.API.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Carinderia.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class OrderController : ControllerBase
    {
        private readonly AppDbContext _context;

        public OrderController(AppDbContext context)
        {
            _context = context;
        }

        [HttpPost]
        public async Task<ActionResult<Order>> PlaceOrder([FromBody] CreateOrderDto orderDto)
        {
            if (orderDto.Items == null || !orderDto.Items.Any())
            {
                return BadRequest(new { message = "Cannot place an order with no items." });
            }

            var order = new Order
            {
                TableNumber = orderDto.TableNumber,
                PaymentMethod = orderDto.PaymentMethod,
                Status = OrderStatus.Preparing,
                CreatedAt = DateTime.UtcNow
            };

            decimal totalAmount = 0;

            foreach (var itemDto in orderDto.Items)
            {
                var menuItem = await _context.MenuItems.FindAsync(itemDto.MenuItemId);
                if (menuItem == null || !menuItem.IsAvailableToday)
                {
                    return BadRequest(new { message = $"Menu item with ID {itemDto.MenuItemId} is not available." });
                }

                var orderItem = new OrderItem
                {
                    MenuItemId = menuItem.Id,
                    Quantity = itemDto.Quantity,
                    UnitPrice = menuItem.Price,
                    SpecialInstruction = itemDto.SpecialInstruction
                };

                totalAmount += menuItem.Price * itemDto.Quantity;
                order.OrderItems.Add(orderItem);
            }

            order.TotalAmount = totalAmount;

            _context.Orders.Add(order);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(GetOrderById), new { id = order.Id }, order);
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<Order>>> GetAllOrders([FromQuery] OrderStatus? status)
        {
            var query = _context.Orders
                .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.MenuItem)
                .AsQueryable();

            if (status.HasValue)
                query = query.Where(o => o.Status == status.Value);

            var orders = await query.OrderByDescending(o => o.CreatedAt).ToListAsync();

            return Ok(orders);
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<Order>> GetOrderById(int id)
        {
            var order = await _context.Orders
                .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.MenuItem)
                .FirstOrDefaultAsync(o => o.Id == id);

            if (order == null)
                return NotFound();

            return Ok(order);
        }

        [HttpPatch("{id}/status")]
        public async Task<IActionResult> UpdateOrderStatus(int id, [FromBody] UpdateOrderStatusDto statusDto)
        {
            var order = await _context.Orders.FindAsync(id);

            if (order == null) return NotFound();

            order.Status = statusDto.Status;
            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Order status updated successfully",
                orderId = order.Id,
                newStatus = order.Status.ToString()
            });
        }
    }
}