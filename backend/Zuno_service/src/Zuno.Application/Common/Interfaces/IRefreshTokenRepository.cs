using Zuno.Domain.Entities;

namespace Zuno.Application.Common.Interfaces;

public interface IRefreshTokenRepository
{
    Task<RefreshToken?> GetByTokenHashAsync(string tokenHash, CancellationToken cancellationToken);

    Task<List<RefreshToken>> GetActiveTokensForUserAsync(Guid userId, CancellationToken cancellationToken);

    void Add(RefreshToken refreshToken);
}
