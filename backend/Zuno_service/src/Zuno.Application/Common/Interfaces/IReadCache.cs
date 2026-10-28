namespace Zuno.Application.Common.Interfaces;

/// <summary>
/// A short-lived cache for reads that are the same for everybody, such as the customer home screen.
/// </summary>
/// <remarks>
/// Per instance today (in memory), behind an interface so it can move to a shared store when several
/// instances run behind a load balancer. Only for data that may be a little stale: never for money,
/// permissions or anything a user just changed.
/// </remarks>
public interface IReadCache
{
    /// <summary>
    /// The cached value for <paramref name="key"/>, or the result of <paramref name="factory"/>, kept for
    /// <paramref name="ttl"/>. Concurrent misses for one key run the factory once.
    /// </summary>
    Task<T> GetOrCreateAsync<T>(
        string key,
        TimeSpan ttl,
        Func<CancellationToken, Task<T>> factory,
        CancellationToken cancellationToken);
}
