using FluentAssertions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Zuno.Infrastructure.Persistence;

namespace Zuno.Infrastructure.UnitTests.Persistence;

/// <summary>
/// Start-up migration is switched by configuration. Switched off, it must not even reach for the
/// database: no DbContext is registered here, so any attempt would throw.
/// </summary>
public class DatabaseMigratorTests
{
    [Theory]
    [InlineData("false")]
    [InlineData(null)]
    public async Task MigrateAsync_WhenSwitchedOff_DoesNotTouchTheDatabase(string? setting)
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { [DatabaseMigrator.SettingKey] = setting })
            .Build();

        var services = new ServiceCollection()
            .AddSingleton<IConfiguration>(configuration)
            .BuildServiceProvider();

        var act = () => DatabaseMigrator.MigrateAsync(services);

        await act.Should().NotThrowAsync();
    }

    [Fact]
    public async Task MigrateAsync_WhenSwitchedOn_UsesTheDatabase()
    {
        var configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { [DatabaseMigrator.SettingKey] = "true" })
            .Build();

        var services = new ServiceCollection()
            .AddSingleton<IConfiguration>(configuration)
            .BuildServiceProvider();

        // No DbContext registered: reaching for it proves the switch was honoured.
        var act = () => DatabaseMigrator.MigrateAsync(services);

        await act.Should().ThrowAsync<InvalidOperationException>();
    }
}
