using Dapper;
using Microsoft.AspNetCore.Mvc;
using MySql.Data.MySqlClient;

namespace ESO.TestRunner.Controllers
{
    public class HomeController : Controller
    {
        public async Task<IActionResult> Index([FromServices]IConfiguration configuration, CancellationToken ct)
        {
            var connectionString = configuration["ESO_CORE_CONNECTION"]
                ?? throw new InvalidOperationException("ConnectionString connection string not found");

            using var connection = new MySqlConnection(connectionString);
            await connection.OpenAsync(ct);

            var sql = "SELECT Id_CBO AS Id, Code, Name, CBOType AS Type FROM cbos WHERE IsDeleted = 0 LIMIT 100";

            var items = await connection.QueryAsync<CboDto>(
                new CommandDefinition(
                    commandText: sql,
                    cancellationToken: ct));

            var result = items.AsList();

            return View(result);
        }
    }

    public sealed record CboDto(
    int Id,
    string? Code,
    string? Name,
    string? Type);
}