using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Security.Claims;

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
  }
}