using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.OpenApi;

namespace BlogLab.Web.Extensions
{
  public static class OpenApiExtensions
  {
    public static IServiceCollection AddBlogLabOpenApi(this IServiceCollection services)
    {
      services.AddEndpointsApiExplorer();
      services.AddSwaggerGen(options =>
      {
        options.SwaggerDoc("v1", new OpenApiInfo
        {
          Title = "BlogLab API",
          Version = "v1"
        });
      });

      return services;
    }

    public static WebApplication UseBlogLabOpenApi(this WebApplication app)
    {
      if (app.Environment.IsDevelopment())
      {
        app.UseSwagger();
        app.UseSwaggerUI(options =>
        {
          options.SwaggerEndpoint("/swagger/v1/swagger.json", "BlogLab API v1");
        });
      }

      return app;
    }
  }
}