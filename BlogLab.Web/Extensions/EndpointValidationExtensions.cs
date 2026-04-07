using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using Microsoft.AspNetCore.Http;

namespace BlogLab.Web.Extensions
{
  public static class EndpointValidationExtensions
  {
    public static IResult ValidateRequest<TModel>(this TModel model)
    {
      var validationContext = new ValidationContext(model);
      var validationResults = new List<ValidationResult>();

      if (Validator.TryValidateObject(model, validationContext, validationResults, validateAllProperties: true))
      {
        return null;
      }

      var errors = validationResults
          .SelectMany(result => result.MemberNames.DefaultIfEmpty(string.Empty), (result, memberName) => new { memberName, result.ErrorMessage })
          .GroupBy(item => item.memberName)
          .ToDictionary(
              group => group.Key,
              group => group
                  .Select(item => item.ErrorMessage)
                  .Where(message => !string.IsNullOrWhiteSpace(message))
                  .Cast<string>()
                  .ToArray());

      return TypedResults.ValidationProblem(errors);
    }
  }
}