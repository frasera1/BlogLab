using System.Threading.Tasks;
using BlogLab.Models.Blog;
using BlogLab.Repository;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace BlogLab.Web.Extensions
{
  public static class BlogEndpointRouteBuilderExtensions
  {
    public static IEndpointRouteBuilder MapBlogEndpoints(this IEndpointRouteBuilder endpoints)
    {
      var group = endpoints.MapGroup("/api/blog")
          .WithTags("Blog");

      group.MapPost("/", CreateAsync)
        .WithName("Blog_Create")
          .RequireAuthorization();
      group.MapGet("/", GetAllAsync)
        .WithName("Blog_GetAll");
      group.MapGet("/{blogId:int}", GetAsync)
        .WithName("Blog_Get");
      group.MapGet("/user/{applicationUserId:int}", GetByApplicationUserIdAsync)
        .WithName("Blog_GetByApplicationUserId");
      group.MapGet("/famous", GetAllFamousAsync)
        .WithName("Blog_GetAllFamous");
      group.MapPost("/{blogId:int}/like/toggle", ToggleLikeAsync)
        .WithName("Blog_ToggleLike")
          .RequireAuthorization();
      group.MapDelete("/{blogId:int}", DeleteAsync)
        .WithName("Blog_Delete")
          .RequireAuthorization();

      return endpoints;
    }

    private static async Task<IResult> CreateAsync(
        BlogCreate blogCreate,
        HttpContext httpContext,
        IPhotoRepository photoRepository,
        IBlogRepository blogRepository)
    {
      var validationProblem = blogCreate.ValidateRequest();
      if (validationProblem is not null)
      {
        return validationProblem;
      }

      var applicationUserId = httpContext.User.GetRequiredApplicationUserId();

      if (blogCreate.PhotoId.HasValue)
      {
        var photo = await photoRepository.GetAsync(blogCreate.PhotoId.Value);
        if (photo.ApplicationUserId != applicationUserId)
        {
          return TypedResults.BadRequest("You did not upload the photo.");
        }
      }

      var blog = await blogRepository.UpsertAsync(blogCreate, applicationUserId);

      return TypedResults.Ok(blog);
    }

    private static async Task<IResult> GetAllAsync(
        HttpContext httpContext,
        IBlogRepository blogRepository,
        int page = 1,
        int pageSize = 6)
    {
      var blogPaging = new BlogPaging
      {
        Page = page,
        PageSize = pageSize
      };

      var currentApplicationUserId = httpContext.User.TryGetApplicationUserId();
      var blogs = await blogRepository.GetAllAsync(blogPaging, currentApplicationUserId);

      return TypedResults.Ok(blogs);
    }

    private static async Task<IResult> GetAsync(
        int blogId,
        HttpContext httpContext,
        IBlogRepository blogRepository)
    {
      var currentApplicationUserId = httpContext.User.TryGetApplicationUserId();
      var blog = await blogRepository.GetAsync(blogId, currentApplicationUserId);

      return blog is null ? TypedResults.NoContent() : TypedResults.Ok(blog);
    }

    private static async Task<IResult> GetByApplicationUserIdAsync(
        int applicationUserId,
        HttpContext httpContext,
        IBlogRepository blogRepository)
    {
      var currentApplicationUserId = httpContext.User.TryGetApplicationUserId();
      var blogs = await blogRepository.GetAllByUserIdAsync(applicationUserId, currentApplicationUserId);

      return TypedResults.Ok(blogs);
    }

    private static async Task<IResult> GetAllFamousAsync(
        HttpContext httpContext,
        IBlogRepository blogRepository)
    {
      var currentApplicationUserId = httpContext.User.TryGetApplicationUserId();
      var blogs = await blogRepository.GetAllFamousAsync(currentApplicationUserId);

      return TypedResults.Ok(blogs);
    }

    private static async Task<IResult> ToggleLikeAsync(
        int blogId,
        HttpContext httpContext,
        IBlogRepository blogRepository)
    {
      var applicationUserId = httpContext.User.GetRequiredApplicationUserId();
      var foundBlog = await blogRepository.GetAsync(blogId, applicationUserId);

      if (foundBlog is null)
      {
        return TypedResults.BadRequest("Blog does not exist.");
      }

      var blogLike = await blogRepository.ToggleLikeAsync(blogId, applicationUserId);

      return TypedResults.Ok(blogLike);
    }

    private static async Task<IResult> DeleteAsync(
        int blogId,
        HttpContext httpContext,
        IBlogRepository blogRepository)
    {
      var applicationUserId = httpContext.User.GetRequiredApplicationUserId();
      var foundBlog = await blogRepository.GetAsync(blogId);

      if (foundBlog is null)
      {
        return TypedResults.BadRequest("Blog does not exist.");
      }

      if (foundBlog.ApplicationUserId == applicationUserId || httpContext.User.IsAdmin())
      {
        var affectedRows = await blogRepository.DeleteAsync(blogId);
        return TypedResults.Ok(affectedRows);
      }

      return TypedResults.BadRequest("You didn't create this blog.");
    }
  }
}