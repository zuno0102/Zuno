using Zuno.Application.Modules.Catalog.DTOs;

namespace Zuno.Application.Common.Interfaces;

/// <summary>The apps' labels and colours, held in memory and refreshed from their tables.</summary>
public interface IUiConfigStore
{
    UiConfigDto Current { get; }

    Task RefreshAsync(CancellationToken cancellationToken);
}
