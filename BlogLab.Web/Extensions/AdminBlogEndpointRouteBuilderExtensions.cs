using System.Threading.Tasks;
using BlogLab.Models.Blog;
using BlogLab.Repository;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace BlogLab.Web.Extensions
{
  public static class AdminBlogEndpointRouteBuilderExtensions
  {
    public static IEndpointRouteBuilder MapAdminBlogEndpoints(this IEndpointRouteBuilder endpoints)
    {
      var group = endpoints.MapGroup("/api/admin/blog")
          .WithTags("AdminBlog");

      group.MapGet("/", GetAllAsync)
        .WithName("AdminBlog_GetAll")
          .RequireAuthorization();

      return endpoints;
    }

    private static async Task<IResult> GetAllAsync(
        HttpContext httpContext,
        IBlogRepository blogRepository,
        int Page = 1,
        int PageSize = 6)
    {
      if (!httpContext.User.IsAdmin())
      {
        return TypedResults.Text("You must be an admin to manage blogs.", statusCode: StatusCodes.Status403Forbidden);
      }

      var blogPaging = new BlogPaging
      {
        Page = Page,
        PageSize = PageSize
      };

      var currentApplicationUserId = httpContext.User.TryGetApplicationUserId();
      var blogs = await blogRepository.GetAllAsync(blogPaging, currentApplicationUserId);

      return TypedResults.Ok(blogs);
    }
  }
}