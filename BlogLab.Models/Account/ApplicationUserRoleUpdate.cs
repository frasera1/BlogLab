using System.ComponentModel.DataAnnotations;

namespace BlogLab.Models.Account
{
  public class ApplicationUserRoleUpdate
  {
    [Required(ErrorMessage = "IsAdmin is required.")]
    public bool? IsAdmin { get; set; }
  }
}