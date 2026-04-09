using System.Threading;
using System.Threading.Tasks;
using BlogLab.Models.Account;

namespace BlogLab.Services
{
    public interface IAdminUserDeletionService
    {
        public Task<ApplicationUserDeletionResult> DeleteAsync(
            int targetApplicationUserId,
            int requestingApplicationUserId,
            CancellationToken cancellationToken);
    }
}