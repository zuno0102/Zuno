namespace Zuno.Application.Common.Interfaces;

/// <summary>
/// Brings every business's standing up to date in one pass: copies in its Rent figures and lets its level
/// take any step that time alone has made due.
/// </summary>
public interface IBusinessReputationSync
{
    /// <summary>Runs one pass over every business, in batches. Returns how many businesses were updated.</summary>
    Task<int> RunAsync(CancellationToken cancellationToken);
}
