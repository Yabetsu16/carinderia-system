using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Carinderia.API.Controllers;
using Carinderia.API.Data;
using Carinderia.API.DTO;
using Carinderia.API.Hubs;
using Carinderia.API.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Moq;
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

        private Mock<IHubContext<OrderHub>> CreateMockHubContext(
    out Mock<IClientProxy> tableProxy,
    out Mock<IClientProxy> kitchenProxy)
        {
            var mockHubContext = new Mock<IHubContext<OrderHub>>();
            var mockClients = new Mock<IHubClients>();

            tableProxy = new Mock<IClientProxy>();
            kitchenProxy = new Mock<IClientProxy>();

            mockHubContext
                .Setup(h => h.Clients)
                .Returns(mockClients.Object);

            mockClients
                .Setup(c => c.Group(It.Is<string>(group => group != "Kitchen")))
                .Returns(tableProxy.Object);

            mockClients
                .Setup(c => c.Group("Kitchen"))
                .Returns(kitchenProxy.Object);

            return mockHubContext;
        }

        [Fact]
        public async Task PlaceOrder_ValidDto_CreatesOrderAndSetsStatusToPreparing()
        {
            using var context = GetInMemoryDbContext();
            // Create mocks for SignalR hub context
            var mockHubContext = CreateMockHubContext(out _, out _);

            var controller = new OrderController(context, mockHubContext.Object);


            var orderDto = new CreateOrderDto
            {
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

            var result = await controller.PlaceOrder(1, orderDto);

            var actionResult = Assert.IsType<CreatedAtActionResult>(result.Result);
            var createdOrder = Assert.IsType<Order>(actionResult.Value);

            Assert.Equal(1, createdOrder.TableNumber);
            Assert.Equal(OrderStatus.Preparing, createdOrder.Status);
            Assert.Equal(140, createdOrder.TotalAmount);
            Assert.Single(createdOrder.OrderItems);
        }

        [Fact]
        public async Task UpdateOrderStatus_ValidId_UpdatesStatusSuccessfully()
        {
            using var context = GetInMemoryDbContext();

            // Create mocks for SignalR hub context
            var mockHubContext = CreateMockHubContext(out _, out _);

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

            var controller = new OrderController(context, mockHubContext.Object);

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

        [Fact]
        public async Task PlaceOrder_QRCodePayment_SetsStatusToPendingPayment()
        {
            using var context = GetInMemoryDbContext();
            var mockHubContext = CreateMockHubContext(out _, out _);

            var controller = new OrderController(context, mockHubContext.Object);

            var orderDto = new CreateOrderDto
            {
                PaymentMethod = PaymentMethod.QRCode,
                Items = new List<CreateOrderItemDto>
                {
                    new CreateOrderItemDto
                    {
                        MenuItemId = 1,
                        Quantity = 1
                    }
                }
            };

            var result = await controller.PlaceOrder(3, orderDto);

            var actionResult = Assert.IsType<CreatedAtActionResult>(result.Result);
            var createdOrder = Assert.IsType<Order>(actionResult.Value);

            Assert.Equal(3, createdOrder.TableNumber);
            Assert.Equal(OrderStatus.PendingPayment, createdOrder.Status);
        }

        [Fact]
        public async Task ConfirmPayment_ValidOrderId_UpdatesStatusToPreparing()
        {
            using var context = GetInMemoryDbContext();
            var mockHubContext = CreateMockHubContext(out _, out _);

            var order = new Order
            {
                Id = 20,
                TableNumber = 1,
                PaymentMethod = PaymentMethod.QRCode,
                Status = OrderStatus.PendingPayment,
                TotalAmount = 70
            };

            context.Orders.Add(order);
            await context.SaveChangesAsync();

            var controller = new OrderController(context, mockHubContext.Object);

            var result = await controller.ConfirmPayment(20);

            Assert.IsType<OkObjectResult>(result);
            var updatedOrder = await context.Orders.FindAsync(20);
            Assert.NotNull(updatedOrder);
            Assert.Equal(OrderStatus.Preparing, updatedOrder.Status);
        }

        [Fact]
        public async Task UpdateOrderStatus_SendsSignalRNotificationToSpecificTableGroup()
        {
            using var context = GetInMemoryDbContext();

            var order = new Order
            {
                Id = 30,
                TableNumber = 5,
                PaymentMethod = PaymentMethod.Cash,
                Status = OrderStatus.Preparing,
                TotalAmount = 150
            };

            context.Orders.Add(order);
            await context.SaveChangesAsync();

            var mockHubContext = CreateMockHubContext(
                out var mockGroupProxy,
                out var mockKitchenProxy);

            var controller = new OrderController(context, mockHubContext.Object);

            var updateDto = new UpdateOrderStatusDto
            {
                Status = OrderStatus.ReadyForPickup
            };

            var result = await controller.UpdateOrderStatus(30, updateDto);

            Assert.IsType<OkObjectResult>(result);

            // Verify notification sent to the specific table group.
            mockGroupProxy.Verify(
                client => client.SendCoreAsync(
                    "ReceiveOrderUpdate",
                    It.Is<object[]>(args =>
                        args.Length == 1 &&
                        args[0] is OrderUpdateDto &&
                        ((OrderUpdateDto)args[0]).Id == 30 &&
                        ((OrderUpdateDto)args[0]).TableNumber == 5 &&
                        ((OrderUpdateDto)args[0]).Status == OrderStatus.ReadyForPickup),
                    default),
                Times.Once);

            // Verify notification sent to the kitchen group.
            mockKitchenProxy.Verify(
                client => client.SendCoreAsync(
                    "ReceiveOrderUpdate",
                    It.Is<object[]>(args =>
                        args.Length == 1 &&
                        args[0] is OrderUpdateDto &&
                        ((OrderUpdateDto)args[0]).Id == 30 &&
                        ((OrderUpdateDto)args[0]).TableNumber == 5 &&
                        ((OrderUpdateDto)args[0]).Status == OrderStatus.ReadyForPickup),
                    default),
                Times.Once);
        }

        [Fact]
        public async Task PlaceOrder_EmptyItems_ReturnsBadRequest()
        {
            using var context = GetInMemoryDbContext();

            var controller = new OrderController(context);

            var orderDto = new CreateOrderDto
            {
                PaymentMethod = PaymentMethod.Cash,
                Items = new List<CreateOrderItemDto>()
            };

            var result = await controller.PlaceOrder(1, orderDto);

            Assert.IsType<BadRequestObjectResult>(result.Result);
            Assert.Empty(context.Orders);
        }

        [Fact]
        public async Task PlaceOrder_UnavailableMenuItem_ReturnsBadRequest()
        {
            using var context = GetInMemoryDbContext();

            var unavailableMenuItem = new MenuItem
            {
                Id = 2,
                Name = "Unavailable Item",
                Price = 100,
                IsAvailableToday = false
            };

            context.MenuItems.Add(unavailableMenuItem);
            await context.SaveChangesAsync();

            var controller = new OrderController(context);

            var orderDto = new CreateOrderDto
            {
                PaymentMethod = PaymentMethod.Cash,
                Items = new List<CreateOrderItemDto>
        {
            new CreateOrderItemDto
            {
                MenuItemId = 2,
                Quantity = 1
            }
        }
            };

            var result = await controller.PlaceOrder(1, orderDto);

            Assert.IsType<BadRequestObjectResult>(result.Result);
            Assert.Empty(context.Orders);
        }

        [Fact]
        public async Task ConfirmPayment_NonexistentOrderId_ReturnsNotFound()
        {
            using var context = GetInMemoryDbContext();

            var controller = new OrderController(context);

            var result = await controller.ConfirmPayment(999);

            Assert.IsType<NotFoundResult>(result);
        }

        [Fact]
        public async Task UpdateOrderStatus_NonexistentId_ReturnsNotFound()
        {
            using var context = GetInMemoryDbContext();

            var controller = new OrderController(context);

            var updateDto = new UpdateOrderStatusDto
            {
                Status = OrderStatus.ReadyForPickup
            };

            var result = await controller.UpdateOrderStatus(999, updateDto);

            Assert.IsType<NotFoundResult>(result);
        }
    }
}