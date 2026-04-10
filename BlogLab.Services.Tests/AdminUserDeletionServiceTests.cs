using BlogLab.Models.Account;
using BlogLab.Models.Photo;
using BlogLab.Repository;
using BlogLab.Services;
using CloudinaryDotNet.Actions;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace BlogLab.Services.Tests;

public class AdminUserDeletionServiceTests
{
  private readonly Mock<IAccountRepository> _accountRepository = new();
  private readonly Mock<IPhotoRepository> _photoRepository = new();
  private readonly Mock<IPhotoService> _photoService = new();
  private readonly Mock<ILogger<AdminUserDeletionService>> _logger = new();

  [Fact]
  public async Task DeleteAsync_ThrowsWhenRequestingUserIsNotAdmin()
  {
    var service = CreateService();

    _accountRepository
        .Setup(repository => repository.GetByIdAsync(7, It.IsAny<CancellationToken>()))
        .ReturnsAsync(new ApplicationUserIdentity
        {
          ApplicationUserId = 7,
          Username = "writer",
          IsAdmin = false,
        });

    var exception = await Assert.ThrowsAsync<UnauthorizedAccessException>(() =>
        service.DeleteAsync(11, 7, CancellationToken.None));

    Assert.Equal("You must be an admin to manage users.", exception.Message);
    _accountRepository.Verify(
        repository => repository.DeleteWithDependenciesAsync(It.IsAny<int>(), It.IsAny<CancellationToken>()),
        Times.Never);
    _photoService.Verify(
        photoService => photoService.DeletePhotoAsync(It.IsAny<string>()),
        Times.Never);
  }

  [Fact]
  public async Task DeleteAsync_ThrowsWhenDeletingOwnAccount()
  {
    var service = CreateService();

    _accountRepository
        .Setup(repository => repository.GetByIdAsync(7, It.IsAny<CancellationToken>()))
        .ReturnsAsync(new ApplicationUserIdentity
        {
          ApplicationUserId = 7,
          Username = "adminlab",
          IsAdmin = true,
        });

    var exception = await Assert.ThrowsAsync<InvalidOperationException>(() =>
        service.DeleteAsync(7, 7, CancellationToken.None));

    Assert.Equal("Admins cannot delete their own accounts.", exception.Message);
    _accountRepository.Verify(
        repository => repository.CountAdminsAsync(It.IsAny<CancellationToken>()),
        Times.Never);
    _accountRepository.Verify(
        repository => repository.DeleteWithDependenciesAsync(It.IsAny<int>(), It.IsAny<CancellationToken>()),
        Times.Never);
  }

  [Fact]
  public async Task DeleteAsync_ThrowsWhenDeletingLastRemainingAdmin()
  {
    var service = CreateService();

    _accountRepository
        .Setup(repository => repository.GetByIdAsync(7, It.IsAny<CancellationToken>()))
        .ReturnsAsync(new ApplicationUserIdentity
        {
          ApplicationUserId = 7,
          Username = "adminlab",
          IsAdmin = true,
        });
    _accountRepository
        .Setup(repository => repository.GetByIdAsync(2, It.IsAny<CancellationToken>()))
        .ReturnsAsync(new ApplicationUserIdentity
        {
          ApplicationUserId = 2,
          Username = "target-admin",
          IsAdmin = true,
        });
    _accountRepository
        .Setup(repository => repository.CountAdminsAsync(It.IsAny<CancellationToken>()))
        .ReturnsAsync(1);

    var exception = await Assert.ThrowsAsync<InvalidOperationException>(() =>
        service.DeleteAsync(2, 7, CancellationToken.None));

    Assert.Equal("You cannot delete the last remaining admin.", exception.Message);
    _photoRepository.Verify(
        repository => repository.GetAllByUserIdAsync(It.IsAny<int>()),
        Times.Never);
    _accountRepository.Verify(
        repository => repository.DeleteWithDependenciesAsync(It.IsAny<int>(), It.IsAny<CancellationToken>()),
        Times.Never);
  }

  [Fact]
  public async Task DeleteAsync_DeletesDependenciesAndOnlyRemovesRemotePhotosWithPublicIds()
  {
    var service = CreateService();
    var deletionResult = new ApplicationUserDeletionResult
    {
      ApplicationUserId = 11,
      Username = "writer",
      DeletedBlogCount = 2,
      DeletedCommentCount = 5,
      DeletedLikeCount = 3,
      DeletedPhotoCount = 2,
      DeletedUserCount = 1,
    };

    _accountRepository
        .Setup(repository => repository.GetByIdAsync(7, It.IsAny<CancellationToken>()))
        .ReturnsAsync(new ApplicationUserIdentity
        {
          ApplicationUserId = 7,
          Username = "adminlab",
          IsAdmin = true,
        });
    _accountRepository
        .Setup(repository => repository.GetByIdAsync(11, It.IsAny<CancellationToken>()))
        .ReturnsAsync(new ApplicationUserIdentity
        {
          ApplicationUserId = 11,
          Username = "writer",
          IsAdmin = false,
        });
    _photoRepository
        .Setup(repository => repository.GetAllByUserIdAsync(11))
        .ReturnsAsync(new List<Photo>
        {
                new() { PhotoId = 1, ApplicationUserId = 11, PublicId = "cloudinary-photo-1", ImageUrl = "https://example.com/1.jpg", Description = "first" },
                new() { PhotoId = 2, ApplicationUserId = 11, PublicId = null!, ImageUrl = "https://example.com/2.jpg", Description = "second" },
                new() { PhotoId = 3, ApplicationUserId = 11, PublicId = "   ", ImageUrl = "https://example.com/3.jpg", Description = "third" },
        });
    _accountRepository
        .Setup(repository => repository.DeleteWithDependenciesAsync(11, It.IsAny<CancellationToken>()))
        .ReturnsAsync(deletionResult);
    _photoService
        .Setup(photoService => photoService.DeletePhotoAsync("cloudinary-photo-1"))
        .ReturnsAsync(new DeletionResult());

    var result = await service.DeleteAsync(11, 7, CancellationToken.None);

    Assert.Same(deletionResult, result);
    _accountRepository.Verify(
        repository => repository.DeleteWithDependenciesAsync(11, It.IsAny<CancellationToken>()),
        Times.Once);
    _photoService.Verify(photoService => photoService.DeletePhotoAsync("cloudinary-photo-1"), Times.Once);
    _photoService.Verify(
        photoService => photoService.DeletePhotoAsync(It.Is<string>(value => string.IsNullOrWhiteSpace(value))),
        Times.Never);
  }

  private AdminUserDeletionService CreateService()
  {
    return new AdminUserDeletionService(
        _accountRepository.Object,
        _logger.Object,
        _photoRepository.Object,
        _photoService.Object);
  }
}