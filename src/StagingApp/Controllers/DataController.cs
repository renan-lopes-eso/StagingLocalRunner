using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StagingApp.Data;
using StagingApp.Models;

namespace StagingApp.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DataController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly ILogger<DataController> _logger;

    public DataController(AppDbContext context, ILogger<DataController> logger)
    {
        _context = context;
        _logger = logger;
    }

    [HttpGet]
    public async Task<ActionResult<IEnumerable<SampleData>>> GetAll()
    {
        return await _context.SampleData.OrderByDescending(x => x.CreatedAt).ToListAsync();
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<SampleData>> Get(int id)
    {
        var data = await _context.SampleData.FindAsync(id);
        if (data == null)
            return NotFound();

        return data;
    }

    [HttpPost]
    public async Task<ActionResult<SampleData>> Create(SampleData data)
    {
        data.CreatedAt = DateTime.UtcNow;
        _context.SampleData.Add(data);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Created record {Id} on branch {Branch}",
            data.Id, Environment.GetEnvironmentVariable("BRANCH_NAME"));

        return CreatedAtAction(nameof(Get), new { id = data.Id }, data);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(int id, SampleData data)
    {
        if (id != data.Id)
            return BadRequest();

        data.UpdatedAt = DateTime.UtcNow;
        _context.Entry(data).State = EntityState.Modified;

        try
        {
            await _context.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException)
        {
            if (!await _context.SampleData.AnyAsync(e => e.Id == id))
                return NotFound();
            throw;
        }

        return NoContent();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        var data = await _context.SampleData.FindAsync(id);
        if (data == null)
            return NotFound();

        _context.SampleData.Remove(data);
        await _context.SaveChangesAsync();

        return NoContent();
    }
}
