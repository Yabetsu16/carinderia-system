using System.Linq;
using Carinderia.API.Data;
using Carinderia.API.DTO;
using Carinderia.API.Hubs;
using Carinderia.API.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace Carinderia.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class OrderController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IHubContext<OrderHub>? _hubContext;

        public OrderController(AppDbContext context, IHubContext<OrderHub>? hubContext = null)
        {
            _context = context;
            _hubContext = hubContext;
        }

        [HttpPost("/api/{tableNumber}/order")]
        public async Task<ActionResult<Order>> PlaceOrder(int tableNumber, [FromBody] CreateOrderDto orderDto)
        {
            if (tableNumber <= 0)
            {
                return BadRequest(new
                {
                    message = "Table number must be greater than zero."
                });
            }

            if (!Enum.IsDefined(orderDto.PaymentMethod))
            {
                return BadRequest(new
                {
                    message = "Invalid payment method."
                });
            }

            if (orderDto.Items == null || !orderDto.Items.Any())
            {
                return BadRequest(new { message = "Cannot place an order with no items." });
            }

            if (orderDto.Items
                .GroupBy(item => item.MenuItemId)
                .Any(group => group.Count() > 1))
            {
                return BadRequest(new
                {
                    message = "Duplicate menu items are not allowed in an order."
                });
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
                if (itemDto.Quantity <= 0)
                {
                    return BadRequest(new
                    {
                        message = "Quantity must be greater than zero."
                    });
                }

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
            await NotifyTableAsync(tableNumber, order);

            return CreatedAtAction(nameof(GetOrderById), new { id = order.Id }, order); ;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<Order>>> GetAllOrders([FromQuery] int? status, [FromQuery] int? tableNumber, [FromQuery] bool includeArchived = false)
        {
            var query = _context.Orders
                .Include(o => o.OrderItems)
                .ThenInclude(oi => oi.MenuItem)
                .AsQueryable();

            if (!includeArchived)
            {
                query = query.Where(o => !o.IsArchived);
            }

            if (tableNumber.HasValue && tableNumber.Value <= 0)
            {
                return BadRequest(new
                {
                    message = "Table number must be greater than zero."
                });
            }

            if (tableNumber.HasValue)
            {
                query = query.Where(o => o.TableNumber == tableNumber.Value);
            }

            if (status.HasValue && !Enum.IsDefined(typeof(OrderStatus), status.Value))
            {
                return BadRequest(new
                {
                    message = "Invalid order status."
                });
            }

            if (status.HasValue)
            {
                query = query.Where(o => (int)o.Status == status.Value);
            }
            else
            {
                // Include PendingPayment (0) up to Ready/Completed for table views
                query = query.Where(o => o.Status >= OrderStatus.PendingPayment);
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
            var order = await _context.Orders
                .Include(o => o.OrderItems)
                .ThenInclude(item => item.MenuItem)
                .FirstOrDefaultAsync(o => o.Id == id);

            if (order == null)
                return NotFound();

            if (order.PaymentMethod != PaymentMethod.QRCode ||
                order.Status != OrderStatus.PendingPayment)
            {
                return BadRequest(new
                {
                    message = "Only QR orders with pending payment can be confirmed."
                });
            }

            order.Status = OrderStatus.Preparing;

            await _context.SaveChangesAsync();
            await NotifyTableAsync(order.TableNumber, order);

            return Ok(new
            {
                message = "Payment confirmed. Order sent to kitchen."
            });
        }

        [HttpPatch("{id}/status")]
        public async Task<IActionResult> UpdateOrderStatus(int id, [FromBody] UpdateOrderStatusDto statusDto)
        {
            var order = await _context.Orders
                .Include(o => o.OrderItems)
                .ThenInclude(item => item.MenuItem)
                .FirstOrDefaultAsync(o => o.Id == id);

            if (order == null) return NotFound();

            if (!Enum.IsDefined(statusDto.Status))
            {
                return BadRequest(new
                {
                    message = "Invalid order status."
                });
            }

            if (!CanTransitionStatus(order.Status, statusDto.Status))
            {
                return BadRequest(new
                {
                    message = $"Cannot change order status from {order.Status} to {statusDto.Status}."
                });
            }

            order.Status = statusDto.Status;
            await _context.SaveChangesAsync();
            await NotifyTableAsync(order.TableNumber, order);

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

            if (order == null)
                return NotFound();

            if (order.Status != OrderStatus.Completed &&
                order.Status != OrderStatus.Cancelled)
            {
                return BadRequest(new
                {
                    message = "Only completed or cancelled orders can be archived."
                });
            }

            order.IsArchived = true;

            await _context.SaveChangesAsync();

            return Ok(new
            {
                message = "Order archived successfully"
            });
        }

        private async Task NotifyTableAsync(int tableNumber, Order order)
        {
            if (_hubContext == null)
                return;

            var orderUpdate = new OrderUpdateDto
            {
                Id = order.Id,
                TableNumber = order.TableNumber,
                PaymentMethod = order.PaymentMethod,
                Status = order.Status,
                TotalAmount = order.TotalAmount,
                CreatedAt = order.CreatedAt,

                OrderItems = order.OrderItems.Select(item => new OrderItemUpdateDto
                {
                    Id = item.Id,
                    MenuItemName = item.MenuItem?.Name ?? "Item",
                    Quantity = item.Quantity,
                    SpecialInstruction = item.SpecialInstruction
                }).ToList()
            };

            await _hubContext.Clients
                .Group($"Table_{tableNumber}")
                .SendAsync("ReceiveOrderUpdate", orderUpdate);

            await _hubContext.Clients
                .Group("Kitchen")
                .SendAsync("ReceiveOrderUpdate", orderUpdate);

            Console.WriteLine(
                $"[SignalR] Order #{order.Id} notification sent to Table_{tableNumber} and Kitchen");
        }

        private static bool CanTransitionStatus(
            OrderStatus currentStatus,
            OrderStatus newStatus)
        {
            return currentStatus switch
            {
                OrderStatus.PendingPayment =>
                    newStatus is OrderStatus.Preparing or OrderStatus.Cancelled,

                OrderStatus.Preparing =>
                    newStatus is OrderStatus.ReadyForPickup or OrderStatus.Cancelled,

                OrderStatus.ReadyForPickup =>
                    newStatus is OrderStatus.Completed or OrderStatus.Cancelled,

                _ => false
            };
        }
    }
}