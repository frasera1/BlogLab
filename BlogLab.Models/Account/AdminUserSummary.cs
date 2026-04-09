namespace BlogLab.Models.Account
{
  public class AdminUserSummary
  {
    public int ApplicationUserId { get; set; }

    public string Username { get; set; }

    public string Fullname { get; set; }

    public string Email { get; set; }

    public bool IsAdmin { get; set; }
  }
}