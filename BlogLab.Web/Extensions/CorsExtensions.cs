using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace BlogLab.Web.Extensions
{
  public static class CorsExtensions
  {
    public static IServiceCollection AddBlogLabCors(this IServiceCollection services)
    {
      services.AddCors();

      return services;
    }

    public static WebApplication UseBlogLabCors(this WebApplication app)
    {
      if (app.Environment.IsDevelopment())
      {
        app.UseCors(policy => policy.AllowAnyHeader().AllowAnyMethod().AllowAnyOrigin());
      }
      else
      {
        app.UseCors();
      }

      return app;
    }
  }
}