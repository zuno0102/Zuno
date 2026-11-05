using System.IdentityModel.Tokens.Jwt;
using System.Net.Http.Headers;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using Npgsql;
using Testcontainers.PostgreSql;
using Zuno.Rent.Infrastructure.Persistence;

namespace Zuno.Rent.IntegrationTests;

/// <summary>
/// Hosts the Rent API on a real, throwaway Postgres database — the same two routes as the Service
/// tests: a container when Docker is there, or a database made (and dropped) on the server named by
/// <c>ZUNO_TEST_POSTGRES</c> when it is not.
/// </summary>
public class RentApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    public const string LocalServerVariable = "ZUNO_TEST_POSTGRES";

    public const string Issuer = "Zuno.Api.IntegrationTests";
    public const string Audience = "Zuno.Client.IntegrationTests";
    public static readonly string SigningKey = new('k', 32);

    private readonly PostgreSqlContainer? _container;
    private readonly string? _localServer;
    private readonly string _databaseName = $"zuno_rent_test_{Guid.NewGuid():N}";
    private string _connectionString = string.Empty;

    private string UploadsDirectory => Path.Combine(Path.GetTempPath(), "zuno-rent-tests", _databaseName);

    public RentApiFactory()
    {
        _localServer = Environment.GetEnvironmentVariable(LocalServerVariable);
        if (string.IsNullOrWhiteSpace(_localServer))
        {
            _container = new PostgreSqlBuilder("postgres:16-alpine").Build();
        }
    }

    /// <summary>A token as the shared login would issue it: user id in NameIdentifier, one role.</summary>
    public static string Token(Guid userId, string role, TimeSpan? lifetime = null, string? key = null)
    {
        var credentials = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(key ?? SigningKey)), SecurityAlgorithms.HmacSha256);
        var now = DateTime.UtcNow;
        var expires = now + (lifetime ?? TimeSpan.FromMinutes(15));
        var token = new JwtSecurityToken(
            Issuer,
            Audience,
            [new Claim(ClaimTypes.NameIdentifier, userId.ToString()), new Claim(ClaimTypes.Role, role)],
            notBefore: expires < now ? expires.AddMinutes(-5) : now,
            expires: expires,
            signingCredentials: credentials);
        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public HttpClient ClientFor(Guid userId, string role = "BusinessOwner")
    {
        var client = CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", Token(userId, role));
        return client;
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["ConnectionStrings:RentDatabase"] = _connectionString,
            ["JwtSettings:Issuer"] = Issuer,
            ["JwtSettings:Audience"] = Audience,
            ["JwtSettings:SigningKey"] = SigningKey,
            // Outside the repository, and removed again when the run ends.
            ["FileStorage:RootPath"] = UploadsDirectory,

            // Raised, not removed: in-process requests share one address, so the suite would
            // otherwise throttle itself. The limiter still runs.
            ["RateLimiting:GlobalPermitLimit"] = "100000",
            ["RateLimiting:UploadPermitLimit"] = "100000",
        }));

        // The Service API is not running here: its answers about the caller come from a stand-in.
        // Nor is a payment gateway: a stand-in that accepts only the signature "good".
        builder.ConfigureTestServices(services =>
        {
            services.AddScoped<Zuno.Rent.Application.Common.IServiceDirectory, StandInServiceDirectory>();
            services.AddSingleton<Zuno.Rent.Application.Common.IRentPaymentGateway, StandInPaymentGateway>();
        });
    }

    /// <summary>Raises numbered orders and accepts a payment only when its signature is "good".</summary>
    private sealed class StandInPaymentGateway : Zuno.Rent.Application.Common.IRentPaymentGateway
    {
        private int _orders;

        public bool IsReady => true;

        public bool IsSimulated => false;

        public string KeyId => "rzp_test_stand_in";

        public Task<string> CreateOrderAsync(decimal amount, string receipt, string description, CancellationToken cancellationToken) =>
            Task.FromResult($"order_{Interlocked.Increment(ref _orders)}_{receipt}");

        public bool VerifySignature(string providerOrderId, string paymentId, string signature) => signature == "good";

        /// <summary>No payment was ever taken outside the app here.</summary>
        public Task<string?> FindCapturedPaymentAsync(string providerOrderId, CancellationToken cancellationToken) =>
            Task.FromResult<string?>(null);
    }

    /// <summary>Answers as the Service API would for any caller: a named customer and a verified business.</summary>
    private sealed class StandInServiceDirectory : Zuno.Rent.Application.Common.IServiceDirectory
    {
        public Task<Zuno.Rent.Application.Common.ServicePerson?> GetCurrentPersonAsync(CancellationToken cancellationToken) =>
            Task.FromResult<Zuno.Rent.Application.Common.ServicePerson?>(new("Test Customer", "9876543210"));

        public Task<Zuno.Rent.Application.Common.ServiceBusiness?> GetCurrentBusinessAsync(CancellationToken cancellationToken) =>
            Task.FromResult<Zuno.Rent.Application.Common.ServiceBusiness?>(new("Test Rentals", null, IsVerified: true));
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
                throw new InvalidOperationException(
                    $"Could not start the test database container. Start Docker, or set {LocalServerVariable} " +
                    "to a Postgres server these tests may create a throwaway database on.",
                    exception);
            }

            _connectionString = _container.GetConnectionString();
        }
        else
        {
            var server = new NpgsqlConnectionStringBuilder(_localServer);
            await using (var admin = new NpgsqlConnection(server.ConnectionString))
            {
                await admin.OpenAsync();
                await using var create = new NpgsqlCommand($"create database \"{_databaseName}\"", admin);
                await create.ExecuteNonQueryAsync();
            }

            server.Database = _databaseName;
            _connectionString = server.ConnectionString;
        }

        // Starting the host runs the Rent migrations (MigrateOnStartup), which is itself under test.
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<RentDbContext>();

        // Refuse to run anywhere but the database just made: these tests write and delete freely.
        var actual = db.Database.GetDbConnection().Database;
        if (!string.Equals(actual, new NpgsqlConnectionStringBuilder(_connectionString).Database, StringComparison.Ordinal))
        {
            throw new InvalidOperationException($"Integration tests are pointed at '{actual}', not their throwaway database. Refusing to run.");
        }

        await db.Database.MigrateAsync();
    }

    async Task IAsyncLifetime.DisposeAsync()
    {
        await base.DisposeAsync();

        if (Directory.Exists(UploadsDirectory))
        {
            Directory.Delete(UploadsDirectory, recursive: true);
        }

        if (_container is not null)
        {
            await _container.DisposeAsync();
            return;
        }

        NpgsqlConnection.ClearAllPools();
        await using var admin = new NpgsqlConnection(new NpgsqlConnectionStringBuilder(_localServer).ConnectionString);
        await admin.OpenAsync();
        await using var drop = new NpgsqlCommand($"drop database if exists \"{_databaseName}\" with (force)", admin);
        await drop.ExecuteNonQueryAsync();
    }
}
