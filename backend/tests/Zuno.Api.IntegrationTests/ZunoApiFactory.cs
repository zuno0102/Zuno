using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Npgsql;
using Testcontainers.PostgreSql;
using Zuno.Infrastructure.Persistence;

namespace Zuno.Api.IntegrationTests;

/// <summary>
/// Gives the API a real, throwaway Postgres to run against, so these tests exercise genuine EF
/// Core and Npgsql behaviour rather than mocks.
/// </summary>
/// <remarks>
/// <para>
/// Two ways to get one, and the fallback is the point. Testcontainers is the better of the two —
/// a container per run, isolated and disposable — but it needs Docker, and a developer without
/// Docker installed got no database, so this whole suite simply never ran for them. Sixteen tests
/// covering token forgery and role separation sat unexecuted, which is worse than not having them:
/// they read as coverage.
/// </para>
/// <para>
/// So when <c>ZUNO_TEST_POSTGRES</c> names a server, these tests create a uniquely-named database
/// on it, migrate it, and drop it afterwards. Same isolation, no Docker. CI keeps using
/// Testcontainers by leaving the variable unset.
/// </para>
/// <para>
/// The variable holds a connection string to the <i>server</i>, not to a database the tests use —
/// they always create their own. Nothing is read from or written to any database already there.
/// </para>
/// </remarks>
public class ZunoApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    /// <summary>Set this to run without Docker. Points at a server; the database is created here.</summary>
    public const string LocalServerVariable = "ZUNO_TEST_POSTGRES";

    private readonly PostgreSqlContainer? _container;

    /// <summary>The server to create the throwaway database on, when not using a container.</summary>
    private readonly string? _localServer;

    /// <summary>Named per run so two runs on one server cannot collide.</summary>
    private readonly string _databaseName = $"zuno_test_{Guid.NewGuid():N}";

    private string _connectionString = string.Empty;

    public ZunoApiFactory()
    {
        _localServer = Environment.GetEnvironmentVariable(LocalServerVariable);

        if (string.IsNullOrWhiteSpace(_localServer))
        {
            _container = new PostgreSqlBuilder("postgres:16-alpine")
                .WithDatabase("zuno_test_db")
                .WithUsername("zuno_test")
                .WithPassword("zuno_test_password")
                .Build();
        }
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureAppConfiguration((_, configBuilder) =>
        {
            configBuilder.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:ZunoDatabase"] = _connectionString,
                ["JwtSettings:Issuer"] = "Zuno.Api.IntegrationTests",
                ["JwtSettings:Audience"] = "Zuno.Client.IntegrationTests",
                ["JwtSettings:SigningKey"] = new string('a', 32),
                ["JwtSettings:AccessTokenExpiryMinutes"] = "15",
                ["JwtSettings:RefreshTokenExpiryDays"] = "14",

                // Raised, not removed: these tests drive the API in-process, so every request
                // shares one partition key and the suite throttles itself. The limiter still
                // runs — it is part of what is under test — it just is not tripped by the tests
                // registering their own accounts.
                ["RateLimiting:Global:PermitLimit"] = "100000",
                ["RateLimiting:Auth:PermitLimit"] = "100000",
                ["RateLimiting:PlaceSearch:PermitLimit"] = "100000",
            });
        });
    }

    public async Task InitializeAsync()
    {
        if (_container is not null)
        {
            try
            {
                await _container.StartAsync();
            }
            catch (Exception exception)
            {
                // Say which of the two routes to take. Without this the whole suite fails with a
                // Docker socket error repeated once per test, which reads as "the tests are
                // broken" rather than "this machine has no Docker".
                throw new InvalidOperationException(
                    "Could not start the test database container. Either start Docker, or set " +
                    $"{LocalServerVariable} to a Postgres server these tests may create a " +
                    "throwaway database on, e.g. " +
                    "\"Host=127.0.0.1;Port=5432;Username=postgres;Password=…;Database=postgres\".",
                    exception);
            }

            _connectionString = _container.GetConnectionString();
        }
        else
        {
            // Create the throwaway database on the named server. Done over a plain connection
            // rather than through EF, because CREATE DATABASE cannot run inside a transaction and
            // EnsureCreated would skip the migrations these tests are meant to exercise.
            var serverBuilder = new NpgsqlConnectionStringBuilder(_localServer);
            await using (var admin = new NpgsqlConnection(serverBuilder.ConnectionString))
            {
                await admin.OpenAsync();
                await using var create = new NpgsqlCommand($"create database \"{_databaseName}\"", admin);
                await create.ExecuteNonQueryAsync();
            }

            serverBuilder.Database = _databaseName;
            _connectionString = serverBuilder.ConnectionString;
        }

        using var scope = Services.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ZunoDbContext>();

        // Refuse to run anywhere but the database we just made. These tests register, cancel and
        // delete freely; pointed at a real database they would quietly destroy its contents. The
        // host reads its connection string eagerly at startup, so if the test configuration ever
        // stops reaching it, that mistake must stop the run rather than pass unnoticed.
        var actual = dbContext.Database.GetDbConnection().Database;
        var expected = new NpgsqlConnectionStringBuilder(_connectionString).Database;
        if (!string.Equals(actual, expected, StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                $"Integration tests are pointed at database '{actual}', not the throwaway " +
                $"'{expected}'. Refusing to run.");
        }

        await dbContext.Database.MigrateAsync();
    }

    async Task IAsyncLifetime.DisposeAsync()
    {
        await base.DisposeAsync();

        if (_container is not null)
        {
            await _container.DisposeAsync();
            return;
        }

        // Drop what we made. Pooled connections are closed first — Postgres refuses to drop a
        // database anything is still connected to, and the API's pool outlives the host otherwise.
        NpgsqlConnection.ClearAllPools();

        var serverBuilder = new NpgsqlConnectionStringBuilder(_localServer);
        await using var admin = new NpgsqlConnection(serverBuilder.ConnectionString);
        await admin.OpenAsync();
        await using var drop = new NpgsqlCommand(
            $"drop database if exists \"{_databaseName}\" with (force)", admin);
        await drop.ExecuteNonQueryAsync();
    }
}
