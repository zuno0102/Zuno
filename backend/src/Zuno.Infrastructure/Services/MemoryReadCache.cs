using System.Collections.Concurrent;
using Microsoft.Extensions.Caching.Memory;
using Zuno.Application.Common.Interfaces;

namespace Zuno.Infrastructure.Services;

/// <summary>
/// <see cref="IReadCache"/> in this instance's memory. One lock per key, so a burst of requests for an
/// expired entry runs the expensive read once rather than once per request.
/// </summary>
public sealed class MemoryReadCache(IMemoryCache cache) : IReadCache
{
    private readonly ConcurrentDictionary<string, SemaphoreSlim> _locks = new(StringComparer.Ordinal);

    public async Task<T> GetOrCreateAsync<T>(
        string key,
        TimeSpan ttl,
        Func<CancellationToken, Task<T>> factory,
        CancellationToken cancellationToken)
    {
        if (cache.TryGetValue(key, out T? hit) && hit is not null)
        {
            return hit;
        }

        var gate = _locks.GetOrAdd(key, _ => new SemaphoreSlim(1, 1));
        await gate.WaitAsync(cancellationToken);
        try
        {
            if (cache.TryGetValue(key, out hit) && hit is not null)
            {
                return hit;
            }

            var value = await factory(cancellationToken);
            cache.Set(key, value, ttl);
            return value;
        }
        finally
        {
            gate.Release();
        }
    }
}
