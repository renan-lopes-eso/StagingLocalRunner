using Microsoft.EntityFrameworkCore;
using StagingApp.Data;

var builder = WebApplication.CreateBuilder(args);

builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();

var connectionString = builder.Configuration.GetConnectionString("DefaultConnection")
    ?? Environment.GetEnvironmentVariable("DATABASE_CONNECTION_STRING");

if (string.IsNullOrEmpty(connectionString))
{
    throw new InvalidOperationException("Connection string not configured");
}

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseMySql(connectionString, ServerVersion.AutoDetect(connectionString)));

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() {
        Title = "Staging API",
        Version = "v1",
        Description = $"Branch: {Environment.GetEnvironmentVariable("BRANCH_NAME") ?? "unknown"}"
    });
});

builder.Services.AddHealthChecks()
    .AddDbContextCheck<AppDbContext>();

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI();

app.UseRouting();
app.UseAuthorization();
app.MapControllers();
app.MapHealthChecks("/health");

app.MapGet("/info", () => new
{
    Environment = app.Environment.EnvironmentName,
    Branch = Environment.GetEnvironmentVariable("BRANCH_NAME"),
    CommitSha = Environment.GetEnvironmentVariable("COMMIT_SHA"),
    DeployedAt = Environment.GetEnvironmentVariable("DEPLOYED_AT"),
    Version = Environment.GetEnvironmentVariable("APP_VERSION") ?? "1.0.0"
});

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    try
    {
        db.Database.Migrate();
        app.Logger.LogInformation("Database migrations applied successfully");
    }
    catch (Exception ex)
    {
        app.Logger.LogError(ex, "Error applying migrations");
        throw;
    }
}

app.Logger.LogInformation("Application started on branch: {Branch}",
    Environment.GetEnvironmentVariable("BRANCH_NAME"));

app.Run();
