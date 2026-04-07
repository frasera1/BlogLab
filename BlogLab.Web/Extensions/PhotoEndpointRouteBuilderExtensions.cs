using System.Linq;
using System.Threading.Tasks;
using BlogLab.Models.Photo;
using BlogLab.Repository;
using BlogLab.Services;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace BlogLab.Web.Extensions
{
  public static class PhotoEndpointRouteBuilderExtensions
  {
    public static IEndpointRouteBuilder MapPhotoEndpoints(this IEndpointRouteBuilder endpoints)
    {
      var group = endpoints.MapGroup("/api/photo")
          .WithTags("Photo");

      group.MapPost("/", UploadPhotoAsync)
        .WithName("Photo_Upload")
          .RequireAuthorization()
          .DisableAntiforgery();
      group.MapGet("/", GetByApplicationUserIdAsync)
        .WithName("Photo_GetMine")
          .RequireAuthorization();
      group.MapGet("/{photoId:int}", GetAsync)
        .WithName("Photo_Get");
      group.MapDelete("/{photoId:int}", DeleteAsync)
        .WithName("Photo_Delete")
          .RequireAuthorization();

      return endpoints;
    }

    private static async Task<IResult> UploadPhotoAsync(
        IFormFile file,
        HttpContext httpContext,
        IPhotoRepository photoRepository,
        IPhotoService photoService)
    {
      var applicationUserId = httpContext.User.GetRequiredApplicationUserId();
      var uploadResult = await photoService.AddPhotoAsync(file);

      if (uploadResult.Error is not null)
      {
        return TypedResults.BadRequest(uploadResult.Error.Message);
      }

      var photoCreate = new PhotoCreate
      {
        PublicId = uploadResult.PublicId,
        ImageUrl = uploadResult.SecureUrl.AbsoluteUri,
        Description = file.FileName
      };

      var photo = await photoRepository.InsertAsync(photoCreate, applicationUserId);

      return TypedResults.Ok(photo);
    }

    private static async Task<IResult> GetByApplicationUserIdAsync(
        HttpContext httpContext,
        IPhotoRepository photoRepository)
    {
      var applicationUserId = httpContext.User.GetRequiredApplicationUserId();
      var photos = await photoRepository.GetAllByUserIdAsync(applicationUserId);

      return TypedResults.Ok(photos);
    }

    private static async Task<IResult> GetAsync(
        int photoId,
        IPhotoRepository photoRepository)
    {
      var photo = await photoRepository.GetAsync(photoId);

      return photo is null ? TypedResults.NoContent() : TypedResults.Ok(photo);
    }

    private static async Task<IResult> DeleteAsync(
        int photoId,
        HttpContext httpContext,
        IPhotoRepository photoRepository,
        IBlogRepository blogRepository,
        IPhotoService photoService)
    {
      var applicationUserId = httpContext.User.GetRequiredApplicationUserId();
      var foundPhoto = await photoRepository.GetAsync(photoId);

      if (foundPhoto is null)
      {
        return TypedResults.BadRequest("Photo does not exist.");
      }

      if (foundPhoto.ApplicationUserId != applicationUserId)
      {
        return TypedResults.BadRequest("Photo was not uploaded by the current user.");
      }

      var blogs = await blogRepository.GetAllByUserIdAsync(applicationUserId);
      var usedInBlog = blogs.Any(blog => blog.PhotoId == photoId);

      if (usedInBlog)
      {
        return TypedResults.BadRequest("Cannot remove photo as it is being used in published blog(s).");
      }

      var deleteResult = await photoService.DeletePhotoAsync(foundPhoto.PublicId);

      if (deleteResult.Error is not null)
      {
        return TypedResults.BadRequest(deleteResult.Error.Message);
      }

      var affectedRows = await photoRepository.DeleteAsync(foundPhoto.PhotoId);

      return TypedResults.Ok(affectedRows);
    }
  }
}