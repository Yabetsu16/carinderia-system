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
        public async Task GetAllOrders_ExcludesArchivedOrdersByDefault()
        {
            using var context = GetInMemoryDbContext();

            var activeOrder = new Order
            {
                Id = 1,
                TableNumber = 1,
                PaymentMethod = PaymentMethod.Cash,
                Status = OrderStatus.Preparing,
                TotalAmount = 100,
                IsArchived = false,
                CreatedAt = DateTime.UtcNow
            };

            var archivedOrder = new Order
            {
                Id = 2,
                TableNumber = 2,
                PaymentMethod = PaymentMethod.Cash,
                Status = OrderStatus.Completed,
                TotalAmount = 200,
                IsArchived = true,
                CreatedAt = DateTime.UtcNow
            };

            context.Orders.AddRange(activeOrder, archivedOrder);
            await context.SaveChangesAsync();

            var controller = new OrderController(context);

            var result = await controller.GetAllOrders(
                status: null,
                tableNumber: null,
                includeArchived: false);

            var actionResult = Assert.IsType<OkObjectResult>(result.Result);

            var orders = Assert.IsAssignableFrom<IEnumerable<Order>>(
                actionResult.Value);

            Assert.Single(orders);
            Assert.Equal(1, orders.First().Id);
        }

        [Fact]
        public async Task GetAllOrders_FiltersOrdersByTableNumber()
        {
            using var context = GetInMemoryDbContext();

            context.Orders.AddRange(
                new Order
                {
                    Id = 1,
                    TableNumber = 1,
                    Status = OrderStatus.Preparing,
                    PaymentMethod = PaymentMethod.Cash,
                    TotalAmount = 100
                },
                new Order
                {
                    Id = 2,
                    TableNumber = 2,
                    Status = OrderStatus.Preparing,
                    PaymentMethod = PaymentMethod.Cash,
                    TotalAmount = 150
                }
            );

            await context.SaveChangesAsync();

            var controller = new OrderController(context);

            var result = await controller.GetAllOrders(
                status: null,
                tableNumber: 1,
                includeArchived: false);

            var actionResult = Assert.IsType<OkObjectResult>(result.Result);
            var orders = Assert.IsAssignableFrom<IEnumerable<Order>>(
                actionResult.Value);

            Assert.Single(orders);
            Assert.All(orders, order => Assert.Equal(1, order.TableNumber));
        }

        [Fact]
        public async Task GetAllOrders_FiltersOrdersByStatus()
        {
            using var context = GetInMemoryDbContext();

            context.Orders.AddRange(
                new Order
                {
                    Id = 1,
                    TableNumber = 1,
                    Status = OrderStatus.Preparing,
                    PaymentMethod = PaymentMethod.Cash,
                    TotalAmount = 100
                },
                new Order
                {
                    Id = 2,
                    TableNumber = 2,
                    Status = OrderStatus.ReadyForPickup,
                    PaymentMethod = PaymentMethod.Cash,
                    TotalAmount = 150
                }
            );

            await context.SaveChangesAsync();

            var controller = new OrderController(context);

            var result = await controller.GetAllOrders(
                status: (int)OrderStatus.Preparing,
                tableNumber: null,
                includeArchived: false);

            var actionResult = Assert.IsType<OkObjectResult>(result.Result);
            var orders = Assert.IsAssignableFrom<IEnumerable<Order>>(
                actionResult.Value);

            Assert.Single(orders);
            Assert.All(
                orders,
                order => Assert.Equal(OrderStatus.Preparing, order.Status));
        }

        [Fact]
        public async Task GetAllOrders_IncludeArchived_ReturnsActiveAndArchivedOrders()
        {
            using var context = GetInMemoryDbContext();

            context.Orders.AddRange(
                new Order
                {
                    Id = 1,
                    TableNumber = 1,
                    PaymentMethod = PaymentMethod.Cash,
                    Status = OrderStatus.Preparing,
                    TotalAmount = 100,
                    IsArchived = false
                },
                new Order
                {
                    Id = 2,
                    TableNumber = 2,
                    PaymentMethod = PaymentMethod.Cash,
                    Status = OrderStatus.Completed,
                    TotalAmount = 200,
                    IsArchived = true
                }
            );

            await context.SaveChangesAsync();

            var controller = new OrderController(context);

            var result = await controller.GetAllOrders(
                status: null,
                tableNumber: null,
                includeArchived: true);

            var actionResult = Assert.IsType<OkObjectResult>(result.Result);
            var orders = Assert.IsAssignableFrom<IEnumerable<Order>>(
                actionResult.Value);

            Assert.Equal(2, orders.Count());
            Assert.Contains(orders, order => order.Id == 1);
            Assert.Contains(orders, order => order.Id == 2);
        }

        [Fact]
        public async Task GetAllOrders_ReturnsOrdersSortedByNewestFirst()
        {
            using var context = GetInMemoryDbContext();

            var olderOrder = new Order
            {
                Id = 1,
                TableNumber = 1,
                PaymentMethod = PaymentMethod.Cash,
                Status = OrderStatus.Preparing,
                TotalAmount = 100,
                CreatedAt = DateTime.UtcNow.AddHours(-2)
            };

            var newerOrder = new Order
            {
                Id = 2,
                TableNumber = 2,
                PaymentMethod = PaymentMethod.Cash,
                Status = OrderStatus.Preparing,
                TotalAmount = 200,
                CreatedAt = DateTime.UtcNow
            };

            context.Orders.AddRange(olderOrder, newerOrder);
            await context.SaveChangesAsync();

            var controller = new OrderController(context);

            var result = await controller.GetAllOrders(
                status: null,
                tableNumber: null,
                includeArchived: false);

            var actionResult = Assert.IsType<OkObjectResult>(result.Result);
            var orders = Assert.IsAssignableFrom<IEnumerable<Order>>(
                actionResult.Value).ToList();

            Assert.Equal(2, orders.Count);
            Assert.Equal(2, orders[0].Id);
            Assert.Equal(1, orders[1].Id);
        }

        [Fact]
        public async Task GetAllOrders_InvalidStatus_ReturnsBadRequest()
        {
            // Arrange
            using var context = GetInMemoryDbContext();

            var controller = new OrderController(context);

            // Act
            var result = await controller.GetAllOrders(
                status: 999,
                tableNumber: null);

            // Assert
            Assert.IsType<BadRequestObjectResult>(result.Result);
        }

        [Fact]
        public async Task GetAllOrders_InvalidTableNumber_ReturnsBadRequest()
        {
            // Arrange
            using var context = GetInMemoryDbContext();

            var controller = new OrderController(context);

            // Act
            var result = await controller.GetAllOrders(
                status: null,
                tableNumber: -1);

            // Assert
            Assert.IsType<BadRequestObjectResult>(result.Result);
        }

        [Fact]
        public async Task GetOrderHistory_ReturnsOnlyArchivedOrders()
        {
            using var context = GetInMemoryDbContext();

            context.Orders.AddRange(
                new Order
                {
                    Id = 1,
                    TableNumber = 1,
                    PaymentMethod = PaymentMethod.Cash,
                    Status = OrderStatus.Completed,
                    TotalAmount = 100,
                    IsArchived = false,
                    CreatedAt = DateTime.UtcNow.AddHours(-2)
                },
                new Order
                {
                    Id = 2,
                    TableNumber = 2,
                    PaymentMethod = PaymentMethod.Cash,
                    Status = OrderStatus.Completed,
                    TotalAmount = 200,
                    IsArchived = true,
                    CreatedAt = DateTime.UtcNow.AddHours(-1)
                },
                new Order
                {
                    Id = 3,
                    TableNumber = 3,
                    PaymentMethod = PaymentMethod.Cash,
                    Status = OrderStatus.Completed,
                    TotalAmount = 300,
                    IsArchived = true,
                    CreatedAt = DateTime.UtcNow
                }
            );

            await context.SaveChangesAsync();

            var controller = new OrderController(context);

            var result = await controller.GetOrderHistory();

            var actionResult = Assert.IsType<OkObjectResult>(result.Result);
            var orders = Assert.IsAssignableFrom<IEnumerable<Order>>(
                actionResult.Value).ToList();

            Assert.Equal(2, orders.Count);
            Assert.All(orders, order => Assert.True(order.IsArchived));

            // Newest archived order should appear first.
            Assert.Equal(3, orders[0].Id);
            Assert.Equal(2, orders[1].Id);
        }

        [Fact]
        public async Task GetOrderById_ExistingId_ReturnsOrderWithOrderItems()
        {
            using var context = GetInMemoryDbContext();

            var order = new Order
            {
                Id = 1,
                TableNumber = 3,
                PaymentMethod = PaymentMethod.Cash,
                Status = OrderStatus.Preparing,
                TotalAmount = 140,
                CreatedAt = DateTime.UtcNow,
                OrderItems =
        {
            new OrderItem
            {
                MenuItemId = 1,
                Quantity = 2,
                UnitPrice = 70
            }
        }
            };

            context.Orders.Add(order);
            await context.SaveChangesAsync();

            var controller = new OrderController(context);

            var result = await controller.GetOrderById(1);

            var actionResult = Assert.IsType<OkObjectResult>(result.Result);
            var returnedOrder = Assert.IsType<Order>(actionResult.Value);

            Assert.Equal(1, returnedOrder.Id);
            Assert.Equal(3, returnedOrder.TableNumber);
            Assert.Equal(140, returnedOrder.TotalAmount);

            Assert.Single(returnedOrder.OrderItems);
            Assert.Equal(1, returnedOrder.OrderItems.First().MenuItemId);
            Assert.Equal(2, returnedOrder.OrderItems.First().Quantity);

            Assert.NotNull(returnedOrder.OrderItems.First().MenuItem);
            Assert.Equal(
                "Adobo",
                returnedOrder.OrderItems.First().MenuItem!.Name);
        }

        [Fact]
        public async Task GetOrderById_NonexistentId_ReturnsNotFound()
        {
            using var context = GetInMemoryDbContext();

            var controller = new OrderController(context);

            var result = await controller.GetOrderById(999);

            Assert.IsType<NotFoundResult>(result.Result);
        }

        [Fact]
        public async Task ArchiveOrder_ValidId_ArchivesOrderSuccessfully()
        {
            using var context = GetInMemoryDbContext();

            var order = new Order
            {
                Id = 1,
                TableNumber = 3,
                PaymentMethod = PaymentMethod.Cash,
                Status = OrderStatus.Completed,
                TotalAmount = 140,
                IsArchived = false
            };

            context.Orders.Add(order);
            await context.SaveChangesAsync();

            var controller = new OrderController(context);

            var result = await controller.ArchiveOrder(1);

            var actionResult = Assert.IsType<OkObjectResult>(result);

            var archivedOrder = await context.Orders.FindAsync(1);

            Assert.NotNull(archivedOrder);
            Assert.True(archivedOrder.IsArchived);
        }

        [Fact]
        public async Task ArchiveOrder_NonexistentId_ReturnsNotFound()
        {
            using var context = GetInMemoryDbContext();

            var controller = new OrderController(context);

            var result = await controller.ArchiveOrder(999);

            Assert.IsType<NotFoundResult>(result);
        }

        [Fact]
        public async Task ArchiveOrder_PreparingOrder_ReturnsBadRequest()
        {
            // Arrange
            using var context = GetInMemoryDbContext();

            var order = new Order
            {
                Id = 103,
                TableNumber = 1,
                PaymentMethod = PaymentMethod.Cash,
                Status = OrderStatus.Preparing,
                TotalAmount = 70,
                IsArchived = false
            };

            context.Orders.Add(order);
            await context.SaveChangesAsync();

            var controller = new OrderController(context);

            // Act
            var result = await controller.ArchiveOrder(103);

            // Assert
            Assert.IsType<BadRequestObjectResult>(result);

            var unchangedOrder = await context.Orders.FindAsync(103);

            Assert.NotNull(unchangedOrder);
            Assert.False(unchangedOrder.IsArchived);
        }

        [Fact]
        public async Task ArchiveOrder_CompletedOrder_ArchivesSuccessfully()
        {
            // Arrange
            using var context = GetInMemoryDbContext();

            var order = new Order
            {
                Id = 104,
                TableNumber = 1,
                PaymentMethod = PaymentMethod.Cash,
                Status = OrderStatus.Completed,
                TotalAmount = 70,
                IsArchived = false
            };

            context.Orders.Add(order);
            await context.SaveChangesAsync();

            var controller = new OrderController(context);

            // Act
            var result = await controller.ArchiveOrder(104);

            // Assert
            Assert.IsType<OkObjectResult>(result);

            var archivedOrder = await context.Orders.FindAsync(104);

            Assert.NotNull(archivedOrder);
            Assert.True(archivedOrder.IsArchived);
        }

        [Fact]
        public async Task PlaceOrder_ValidDto_CreatesOrderAndSetsStatusToPreparing()
        {
            using var context = GetInMemoryDbContext();
            // Create mocks for SignalR hub context
            var mockHubContext = CreateMockHubContext(
                out var tableGroupProxy,
                out var kitchenGroupProxy);

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

            // Verify notification sent to the table group
            tableGroupProxy.Verify(
                client => client.SendCoreAsync(
                    "ReceiveOrderUpdate",
                    It.Is<object[]>(args =>
                        args.Length == 1 &&
                        args[0] is OrderUpdateDto &&
                        ((OrderUpdateDto)args[0]).TableNumber == 1),
                    default),
                Times.Once);

            // Verify notification sent to the kitchen group
            kitchenGroupProxy.Verify(
                client => client.SendCoreAsync(
                    "ReceiveOrderUpdate",
                    It.Is<object[]>(args =>
                        args.Length == 1 &&
                        args[0] is OrderUpdateDto &&
                        ((OrderUpdateDto)args[0]).TableNumber == 1),
                    default),
                Times.Once);
        }

        [Fact]
        public async Task PlaceOrder_DuplicateMenuItemIds_ReturnsBadRequest()
        {
            // Arrange
            var context = GetInMemoryDbContext();
            var controller = new OrderController(context);

            var orderDto = new CreateOrderDto
            {
                PaymentMethod = PaymentMethod.Cash,
                Items = new List<CreateOrderItemDto>
        {
            new()
            {
                MenuItemId = 1,
                Quantity = 1
            },
            new()
            {
                MenuItemId = 1,
                Quantity = 2
            }
        }
            };

            // Act
            var result = await controller.PlaceOrder(1, orderDto);

            // Assert
            Assert.IsType<BadRequestObjectResult>(result.Result);
            Assert.Empty(context.Orders);
        }

        [Fact]
        public async Task PlaceOrder_InvalidTableNumber_ReturnsBadRequest()
        {
            // Arrange
            var context = GetInMemoryDbContext();
            var controller = new OrderController(context);

            var orderDto = new CreateOrderDto
            {
                PaymentMethod = PaymentMethod.Cash,
                Items = new List<CreateOrderItemDto>
        {
            new()
            {
                MenuItemId = 1,
                Quantity = 1
            }
        }
            };

            // Act
            var result = await controller.PlaceOrder(0, orderDto);

            // Assert
            Assert.IsType<BadRequestObjectResult>(result.Result);
            Assert.Empty(context.Orders);
        }

        [Fact]
        public async Task PlaceOrder_ZeroQuantity_ReturnsBadRequest()
        {
            using var context = GetInMemoryDbContext();

            var controller = new OrderController(context);

            var orderDto = new CreateOrderDto
            {
                PaymentMethod = PaymentMethod.Cash,
                Items = new List<CreateOrderItemDto>
        {
            new CreateOrderItemDto
            {
                MenuItemId = 1,
                Quantity = 0
            }
        }
            };

            var result = await controller.PlaceOrder(1, orderDto);

            Assert.IsType<BadRequestObjectResult>(result.Result);

            Assert.Empty(context.Orders);
        }

        [Fact]
        public async Task PlaceOrder_NegativeQuantity_ReturnsBadRequest()
        {
            using var context = GetInMemoryDbContext();

            var controller = new OrderController(context);

            var orderDto = new CreateOrderDto
            {
                PaymentMethod = PaymentMethod.Cash,
                Items = new List<CreateOrderItemDto>
        {
            new CreateOrderItemDto
            {
                MenuItemId = 1,
                Quantity = -1
            }
        }
            };

            var result = await controller.PlaceOrder(1, orderDto);

            Assert.IsType<BadRequestObjectResult>(result.Result);
            Assert.Empty(context.Orders);
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
        public async Task UpdateOrderStatus_PreparingToReadyForPickup_UpdatesSuccessfully()
        {
            // Arrange
            using var context = GetInMemoryDbContext();

            var order = new Order
            {
                Id = 100,
                TableNumber = 1,
                PaymentMethod = PaymentMethod.Cash,
                Status = OrderStatus.Preparing,
                TotalAmount = 140,
                OrderItems = new List<OrderItem>
        {
            new OrderItem
            {
                Id = 20,
                MenuItemId = 1,
                Quantity = 2,
                UnitPrice = 70,
                SpecialInstruction = "Extra sauce"
            }
        }
            };

            context.Orders.Add(order);
            await context.SaveChangesAsync();

            var hubContext = CreateMockHubContext(
                out var tableGroupProxy,
                out var kitchenGroupProxy);

            OrderUpdateDto? capturedUpdate = null;

            tableGroupProxy
                .Setup(client => client.SendCoreAsync(
                    "ReceiveOrderUpdate",
                    It.IsAny<object[]>(),
                    It.IsAny<CancellationToken>()))
                .Callback<string, object[], CancellationToken>(
                    (method, args, token) =>
                    {
                        capturedUpdate = args[0] as OrderUpdateDto;
                    })
                .Returns(Task.CompletedTask);

            var controller = new OrderController(context, hubContext.Object);

            var statusDto = new UpdateOrderStatusDto
            {
                Status = OrderStatus.ReadyForPickup
            };

            // Act
            var result = await controller.UpdateOrderStatus(100, statusDto);

            // Assert
            Assert.IsType<OkObjectResult>(result);

            var updatedOrder = await context.Orders.FindAsync(100);
            Assert.Equal(OrderStatus.ReadyForPickup, updatedOrder!.Status);

            // Verify SignalR payload
            Assert.NotNull(capturedUpdate);
            Assert.Equal(100, capturedUpdate.Id);
            Assert.Equal(OrderStatus.ReadyForPickup, capturedUpdate.Status);
            Assert.Single(capturedUpdate.OrderItems);

            var item = capturedUpdate.OrderItems.First();

            Assert.Equal("Adobo", item.MenuItemName);
            Assert.Equal(2, item.Quantity);
            Assert.Equal("Extra sauce", item.SpecialInstruction);

            // Verify notifications
            tableGroupProxy.Verify(
                client => client.SendCoreAsync(
                    "ReceiveOrderUpdate",
                    It.Is<object[]>(args =>
                        args.Length == 1 &&
                        args[0] is OrderUpdateDto &&
                        ((OrderUpdateDto)args[0]).Id == 100),
                    default),
                Times.Once);

            kitchenGroupProxy.Verify(
                client => client.SendCoreAsync(
                    "ReceiveOrderUpdate",
                    It.Is<object[]>(args =>
                        args.Length == 1 &&
                        args[0] is OrderUpdateDto &&
                        ((OrderUpdateDto)args[0]).Id == 100),
                    default),
                Times.Once);
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
        public async Task ConfirmPayment_ValidOrderId_SendsSignalRNotification()
        {
            // Arrange
            using var context = GetInMemoryDbContext();

            var order = new Order
            {
                Id = 1,
                TableNumber = 3,
                PaymentMethod = PaymentMethod.QRCode,
                Status = OrderStatus.PendingPayment,
                TotalAmount = 140,
                OrderItems = new List<OrderItem>
        {
            new OrderItem
            {
                Id = 10,
                MenuItemId = 1,
                Quantity = 2,
                UnitPrice = 70,
                SpecialInstruction = "No spicy sauce"
            }
        }
            };

            context.Orders.Add(order);
            await context.SaveChangesAsync();

            var hubContext = CreateMockHubContext(
                out var tableGroupProxy,
                out var kitchenGroupProxy);

            OrderUpdateDto? capturedUpdate = null;

            tableGroupProxy
                .Setup(client => client.SendCoreAsync(
                    "ReceiveOrderUpdate",
                    It.IsAny<object[]>(),
                    It.IsAny<CancellationToken>()))
                .Callback<string, object[], CancellationToken>(
                    (method, args, token) =>
                    {
                        capturedUpdate = args[0] as OrderUpdateDto;
                    })
                .Returns(Task.CompletedTask);

            var controller = new OrderController(context, hubContext.Object);

            // Act
            var result = await controller.ConfirmPayment(1);

            // Assert
            Assert.IsType<OkObjectResult>(result);
            Assert.Equal(OrderStatus.Preparing, order.Status);

            Assert.NotNull(capturedUpdate);
            Assert.Equal(1, capturedUpdate.Id);
            Assert.Single(capturedUpdate.OrderItems);

            var item = capturedUpdate.OrderItems.First();

            Assert.Equal("Adobo", item.MenuItemName);
            Assert.Equal(2, item.Quantity);
            Assert.Equal("No spicy sauce", item.SpecialInstruction);

            tableGroupProxy.Verify(
                client => client.SendCoreAsync(
                    "ReceiveOrderUpdate",
                    It.Is<object[]>(args =>
                        args.Length == 1 &&
                        args[0] is OrderUpdateDto &&
                        ((OrderUpdateDto)args[0]).Id == 1),
                    default),
                Times.Once);

            kitchenGroupProxy.Verify(
                client => client.SendCoreAsync(
                    "ReceiveOrderUpdate",
                    It.Is<object[]>(args =>
                        args.Length == 1 &&
                        args[0] is OrderUpdateDto &&
                        ((OrderUpdateDto)args[0]).Id == 1),
                    default),
                Times.Once);
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
        public async Task UpdateOrderStatus_InvalidTransition_ReturnsBadRequest()
        {
            // Arrange
            var context = GetInMemoryDbContext();

            var order = new Order
            {
                Id = 101,
                TableNumber = 1,
                PaymentMethod = PaymentMethod.QRCode,
                Status = OrderStatus.PendingPayment,
                TotalAmount = 140
            };

            context.Orders.Add(order);
            await context.SaveChangesAsync();

            var controller = new OrderController(context);

            var statusDto = new UpdateOrderStatusDto
            {
                Status = OrderStatus.Completed
            };

            // Act
            var result = await controller.UpdateOrderStatus(101, statusDto);

            // Assert
            Assert.IsType<BadRequestObjectResult>(result);

            var unchangedOrder = await context.Orders.FindAsync(101);
            Assert.Equal(OrderStatus.PendingPayment, unchangedOrder!.Status);
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
        public async Task PlaceOrder_InvalidPaymentMethod_ReturnsBadRequest()
        {
            // Arrange
            using var context = GetInMemoryDbContext();
            var controller = new OrderController(context);

            var orderDto = new CreateOrderDto
            {
                PaymentMethod = (PaymentMethod)99,
                Items = new List<CreateOrderItemDto>
        {
            new()
            {
                MenuItemId = 1,
                Quantity = 1
            }
        }
            };

            // Act
            var result = await controller.PlaceOrder(1, orderDto);

            // Assert
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
        public async Task ConfirmPayment_CancelledOrder_ReturnsBadRequest()
        {
            // Arrange
            using var context = GetInMemoryDbContext();

            var order = new Order
            {
                Id = 102,
                TableNumber = 1,
                PaymentMethod = PaymentMethod.QRCode,
                Status = OrderStatus.Cancelled,
                TotalAmount = 70
            };

            context.Orders.Add(order);
            await context.SaveChangesAsync();

            var hubContext = CreateMockHubContext(
                out var tableGroupProxy,
                out var kitchenGroupProxy);

            var controller = new OrderController(context, hubContext.Object);

            // Act
            var result = await controller.ConfirmPayment(102);

            // Assert
            Assert.IsType<BadRequestObjectResult>(result);

            var unchangedOrder = await context.Orders.FindAsync(102);
            Assert.Equal(OrderStatus.Cancelled, unchangedOrder!.Status);

            tableGroupProxy.Verify(
                client => client.SendCoreAsync(
                    "ReceiveOrderUpdate",
                    It.IsAny<object[]>(),
                    default),
                Times.Never);

            kitchenGroupProxy.Verify(
                client => client.SendCoreAsync(
                    "ReceiveOrderUpdate",
                    It.IsAny<object[]>(),
                    default),
                Times.Never);
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

        [Fact]
        public async Task UpdateOrderStatus_PreparingToCancelled_UpdatesSuccessfully()
        {
            // Arrange
            using var context = GetInMemoryDbContext();

            var order = new Order
            {
                Id = 105,
                TableNumber = 1,
                PaymentMethod = PaymentMethod.Cash,
                Status = OrderStatus.Preparing,
                TotalAmount = 140,
                IsArchived = false
            };

            context.Orders.Add(order);
            await context.SaveChangesAsync();

            var controller = new OrderController(context);

            var statusDto = new UpdateOrderStatusDto
            {
                Status = OrderStatus.Cancelled
            };

            // Act
            var result = await controller.UpdateOrderStatus(105, statusDto);

            // Assert
            Assert.IsType<OkObjectResult>(result);

            var updatedOrder = await context.Orders.FindAsync(105);

            Assert.NotNull(updatedOrder);
            Assert.Equal(OrderStatus.Cancelled, updatedOrder.Status);
            Assert.False(updatedOrder.IsArchived);
        }

        [Fact]
        public async Task UpdateOrderStatus_PendingPaymentToCancelled_UpdatesSuccessfully()
        {
            // Arrange
            using var context = GetInMemoryDbContext();

            var order = new Order
            {
                Id = 106,
                TableNumber = 2,
                PaymentMethod = PaymentMethod.QRCode,
                Status = OrderStatus.PendingPayment,
                TotalAmount = 140,
                IsArchived = false
            };

            context.Orders.Add(order);
            await context.SaveChangesAsync();

            var controller = new OrderController(context);

            var statusDto = new UpdateOrderStatusDto
            {
                Status = OrderStatus.Cancelled
            };

            // Act
            var result = await controller.UpdateOrderStatus(106, statusDto);

            // Assert
            Assert.IsType<OkObjectResult>(result);

            var updatedOrder = await context.Orders.FindAsync(106);

            Assert.NotNull(updatedOrder);
            Assert.Equal(OrderStatus.Cancelled, updatedOrder.Status);
            Assert.False(updatedOrder.IsArchived);
        }

        [Fact]
        public async Task UpdateOrderStatus_ReadyForPickupToCancelled_UpdatesSuccessfully()
        {
            // Arrange
            using var context = GetInMemoryDbContext();

            var order = new Order
            {
                Id = 107,
                TableNumber = 3,
                PaymentMethod = PaymentMethod.Cash,
                Status = OrderStatus.ReadyForPickup,
                TotalAmount = 140,
                IsArchived = false
            };

            context.Orders.Add(order);
            await context.SaveChangesAsync();

            var controller = new OrderController(context);

            var statusDto = new UpdateOrderStatusDto
            {
                Status = OrderStatus.Cancelled
            };

            // Act
            var result = await controller.UpdateOrderStatus(107, statusDto);

            // Assert
            Assert.IsType<OkObjectResult>(result);

            var updatedOrder = await context.Orders.FindAsync(107);

            Assert.NotNull(updatedOrder);
            Assert.Equal(OrderStatus.Cancelled, updatedOrder.Status);
            Assert.False(updatedOrder.IsArchived);
        }

        [Fact]
        public async Task UpdateOrderStatus_CompletedToCancelled_ReturnsBadRequest()
        {
            // Arrange
            using var context = GetInMemoryDbContext();

            var order = new Order
            {
                Id = 108,
                TableNumber = 3,
                PaymentMethod = PaymentMethod.Cash,
                Status = OrderStatus.Completed,
                TotalAmount = 140,
                IsArchived = false
            };

            context.Orders.Add(order);
            await context.SaveChangesAsync();

            var controller = new OrderController(context);

            var statusDto = new UpdateOrderStatusDto
            {
                Status = OrderStatus.Cancelled
            };

            // Act
            var result = await controller.UpdateOrderStatus(108, statusDto);

            // Assert
            Assert.IsType<BadRequestObjectResult>(result);

            var unchangedOrder = await context.Orders.FindAsync(108);

            Assert.NotNull(unchangedOrder);
            Assert.Equal(OrderStatus.Completed, unchangedOrder.Status);
            Assert.False(unchangedOrder.IsArchived);
        }

        [Fact]
        public async Task UpdateOrderStatus_PreparingToCancelled_SendsSignalRNotification()
        {
            // Arrange
            using var context = GetInMemoryDbContext();

            var order = new Order
            {
                Id = 109,
                TableNumber = 4,
                PaymentMethod = PaymentMethod.Cash,
                Status = OrderStatus.Preparing,
                TotalAmount = 140,
                IsArchived = false
            };

            context.Orders.Add(order);
            await context.SaveChangesAsync();

            var hubContext = CreateMockHubContext(
                out var tableGroupProxy,
                out var kitchenGroupProxy);

            OrderUpdateDto? capturedUpdate = null;

            tableGroupProxy
                .Setup(client => client.SendCoreAsync(
                    "ReceiveOrderUpdate",
                    It.IsAny<object[]>(),
                    It.IsAny<CancellationToken>()))
                .Callback<string, object[], CancellationToken>(
                    (method, args, token) =>
                    {
                        capturedUpdate = args[0] as OrderUpdateDto;
                    })
                .Returns(Task.CompletedTask);

            var controller = new OrderController(context, hubContext.Object);

            var statusDto = new UpdateOrderStatusDto
            {
                Status = OrderStatus.Cancelled
            };

            // Act
            var result = await controller.UpdateOrderStatus(109, statusDto);

            // Assert
            Assert.IsType<OkObjectResult>(result);

            Assert.NotNull(capturedUpdate);
            Assert.Equal(109, capturedUpdate.Id);
            Assert.Equal(OrderStatus.Cancelled, capturedUpdate.Status);

            tableGroupProxy.Verify(client => client.SendCoreAsync(
                "ReceiveOrderUpdate",
                It.IsAny<object[]>(),
                It.IsAny<CancellationToken>()),
                Times.Once);

            kitchenGroupProxy.Verify(client => client.SendCoreAsync(
                "ReceiveOrderUpdate",
                It.IsAny<object[]>(),
                It.IsAny<CancellationToken>()),
                Times.Once);
        }
    }
}