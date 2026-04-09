namespace BlogLab.Models.Account
{
  public class ApplicationUserDeletionResult
  {
    public int ApplicationUserId { get; set; }

    public string Username { get; set; }

    public int DeletedBlogCount { get; set; }

    public int DeletedCommentCount { get; set; }

    public int DeletedLikeCount { get; set; }

    public int DeletedPhotoCount { get; set; }

    public int DeletedUserCount { get; set; }
  }
}