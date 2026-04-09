using BlogLab.Identity;
using BlogLab.Models.Account;
using BlogLab.Models.Settings;
using BlogLab.Repository;
using BlogLab.Services;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace BlogLab.Web.Extensions
{
  public static class ServiceCollectionExtensions
  {
    public static IServiceCollection AddBlogLabServices(this IServiceCollection services, IConfiguration configuration)
    {
      services.Configure<CloudinaryOptions>(configuration.GetSection("CloudinaryOptions"));

      services.AddScoped<IAdminUserDeletionService, AdminUserDeletionService>();
      services.AddScoped<ITokenService, TokenService>();
      services.AddScoped<IPhotoService, PhotoService>();

      services.AddScoped<IBlogRepository, BlogRepository>();
      services.AddScoped<IBlogCommentRepository, BlogCommentRepository>();
      services.AddScoped<IAccountRepository, AccountRepository>();
      services.AddScoped<IPhotoRepository, PhotoRepository>();

      services.AddIdentityCore<ApplicationUserIdentity>(options =>
          {
            options.Password.RequireNonAlphanumeric = false;
          })
          .AddUserStore<UserStore>()
          .AddDefaultTokenProviders()
          .AddSignInManager<SignInManager<ApplicationUserIdentity>>();

      return services;
    }
  }
}