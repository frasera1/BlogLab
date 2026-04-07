using BlogLab.Models.Blog;
using Dapper;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Threading.Tasks;

namespace BlogLab.Repository
{
    public class BlogRepository : IBlogRepository
    {
        private readonly IConfiguration _config;

        public BlogRepository(IConfiguration config)
        {
            _config = config;
        }

        public async Task<int> DeleteAsync(int blogId)
        {
            int affectedRows = 0;

            using (var connection = new SqlConnection(_config.GetConnectionString("DefaultConnection")))
            {
                await connection.OpenAsync();

                affectedRows = await connection.ExecuteAsync(
                    "Blog_Delete",
                    new { BlogId = blogId },
                    commandType: CommandType.StoredProcedure);
            }

            return affectedRows;
        }

        public async Task<PagedResults<Blog>> GetAllAsync(BlogPaging blogPaging, int? currentApplicationUserId = null)
        {
            var results = new PagedResults<Blog>();

            using (var connection = new SqlConnection(_config.GetConnectionString("DefaultConnection")))
            {
                await connection.OpenAsync();

                using (var multi = await connection.QueryMultipleAsync("Blog_GetAll",
                    new
                    {
                        Offset = (blogPaging.Page - 1) * blogPaging.PageSize,
                        PageSize = blogPaging.PageSize,
                        CurrentApplicationUserId = currentApplicationUserId
                    },
                    commandType: CommandType.StoredProcedure))
                {
                    results.Items = multi.Read<Blog>();
                    results.TotalCount = multi.ReadFirst<int>();
                }
            }
            return results;
        }

        public async Task<List<Blog>> GetAllByUserIdAsync(int applicationUserId, int? currentApplicationUserId = null)
        {
            IEnumerable<Blog> blogs;

            using (var connection = new SqlConnection(_config.GetConnectionString("DefaultConnection")))
            {
                await connection.OpenAsync();

                blogs = await connection.QueryAsync<Blog>(
                    "Blog_GetByUserId",
                    new
                    {
                        ApplicationUserId = applicationUserId,
                        CurrentApplicationUserId = currentApplicationUserId
                    },
                    commandType: CommandType.StoredProcedure);

            }

            return blogs.ToList();
        }

        public async Task<List<Blog>> GetAllFamousAsync(int? currentApplicationUserId = null)
        {
            IEnumerable<Blog> famousBlogs;

            using (var connection = new SqlConnection(_config.GetConnectionString("DefaultConnection")))
            {
                await connection.OpenAsync();

                famousBlogs = await connection.QueryAsync<Blog>(
                    "Blog_GetAllFamous",
                    new { CurrentApplicationUserId = currentApplicationUserId },
                    commandType: CommandType.StoredProcedure);

            }

            return famousBlogs.ToList();
        }

        public async Task<Blog> GetAsync(int blogId, int? currentApplicationUserId = null)
        {
            Blog blog;

            using (var connection = new SqlConnection(_config.GetConnectionString("DefaultConnection")))
            {
                await connection.OpenAsync();

                blog = await connection.QueryFirstOrDefaultAsync<Blog>(
                    "Blog_Get",
                    new
                    {
                        BlogId = blogId,
                        CurrentApplicationUserId = currentApplicationUserId
                    },
                    commandType: CommandType.StoredProcedure);
            }

            return blog;
        }

        public async Task<BlogLike> ToggleLikeAsync(int blogId, int applicationUserId)
        {
            BlogLike blogLike;

            using (var connection = new SqlConnection(_config.GetConnectionString("DefaultConnection")))
            {
                await connection.OpenAsync();

                blogLike = await connection.QueryFirstOrDefaultAsync<BlogLike>(
                    "BlogLike_Toggle",
                    new
                    {
                        BlogId = blogId,
                        ApplicationUserId = applicationUserId
                    },
                    commandType: CommandType.StoredProcedure);
            }

            return blogLike;
        }

        public async Task<Blog> UpsertAsync(BlogCreate blogCreate, int applicationUserId)
        {
            var dataTable = new DataTable();
            dataTable.Columns.Add("BlogId", typeof(int));
            dataTable.Columns.Add("Title", typeof(string));
            dataTable.Columns.Add("Content", typeof(string));
            dataTable.Columns.Add("PhotoId", typeof(int));

            dataTable.Rows.Add(
                blogCreate.BlogId,
                blogCreate.Title,
                blogCreate.Content,
                blogCreate.PhotoId);

            int? newBlogId;

            using (var connection = new SqlConnection(_config.GetConnectionString("DefaultConnection")))
            {
                await connection.OpenAsync();

                newBlogId = await connection.ExecuteScalarAsync<int?>("Blog_Upsert",
                    new { Blog = dataTable.AsTableValuedParameter("dbo.BlogType"), applicationUserId = applicationUserId },
                    commandType: CommandType.StoredProcedure);
            }

            newBlogId = newBlogId ?? blogCreate.BlogId;

            Blog blog = await GetAsync(newBlogId.Value);

            return blog;
        }
    }
}
