using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using BlogLab.Models.Account;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;

namespace BlogLab.Web.Extensions
{
  public static class CurrentUserExtensions
  {
    public static int? TryGetApplicationUserId(this ClaimsPrincipal user)
    {
      var applicationUserIdClaim = user?.Claims?.FirstOrDefault(claim => claim.Type == JwtRegisteredClaimNames.NameId)?.Value;

      if (int.TryParse(applicationUserIdClaim, out var applicationUserId))
      {
        return applicationUserId;
      }

      return null;
    }

    public static int GetRequiredApplicationUserId(this ClaimsPrincipal user)
    {
      return int.Parse(user.Claims.First(claim => claim.Type == JwtRegisteredClaimNames.NameId).Value);
    }

    public static bool IsAdmin(this ClaimsPrincipal user)
    {
      return user?.IsInRole("Admin") ?? false;
    }

    public static async Task<ApplicationUserIdentity> GetCurrentApplicationUserAsync(
        this HttpContext httpContext,
        UserManager<ApplicationUserIdentity> userManager)
    {
      var applicationUserId = httpContext.User.TryGetApplicationUserId();
      if (!applicationUserId.HasValue)
      {
        return null;
      }

      return await userManager.FindByIdAsync(applicationUserId.Value.ToString());
    }
  }
}