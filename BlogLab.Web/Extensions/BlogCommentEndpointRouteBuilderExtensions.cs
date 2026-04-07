using System.Threading.Tasks;
using BlogLab.Models.BlogComment;
using BlogLab.Repository;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace BlogLab.Web.Extensions
{
  public static class BlogCommentEndpointRouteBuilderExtensions
  {
    public static IEndpointRouteBuilder MapBlogCommentEndpoints(this IEndpointRouteBuilder endpoints)
    {
      var group = endpoints.MapGroup("/api/blogcomment")
          .WithTags("BlogComment");

      group.MapPost("/", CreateAsync)
        .WithName("BlogComment_Create")
          .RequireAuthorization();
      group.MapGet("/{blogId:int}", GetAllAsync)
        .WithName("BlogComment_GetAll");
      group.MapDelete("/{blogCommentId:int}", DeleteAsync)
        .WithName("BlogComment_Delete")
          .RequireAuthorization();

      return endpoints;
    }

    private static async Task<IResult> CreateAsync(
        BlogCommentCreate blogCommentCreate,
        HttpContext httpContext,
        IBlogCommentRepository blogCommentRepository)
    {
      var validationProblem = blogCommentCreate.ValidateRequest();
      if (validationProblem is not null)
      {
        return validationProblem;
      }

      var applicationUserId = httpContext.User.GetRequiredApplicationUserId();
      var createdBlogComment = await blogCommentRepository.UpsertAsync(blogCommentCreate, applicationUserId);

      return TypedResults.Ok(createdBlogComment);
    }

    private static async Task<IResult> GetAllAsync(
        int blogId,
        IBlogCommentRepository blogCommentRepository)
    {
      var blogComments = await blogCommentRepository.GetAllAsync(blogId);

      return TypedResults.Ok(blogComments);
    }

    private static async Task<IResult> DeleteAsync(
        int blogCommentId,
        HttpContext httpContext,
        IBlogCommentRepository blogCommentRepository)
    {
      var applicationUserId = httpContext.User.GetRequiredApplicationUserId();
      var foundBlogComment = await blogCommentRepository.GetAsync(blogCommentId);

      if (foundBlogComment is null)
      {
        return TypedResults.BadRequest("Blog comment does not exist.");
      }

      if (foundBlogComment.ApplicationUserId == applicationUserId)
      {
        var affectedRows = await blogCommentRepository.DeleteAsync(blogCommentId);
        return TypedResults.Ok(affectedRows);
      }

      return TypedResults.BadRequest("This comment wasn't created by the current user.");
    }
  }
}