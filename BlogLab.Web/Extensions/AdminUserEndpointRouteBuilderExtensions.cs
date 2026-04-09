using System;
using System.Threading.Tasks;
using BlogLab.Models.Account;
using BlogLab.Repository;
using BlogLab.Services;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Routing;

namespace BlogLab.Web.Extensions
{
  public static class AdminUserEndpointRouteBuilderExtensions
  {
    public static IEndpointRouteBuilder MapAdminUserEndpoints(this IEndpointRouteBuilder endpoints)
    {
      var group = endpoints.MapGroup("/api/admin/users")
          .WithTags("AdminUsers");

      group.MapGet("/", GetAllAsync)
        .WithName("AdminUsers_GetAll")
        .RequireAuthorization();
      group.MapDelete("/{applicationUserId:int}", DeleteAsync)
        .WithName("AdminUsers_Delete")
        .RequireAuthorization();
      group.MapPatch("/{applicationUserId:int}/role", UpdateRoleAsync)
        .WithName("AdminUsers_UpdateRole")
        .RequireAuthorization();

      return endpoints;
    }

    private static async Task<IResult> GetAllAsync(
        HttpContext httpContext,
        IAccountRepository accountRepository,
        UserManager<ApplicationUserIdentity> userManager,
        int Page = 1,
        int PageSize = 10)
    {
      var currentUser = await httpContext.GetCurrentApplicationUserAsync(userManager);
      if (currentUser is null)
      {
        return TypedResults.Unauthorized();
      }

      if (!currentUser.IsAdmin)
      {
        return TypedResults.Text("You must be an admin to manage users.", statusCode: StatusCodes.Status403Forbidden);
      }

      var users = await accountRepository.GetAllAsync(Page, PageSize, httpContext.RequestAborted);

      return TypedResults.Ok(users);
    }

    private static async Task<IResult> DeleteAsync(
        int applicationUserId,
        HttpContext httpContext,
        IAdminUserDeletionService adminUserDeletionService)
    {
      var requestingApplicationUserId = httpContext.User.TryGetApplicationUserId();
      if (!requestingApplicationUserId.HasValue)
      {
        return TypedResults.Unauthorized();
      }

      try
      {
        var result = await adminUserDeletionService.DeleteAsync(
            applicationUserId,
            requestingApplicationUserId.Value,
            httpContext.RequestAborted);

        return TypedResults.Ok(result);
      }
      catch (UnauthorizedAccessException ex)
      {
        return TypedResults.Text(ex.Message, statusCode: StatusCodes.Status403Forbidden);
      }
      catch (InvalidOperationException ex)
      {
        return TypedResults.BadRequest(ex.Message);
      }
    }

    private static async Task<IResult> UpdateRoleAsync(
        int applicationUserId,
        ApplicationUserRoleUpdate applicationUserRoleUpdate,
        HttpContext httpContext,
        IAccountRepository accountRepository,
        UserManager<ApplicationUserIdentity> userManager)
    {
      var validationProblem = applicationUserRoleUpdate.ValidateRequest();
      if (validationProblem is not null)
      {
        return validationProblem;
      }

      var currentUser = await httpContext.GetCurrentApplicationUserAsync(userManager);
      if (currentUser is null)
      {
        return TypedResults.Unauthorized();
      }

      if (!currentUser.IsAdmin)
      {
        return TypedResults.Text("You must be an admin to manage users.", statusCode: StatusCodes.Status403Forbidden);
      }

      var targetUser = await userManager.FindByIdAsync(applicationUserId.ToString());
      if (targetUser is null)
      {
        return TypedResults.BadRequest("User does not exist.");
      }

      var shouldBeAdmin = applicationUserRoleUpdate.IsAdmin.GetValueOrDefault();
      if (targetUser.IsAdmin == shouldBeAdmin)
      {
        return TypedResults.Ok(CreateAdminUserSummary(targetUser));
      }

      if (targetUser.IsAdmin && !shouldBeAdmin)
      {
        var adminCount = await accountRepository.CountAdminsAsync(httpContext.RequestAborted);
        if (adminCount <= 1)
        {
          return TypedResults.BadRequest("You cannot remove the last remaining admin.");
        }
      }

      targetUser.IsAdmin = shouldBeAdmin;

      var result = await userManager.UpdateAsync(targetUser);
      if (!result.Succeeded)
      {
        return TypedResults.BadRequest(result.Errors);
      }

      var updatedUser = await userManager.FindByIdAsync(applicationUserId.ToString());
      if (updatedUser is null)
      {
        return TypedResults.BadRequest("User does not exist.");
      }

      return TypedResults.Ok(CreateAdminUserSummary(updatedUser));
    }

    private static AdminUserSummary CreateAdminUserSummary(ApplicationUserIdentity user)
    {
      return new AdminUserSummary
      {
        ApplicationUserId = user.ApplicationUserId,
        Username = user.Username,
        Fullname = user.Fullname,
        Email = user.Email,
        IsAdmin = user.IsAdmin
      };
    }
  }
}