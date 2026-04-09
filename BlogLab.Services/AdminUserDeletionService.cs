using System;
using System.Threading;
using System.Threading.Tasks;
using BlogLab.Models.Account;
using BlogLab.Repository;
using Microsoft.Extensions.Logging;

namespace BlogLab.Services
{
    public class AdminUserDeletionService : IAdminUserDeletionService
    {
        private readonly IAccountRepository _accountRepository;
        private readonly ILogger<AdminUserDeletionService> _logger;
        private readonly IPhotoRepository _photoRepository;
        private readonly IPhotoService _photoService;

        public AdminUserDeletionService(
            IAccountRepository accountRepository,
            ILogger<AdminUserDeletionService> logger,
            IPhotoRepository photoRepository,
            IPhotoService photoService)
        {
            _accountRepository = accountRepository;
            _logger = logger;
            _photoRepository = photoRepository;
            _photoService = photoService;
        }

        public async Task<ApplicationUserDeletionResult> DeleteAsync(
            int targetApplicationUserId,
            int requestingApplicationUserId,
            CancellationToken cancellationToken)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var requestingUser = await _accountRepository.GetByIdAsync(requestingApplicationUserId, cancellationToken);
            if (requestingUser is null || !requestingUser.IsAdmin)
            {
                throw new UnauthorizedAccessException("You must be an admin to manage users.");
            }

            var targetUser = await _accountRepository.GetByIdAsync(targetApplicationUserId, cancellationToken);
            if (targetUser is null)
            {
                throw new InvalidOperationException("User does not exist.");
            }

            if (targetApplicationUserId == requestingApplicationUserId)
            {
                throw new InvalidOperationException("Admins cannot delete their own accounts.");
            }

            if (targetUser.IsAdmin)
            {
                var adminCount = await _accountRepository.CountAdminsAsync(cancellationToken);
                if (adminCount <= 1)
                {
                    throw new InvalidOperationException("You cannot delete the last remaining admin.");
                }
            }

            var photos = await _photoRepository.GetAllByUserIdAsync(targetApplicationUserId);
            var deletionResult = await _accountRepository.DeleteWithDependenciesAsync(targetApplicationUserId, cancellationToken);

            foreach (var photo in photos)
            {
                if (string.IsNullOrWhiteSpace(photo.PublicId))
                {
                    continue;
                }

                var deleteResult = await _photoService.DeletePhotoAsync(photo.PublicId);
                if (deleteResult.Error is not null)
                {
                    _logger.LogWarning(
                        "Deleted user {TargetApplicationUserId} but failed to remove remote photo {PublicId}: {ErrorMessage}",
                        targetApplicationUserId,
                        photo.PublicId,
                        deleteResult.Error.Message);
                }
            }

            return deletionResult;
        }
    }
}