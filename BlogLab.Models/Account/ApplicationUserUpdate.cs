using System.ComponentModel.DataAnnotations;

namespace BlogLab.Models.Account
{
  public class ApplicationUserUpdate
  {
    [MinLength(10, ErrorMessage = "Must be 10-30 characters.")]
    [MaxLength(30, ErrorMessage = "Must be 10-30 characters.")]
    public string Fullname { get; set; }

    [Required(ErrorMessage = "Email is required.")]
    [MaxLength(30, ErrorMessage = "Must be at most 30 characters.")]
    [EmailAddress(ErrorMessage = "Invalid email address.")]
    public string Email { get; set; }
  }
}