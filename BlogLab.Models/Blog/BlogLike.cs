namespace BlogLab.Models.Blog
{
    public class BlogLike
    {
        public int BlogId { get; set; }

        public int LikeCount { get; set; }

        public bool LikedByCurrentUser { get; set; }
    }
}