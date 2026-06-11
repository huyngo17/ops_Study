using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Diagnostics;
using System.Diagnostics;
using WebApplication1.Models;

namespace WebApplication1.Controllers
{
    public class HomeController : Controller
    {
        private readonly ILogger<HomeController> _logger;

        public HomeController(ILogger<HomeController> logger)
        {
            _logger = logger;
        }

        public IActionResult Index()
        {
            _logger.LogInformation("Home page requested from {RemoteIp}", HttpContext.Connection.RemoteIpAddress);
            return View();
        }

        public IActionResult Log()
        {
            _logger.LogInformation("Manual log endpoint called at {Timestamp}", DateTimeOffset.UtcNow);
            return Content("Log written. Check container logs with: docker logs <container-name>");
        }

        public IActionResult Boom()
        {
            _logger.LogWarning("Boom endpoint called. Throwing a demo exception on purpose.");
            throw new InvalidOperationException("Demo exception from /Home/Boom. The global exception handler should catch this.");
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            var exceptionFeature = HttpContext.Features.Get<IExceptionHandlerPathFeature>();

            if (exceptionFeature?.Error is not null)
            {
                _logger.LogError(
                    exceptionFeature.Error,
                    "Global exception handler caught an error from {Path}",
                    exceptionFeature.Path);
            }

            return View(new ErrorViewModel
            {
                RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier
            });
        }
    }
}
