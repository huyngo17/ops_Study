var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllersWithViews();

var app = builder.Build();

app.UseExceptionHandler("/Home/Error");

app.UseRouting();

app.UseAuthorization();

app.MapStaticAssets();

app.MapGet("/health", () => Results.Ok(new
{
    status = "healthy",
    app = "WebApplication1",
    timestamp = DateTimeOffset.UtcNow
}));

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}")
    .WithStaticAssets();


app.Run();
