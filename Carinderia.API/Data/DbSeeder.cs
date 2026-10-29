using Carinderia.API.Models;

namespace Carinderia.API.Data
{
    public static class DbSeeder
    {
        public static void Seed(AppDbContext context)
        {
            if (context.Categories.Any()) return;

            var categories = new List<Category>
            {
                new Category
                {
                    Name = "Sabaw",
                    MenuItems = new List<MenuItem>
                    {
                        new MenuItem { Name = "Sinigang na Baboy", Description = "Sour tamarind broth with pork belly", Price = 120.00m, IsAvailableToday = true},
                        new MenuItem { Name = "Bulalo", Description = "Beef marrow stew", Price = 150m, IsAvailableToday = true}
                    }
                },
                new Category
                {
                    Name = "Prito",
                    MenuItems = new List<MenuItem>
                    {
                        new MenuItem { Name = "Adobong Manok", Description = "Classic soy-vinegar chicken", Price = 90.00m, IsAvailableToday = true},
                        new MenuItem { Name = "Fried Chicken", Description = "Crispy golden fried chicken", Price = 80.00m, IsAvailableToday = true }
                }
                },
                new Category
                {
                    Name = "Kanin",
                    MenuItems = new List<MenuItem>
                    {
                        new MenuItem { Name = "Extra Rice", Description = "Steamed white rice", Price = 15.00m, IsAvailableToday = true }
                    }
                }
            };

            context.Categories.AddRange(categories);

            // Seed default tables
            if (!context.TableSessions.Any())
            {
                context.TableSessions.AddRange(
                    new TableSession { TableNumber = 1 },
                    new TableSession { TableNumber = 2 },
                    new TableSession { TableNumber = 3 },
                    new TableSession { TableNumber = 4 }
                );
            }

            context.SaveChanges();
        }
    }
}