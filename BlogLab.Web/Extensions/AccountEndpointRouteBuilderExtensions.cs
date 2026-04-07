using System.Threading.Tasks;
using BlogLab.Models.Account;
using BlogLab.Services;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Routing;

namespace BlogLab.Web.Extensions
{
  public static class AccountEndpointRouteBuilderExtensions
  {
    public static IEndpointRouteBuilder MapAccountEndpoints(this IEndpointRouteBuilder endpoints)
    {
      var group = endpoints.MapGroup("/api/account")
          .WithTags("Account");

      group.MapPost("/register", RegisterAsync)
        .WithName("Account_Register");
      group.MapPost("/login", LoginAsync)
        .WithName("Account_Login");

      return endpoints;
    }

    private static async Task<IResult> RegisterAsync(
        ApplicationUserCreate applicationUserCreate,
        ITokenService tokenService,
        UserManager<ApplicationUserIdentity> userManager)
    {
      var validationProblem = applicationUserCreate.ValidateRequest();
      if (validationProblem is not null)
      {
        return validationProblem;
      }

      var applicationUserIdentity = new ApplicationUserIdentity
      {
        Username = applicationUserCreate.Username,
        Email = applicationUserCreate.Email,
        Fullname = applicationUserCreate.Fullname,
        IsAdmin = false
      };

      var result = await userManager.CreateAsync(applicationUserIdentity, applicationUserCreate.Password);

      if (result.Succeeded)
      {
        applicationUserIdentity = await userManager.FindByNameAsync(applicationUserCreate.Username);

        return TypedResults.Ok(CreateApplicationUser(applicationUserIdentity, tokenService));
      }

      return TypedResults.BadRequest(result.Errors);
    }

    private static async Task<IResult> LoginAsync(
        ApplicationUserLogin applicationUserLogin,
        ITokenService tokenService,
        UserManager<ApplicationUserIdentity> userManager,
        SignInManager<ApplicationUserIdentity> signInManager)
    {
      var validationProblem = applicationUserLogin.ValidateRequest();
      if (validationProblem is not null)
      {
        return validationProblem;
      }

      var applicationUserIdentity = await userManager.FindByNameAsync(applicationUserLogin.Username);

      if (applicationUserIdentity is not null)
      {
        var result = await signInManager.CheckPasswordSignInAsync(
            applicationUserIdentity,
            applicationUserLogin.Password,
            false);

        if (result.Succeeded)
        {
          return TypedResults.Ok(CreateApplicationUser(applicationUserIdentity, tokenService));
        }
      }

      return TypedResults.BadRequest("Invalid login attempt.");
    }

    private static ApplicationUser CreateApplicationUser(
        ApplicationUserIdentity applicationUserIdentity,
        ITokenService tokenService)
    {
      return new ApplicationUser
      {
        ApplicationUserId = applicationUserIdentity.ApplicationUserId,
        Username = applicationUserIdentity.Username,
        Email = applicationUserIdentity.Email,
        Fullname = applicationUserIdentity.Fullname,
        IsAdmin = applicationUserIdentity.IsAdmin,
        Token = tokenService.CreateToken(applicationUserIdentity)
      };
    }
  }
}