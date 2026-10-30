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
        public async Task<ActionResult<Order>> PlaceOrder(int tableNumber, [FromBody] CreateOrderDto orderDto)
        {
            if (orderDto.Items == null || !orderDto.Items.Any())
            {
                return BadRequest(new { message = "Cannot place an order with no items." });
            }

            var order = new Order
            {
                TableNumber = tableNumber,
                PaymentMethod = orderDto.PaymentMethod,
                // PaymentMethod 1 (QR Code) starts as PendingPayment; Cash starts as Preparing
                Status = orderDto.PaymentMethod == PaymentMethod.QRCode
                    ? OrderStatus.PendingPayment
                    : OrderStatus.Preparing,
                CreatedAt = DateTime.UtcNow
            };

            decimal totalAmount = 0;
            foreach (var itemDto in orderDto.Items)
            {
                var menuItem = await _context.MenuItems.FindAsync(itemDto.MenuItemId);
                if (menuItem == null || !menuItem.IsAvailableToday)
                    return BadRequest(new { message = $"Menu item ID {itemDto.MenuItemId} is unavailable." });

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
        public async Task<ActionResult<IEnumerable<Order>>> GetAllOrders([FromQuery] int? status, [FromQuery] bool includeArchived = false)
        {
            var query = _context.Orders
                .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.MenuItem)
                .AsQueryable();

            if (!includeArchived)
            {
                query = query.Where(o => !o.IsArchived);
            }

            if (status.HasValue)
            {
                // Explicitly filter by the integer value of the OrderStatus enum
                query = query.Where(o => (int)o.Status == status.Value);
            }
            else
            {
                // Default behavior for KDS kitchen board (excludes pending payments)
                query = query.Where(o => o.Status >= OrderStatus.Preparing);
            }

            var orders = await query.OrderByDescending(o => o.CreatedAt).ToListAsync();
            return Ok(orders);
        }

        [HttpGet("history")]
        public async Task<ActionResult<IEnumerable<Order>>> GetOrderHistory()
        {
            var orders = await _context.Orders
                .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.MenuItem)
                .Where(o => o.IsArchived)
                .OrderByDescending(o => o.CreatedAt)
                .ToListAsync();
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

        [HttpPatch("{id}/confirm-payment")]
        public async Task<IActionResult> ConfirmPayment(int id)
        {
            var order = await _context.Orders.FindAsync(id);
            if (order == null) return NotFound();

            order.Status = OrderStatus.Preparing; // Sends order straight to the kitchen
            await _context.SaveChangesAsync();

            return Ok(new { message = "Payment confirmed. Order sent to kitchen." });
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

        [HttpPatch("{id}/archive")]
        public async Task<IActionResult> ArchiveOrder(int id)
        {
            var order = await _context.Orders.FindAsync(id);
            if (order == null) return NotFound();

            order.IsArchived = true; // Marks it as archived so it drops off the active board
            await _context.SaveChangesAsync();

            return Ok(new { message = "Order archived successfully" });
        }
    }
}