using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StagingApp.Data;

namespace StagingApp.Controllers;

[ApiController]
[Route("api/[controller]")]
public class HealthController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly ILogger<HealthController> _logger;

    public HealthController(AppDbContext context, ILogger<HealthController> logger)
    {
        _context = context;
        _logger = logger;
    }

    [HttpGet]
    public async Task<IActionResult> Get()
    {
        try
        {
            await _context.Database.CanConnectAsync();

            return Ok(new
            {
                Status = "Healthy",
                Timestamp = DateTime.UtcNow,
                Branch = Environment.GetEnvironmentVariable("BRANCH_NAME") ?? "unknown",
                Database = "Connected"
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Health check failed");
            return StatusCode(503, new
            {
                Status = "Unhealthy",
                Error = ex.Message
            });
        }
    }
}
