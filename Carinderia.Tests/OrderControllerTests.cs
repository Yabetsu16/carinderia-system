using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Carinderia.API.Controllers;
using Carinderia.API.Data;
using Carinderia.API.DTO;
using Carinderia.API.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Carinderia.Tests
{
    public class OrderControllerTests
    {
        private AppDbContext GetInMemoryDbContext()
        {
            var options = new DbContextOptionsBuilder<AppDbContext>()
                .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
                .Options;

            var context = new AppDbContext(options);

            context.MenuItems.Add(new MenuItem
            {
                Id = 1,
                Name = "Adobo",
                Price = 70,
                IsAvailableToday = true
            });

            context.SaveChanges();
            return context;
        }
        [Fact]
        public async Task PlaceOrder_ValidDto_CreatesOrderAndSetsStatusToPreparing()
        {
            using var context = GetInMemoryDbContext();
            var controller = new OrderController(context);

            var orderDto = new CreateOrderDto
            {
                TableNumber = 5,
                PaymentMethod = PaymentMethod.Cash,
                Items = new List<CreateOrderItemDto>
                {
                    new CreateOrderItemDto
                    {
                        MenuItemId = 1,
                        Quantity = 2,
                        SpecialInstruction = "Extra sauce"
                    }
                }
            };

            var result = await controller.PlaceOrder(orderDto);

            var actionResult = Assert.IsType<CreatedAtActionResult>(result.Result);
            var createdOrder = Assert.IsType<Order>(actionResult.Value);

            Assert.Equal(5, createdOrder.TableNumber);
            Assert.Equal(OrderStatus.Preparing, createdOrder.Status);
            Assert.Equal(140, createdOrder.TotalAmount);
            Assert.Single(createdOrder.OrderItems);
        }

        [Fact]
        public async Task UpdateOrderStatus_ValidId_UpdatesStatusSuccessfully()
        {
            using var context = GetInMemoryDbContext();
            var order = new Order
            {
                Id = 10,
                TableNumber = 2,
                PaymentMethod = PaymentMethod.QRCode,
                Status = OrderStatus.Preparing,
                TotalAmount = 100
            };

            context.Orders.Add(order);
            await context.SaveChangesAsync();

            var controller = new OrderController(context);
            var updateDto = new UpdateOrderStatusDto
            {
                Status = OrderStatus.ReadyForPickup
            };

            var result = await controller.UpdateOrderStatus(10, updateDto);

            Assert.IsType<OkObjectResult>(result);
            var updatedOrderInDb = await context.Orders.FindAsync(10);
            Assert.NotNull(updatedOrderInDb);
            Assert.Equal(OrderStatus.ReadyForPickup, updatedOrderInDb.Status);
        }
    }
}