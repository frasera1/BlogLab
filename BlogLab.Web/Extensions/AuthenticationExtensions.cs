using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using System;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace BlogLab.Web.Extensions
{
  public static class AuthenticationExtensions
  {
    public static IServiceCollection AddBlogLabAuthentication(this IServiceCollection services, IConfiguration configuration)
    {
      JwtSecurityTokenHandler.DefaultInboundClaimTypeMap.Clear();

      services.AddAuthorization();

      services.AddAuthentication(options =>
          {
            options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
            options.DefaultScheme = JwtBearerDefaults.AuthenticationScheme;
            options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
          })
          .AddJwtBearer(options =>
          {
            options.MapInboundClaims = false;
            options.RequireHttpsMetadata = false;
            options.SaveToken = true;
            options.TokenValidationParameters = new TokenValidationParameters
            {
              ValidateIssuer = true,
              ValidateAudience = true,
              ValidateLifetime = true,
              ValidateIssuerSigningKey = true,
              ValidIssuer = configuration["Jwt:Issuer"],
              ValidAudience = configuration["Jwt:Issuer"],
              IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(configuration["Jwt:Key"])),
              NameClaimType = JwtRegisteredClaimNames.UniqueName,
              RoleClaimType = ClaimTypes.Role,
              ClockSkew = TimeSpan.Zero
            };
          });

      return services;
    }
  }
}