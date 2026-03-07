using BlogLab.Models.Blog;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;

namespace BlogLab.Repository
{
    public interface IBlogRepository
    {
        public Task<Blog> UpsertAsync(BlogCreate blogCreate, int applicationUserId);

        public Task<PagedResults<Blog>> GetAllAsync(BlogPaging blogPaging, int? currentApplicationUserId = null);

        public Task<Blog> GetAsync(int blogId, int? currentApplicationUserId = null);

        public Task<List<Blog>> GetAllFamousAsync(int? currentApplicationUserId = null);

        public Task<List<Blog>> GetAllByUserIdAsync(int applicationUserId, int? currentApplicationUserId = null);

        public Task<BlogLike> ToggleLikeAsync(int blogId, int applicationUserId);

        public Task<int> DeleteAsync(int blogId);
    }
}
