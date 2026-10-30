using Carinderia.API.Controllers;
using Carinderia.API.Data;
using Carinderia.API.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Carinderia.Tests;

public class UnitTest1
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
}
