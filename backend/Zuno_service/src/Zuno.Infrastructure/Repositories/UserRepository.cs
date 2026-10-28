using Microsoft.EntityFrameworkCore;
using Zuno.Application.Common.Interfaces;
using Zuno.Domain.Entities;
using Zuno.Infrastructure.Persistence;

namespace Zuno.Infrastructure.Repositories;

public class UserRepository(ZunoDbContext dbContext) : IUserRepository
{
    public Task<User?> GetByIdAsync(Guid id, CancellationToken cancellationToken) =>
        dbContext.Users.Include(u => u.Role).FirstOrDefaultAsync(u => u.Id == id, cancellationToken);

    public Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken) =>
        dbContext.Users.Include(u => u.Role).FirstOrDefaultAsync(u => u.Email == email, cancellationToken);

    public Task<User?> GetByPhoneNumberAsync(string phoneNumber, CancellationToken cancellationToken) =>
        dbContext.Users.Include(u => u.Role).FirstOrDefaultAsync(u => u.PhoneNumber == phoneNumber, cancellationToken);

    public Task<User?> GetByEmailOrPhoneAsync(string emailOrPhone, CancellationToken cancellationToken) =>
        dbContext.Users.Include(u => u.Role)
            .FirstOrDefaultAsync(u => u.Email == emailOrPhone || u.PhoneNumber == emailOrPhone, cancellationToken);

    public Task<bool> ExistsByEmailAsync(string email, CancellationToken cancellationToken) =>
        dbContext.Users.AnyAsync(u => u.Email == email, cancellationToken);

    public Task<bool> ExistsByPhoneNumberAsync(string phoneNumber, CancellationToken cancellationToken) =>
        dbContext.Users.AnyAsync(u => u.PhoneNumber == phoneNumber, cancellationToken);

    public void Add(User user) => dbContext.Users.Add(user);
}
