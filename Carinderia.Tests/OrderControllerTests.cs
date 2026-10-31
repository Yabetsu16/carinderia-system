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
        [Fact]
        public async Task PlaceOrder_ValidDto_CreatesOrderAndSetsStatusToPreparing()
        {
            using var context = GetInMemoryDbContext();
            // Create mocks for SignalR hub context
            var mockHubContext = new Mock<IHubContext<OrderHub>>();
            var mockClients = new Mock<IHubClients>();
            var mockClientProxy = new Mock<IClientProxy>();
            var mockAllProxy = new Mock<IClientProxy>();

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
            var mockHubContext = new Mock<IHubContext<OrderHub>>();
            var mockClients = new Mock<IHubClients>();
            var mockClientProxy = new Mock<IClientProxy>();
            var mockAllProxy = new Mock<IClientProxy>();

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
            // Create mocks for SignalR hub context
            var mockHubContext = new Mock<IHubContext<OrderHub>>();
            var mockClients = new Mock<IHubClients>();
            var mockClientProxy = new Mock<IClientProxy>();
            var mockAllProxy = new Mock<IClientProxy>();

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
            // Create mocks for SignalR hub context
            var mockHubContext = new Mock<IHubContext<OrderHub>>();
            var mockClients = new Mock<IHubClients>();
            var mockClientProxy = new Mock<IClientProxy>();
            var mockAllProxy = new Mock<IClientProxy>();

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

            // Mock SignalR Hub Context and Client Proxies for Table group and Kitchen group
            var mockHubContext = new Mock<IHubContext<OrderHub>>();
            var mockClients = new Mock<IHubClients>();
            var mockGroupProxy = new Mock<IClientProxy>();
            var mockKitchenProxy = new Mock<IClientProxy>();

            mockHubContext.Setup(h => h.Clients).Returns(mockClients.Object);
            mockClients.Setup(c => c.Group("Table_5")).Returns(mockGroupProxy.Object);
            mockClients.Setup(c => c.Group("Kitchen")).Returns(mockKitchenProxy.Object);

            var controller = new OrderController(context, mockHubContext.Object);
            var updateDto = new UpdateOrderStatusDto
            {
                Status = OrderStatus.ReadyForPickup
            };

            var result = await controller.UpdateOrderStatus(30, updateDto);

            // Assert that the notification was sent to both the specific table group and the kitchen group
            Assert.IsType<OkObjectResult>(result);

            mockGroupProxy.Verify(
                client => client.SendCoreAsync(
                    "ReceiveOrderUpdate",
                    It.Is<object[]>(o => o.Length == 1 && ((Order)o[0]).Id == 30),
                    default),
                Times.Once);

            mockKitchenProxy.Verify(
                client => client.SendCoreAsync(
                    "ReceiveOrderUpdate",
                    It.Is<object[]>(o => o.Length == 1 && ((Order)o[0]).Id == 30),
                    default),
                Times.Once);
        }
    }
}