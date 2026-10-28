using Zuno.Domain.Entities;

namespace Zuno.Application.Common.Interfaces;

public interface IUserRepository
{
    Task<User?> GetByIdAsync(Guid id, CancellationToken cancellationToken);

    Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken);

    Task<User?> GetByPhoneNumberAsync(string phoneNumber, CancellationToken cancellationToken);

    Task<User?> GetByEmailOrPhoneAsync(string emailOrPhone, CancellationToken cancellationToken);

    Task<bool> ExistsByEmailAsync(string email, CancellationToken cancellationToken);

    Task<bool> ExistsByPhoneNumberAsync(string phoneNumber, CancellationToken cancellationToken);

    void Add(User user);
}
