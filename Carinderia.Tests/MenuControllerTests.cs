using Carinderia.API.Controllers;
using Carinderia.API.Data;
using Carinderia.API.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Carinderia.Tests;

public class MenuControllerTests
{
    private AppDbContext GetInMemoryDbContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        var context = new AppDbContext(options);

        context.Categories.AddRange(
            new Category
            {
                Id = 1,
                Name = "Sabaw",
                MenuItems = new List<MenuItem>
                {
                    new MenuItem { Id = 1, Name = "Sinigang", Price = 80, IsAvailableToday = true, CategoryId = 1 },
                    new MenuItem { Id = 2, Name = "Bulalo", Price = 120, IsAvailableToday = false, CategoryId = 1 }
                }
            },
            new Category
            {
                Id = 2,
                Name = "Ulam",
                MenuItems = new List<MenuItem>
                {
                    new MenuItem
                    {
                        Id = 3,
                        Name = "Adobo",
                        Price = 100,
                        IsAvailableToday = false,
                        CategoryId = 2
                    }
                }
            }
        );

        context.SaveChanges();
        return context;
    }

    [Fact]
    public async Task GetActiveMenu_ReturnsOnlyAvailableMenuItems()
    {
        using var context = GetInMemoryDbContext();
        var controller = new MenuController(context);

        var result = await controller.GetActiveMenu();

        var actionResult = Assert.IsType<OkObjectResult>(result.Result);
        var categories = Assert.IsAssignableFrom<IEnumerable<Category>>(actionResult.Value);

        var sabawCategory = categories.First(c => c.Id == 1);
        Assert.Single(sabawCategory.MenuItems);
        Assert.Equal("Sinigang", sabawCategory.MenuItems.First().Name);
    }

    [Fact]
    public async Task GetActiveMenu_ReturnsAllCategories()
    {
        using var context = GetInMemoryDbContext();
        var controller = new MenuController(context);

        var result = await controller.GetActiveMenu();

        var actionResult = Assert.IsType<OkObjectResult>(result.Result);
        var categories = Assert.IsAssignableFrom<IEnumerable<Category>>(
            actionResult.Value);

        Assert.Equal(2, categories.Count());
    }

    [Fact]
    public async Task GetActiveMenu_KeepsCategoriesWithNoAvailableItems()
    {
        using var context = GetInMemoryDbContext();
        var controller = new MenuController(context);

        var result = await controller.GetActiveMenu();

        var actionResult = Assert.IsType<OkObjectResult>(result.Result);
        var categories = Assert.IsAssignableFrom<IEnumerable<Category>>(
            actionResult.Value);

        var ulamCategory = categories.First(c => c.Id == 2);

        Assert.Empty(ulamCategory.MenuItems);
    }

    [Fact]
    public async Task GetActiveMenu_FiltersUnavailableItemsAcrossCategories()
    {
        using var context = GetInMemoryDbContext();
        var controller = new MenuController(context);

        var result = await controller.GetActiveMenu();

        var actionResult = Assert.IsType<OkObjectResult>(result.Result);
        var categories = Assert.IsAssignableFrom<IEnumerable<Category>>(
            actionResult.Value);

        Assert.All(
            categories,
            category => Assert.All(
                category.MenuItems,
                item => Assert.True(item.IsAvailableToday)));
    }

    [Fact]
    public async Task GetActiveMenu_NoCategories_ReturnsEmptyList()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        using var context = new AppDbContext(options);
        var controller = new MenuController(context);

        var result = await controller.GetActiveMenu();

        var actionResult = Assert.IsType<OkObjectResult>(result.Result);
        var categories = Assert.IsAssignableFrom<IEnumerable<Category>>(
            actionResult.Value);

        Assert.Empty(categories);
    }
}
