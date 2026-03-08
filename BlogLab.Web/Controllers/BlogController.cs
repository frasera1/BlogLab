using BlogLab.Models.Blog;
using BlogLab.Repository;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Threading.Tasks;

namespace BlogLab.Web.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class BlogController : ControllerBase
    {
        private readonly IBlogRepository _blogRepository;
        private readonly IPhotoRepository _photoRepository;

        public BlogController(IPhotoRepository photoRepository,
            IBlogRepository blogRepository)
        {
            _blogRepository = blogRepository;
            _photoRepository = photoRepository;
        }

        private int? TryGetApplicationUserId()
        {
            var applicationUserIdClaim = User?.Claims?.FirstOrDefault(i => i.Type == JwtRegisteredClaimNames.NameId)?.Value;

            if (int.TryParse(applicationUserIdClaim, out int applicationUserId))
            {
                return applicationUserId;
            }

            return null;
        }

        [Authorize]
        [HttpPost]
        public async Task<ActionResult<Blog>> Create(BlogCreate blogCreate)
        {
            int applicationUserId = int.Parse(User.Claims.First(i => i.Type == JwtRegisteredClaimNames.NameId).Value);

            if (blogCreate.PhotoId.HasValue)
            {
                var photo = await _photoRepository.GetAsync(blogCreate.PhotoId.Value);
                if (photo.ApplicationUserId != applicationUserId)
                {
                    return BadRequest("You did not upload the photo.");
                }
            }

            var blog = await _blogRepository.UpsertAsync(blogCreate, applicationUserId);

            return Ok(blog);
        }

        [HttpGet]
        public async Task<ActionResult<PagedResults<Blog>>> GetAll([FromQuery] BlogPaging blogPaging)
        {
            int? currentApplicationUserId = TryGetApplicationUserId();

            var blogs = await _blogRepository.GetAllAsync(blogPaging, currentApplicationUserId);

            return Ok(blogs);
        }

        [HttpGet("{blogId}")]
        public async Task<ActionResult<PagedResults<Blog>>> Get(int blogId)
        {
            int? currentApplicationUserId = TryGetApplicationUserId();

            var blog = await _blogRepository.GetAsync(blogId, currentApplicationUserId);

            return Ok(blog);
        }

        [HttpGet("user/{applicationUserId}")]
        public async Task<ActionResult<List<Blog>>> GetByApplicationUserId(int applicationUserId)
        {
            int? currentApplicationUserId = TryGetApplicationUserId();

            var blogs = await _blogRepository.GetAllByUserIdAsync(applicationUserId, currentApplicationUserId);

            return Ok(blogs);
        }

        [HttpGet("famous")]
        public async Task<ActionResult<List<Blog>>> GetAllFamous()
        {
            int? currentApplicationUserId = TryGetApplicationUserId();

            var blogs = await _blogRepository.GetAllFamousAsync(currentApplicationUserId);

            return Ok(blogs);
        }

        [Authorize]
        [HttpPost("{blogId}/like/toggle")]
        public async Task<ActionResult<BlogLike>> ToggleLike(int blogId)
        {
            int applicationUserId = int.Parse(User.Claims.First(i => i.Type == JwtRegisteredClaimNames.NameId).Value);

            var foundBlog = await _blogRepository.GetAsync(blogId, applicationUserId);

            if (foundBlog == null) return BadRequest("Blog does not exist.");

            var blogLike = await _blogRepository.ToggleLikeAsync(blogId, applicationUserId);

            return Ok(blogLike);
        }

        [Authorize]
        [HttpDelete("{blogId}")]
        public async Task<ActionResult<int>> Delete(int blogId)
        {
            int applicationUserId = int.Parse(User.Claims.First(i => i.Type == JwtRegisteredClaimNames.NameId).Value);

            var foundBlog = await _blogRepository.GetAsync(blogId);

            if (foundBlog == null) return BadRequest("Blog does not exist.");


            if (foundBlog.ApplicationUserId == applicationUserId || User.IsInRole("Admin"))
            {
                var affectedRows = await _blogRepository.DeleteAsync(blogId);

                return Ok(affectedRows);
            }
            else
            {
                return BadRequest("You didn't create this blog.");
            }

        }
    }
}
