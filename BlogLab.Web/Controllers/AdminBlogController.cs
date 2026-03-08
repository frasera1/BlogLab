using BlogLab.Models.Blog;
using BlogLab.Repository;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Threading.Tasks;

namespace BlogLab.Web.Controllers
{
    [Route("api/admin/blog")]
    [ApiController]
    public class AdminBlogController : ControllerBase
    {
        private readonly IBlogRepository _blogRepository;

        public AdminBlogController(IBlogRepository blogRepository)
        {
            _blogRepository = blogRepository;
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
        [HttpGet]
        public async Task<ActionResult<PagedResults<Blog>>> GetAll([FromQuery] BlogPaging blogPaging)
        {
            if (!User.IsInRole("Admin"))
            {
                return StatusCode(StatusCodes.Status403Forbidden, "You must be an admin to manage blogs.");
            }

            int? currentApplicationUserId = TryGetApplicationUserId();
            var blogs = await _blogRepository.GetAllAsync(blogPaging, currentApplicationUserId);

            return Ok(blogs);
        }
    }
}