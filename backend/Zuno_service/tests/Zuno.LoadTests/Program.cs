using System.Collections.Concurrent;
using System.Diagnostics;
using System.Globalization;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

// A small load test for the Zuno API: signs in a set of the dummy accounts made by
// tests/perf/seed-volume.sql, then has many of them use the busiest screens at once, and reports
// latency and errors per endpoint.
//
//   dotnet run -c Release --project tests/Zuno.LoadTests -- --base http://localhost:5157/api/v1 \
//     --users 300 --concurrency 100 --seconds 60
//
// Point it only at a scratch API on a scratch database: every request is real.

var options = LoadOptions.Parse(args);
Console.WriteLine($"Target {options.BaseUrl}  users {options.Users}  concurrency {options.Concurrency}  {options.Seconds}s");

using var http = new HttpClient(new SocketsHttpHandler
{
    MaxConnectionsPerServer = options.Concurrency * 2,
    PooledConnectionLifetime = TimeSpan.FromMinutes(5),
})
{
    BaseAddress = new Uri(options.BaseUrl.TrimEnd('/') + "/"),
    Timeout = TimeSpan.FromSeconds(30),
};

var stats = new ConcurrentDictionary<string, EndpointStats>();

// ---- 1. Sign in ---------------------------------------------------------------------------------
var accounts = Accounts.Pick(options).ToList();
var sessions = new ConcurrentBag<Session>();
var signIn = Stopwatch.StartNew();
await Parallel.ForEachAsync(
    accounts,
    new ParallelOptions { MaxDegreeOfParallelism = Math.Min(options.Concurrency, 32) },
    async (account, ct) =>
    {
        var started = Stopwatch.GetTimestamp();
        try
        {
            using var response = await http.PostAsJsonAsync(
                "auth/login", new { emailOrPhone = account.Email, password = options.Password }, ct);
            Record(stats, "POST auth/login", started, response.IsSuccessStatusCode, (int)response.StatusCode);
            if (!response.IsSuccessStatusCode)
            {
                return;
            }

            using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync(ct));
            var token = json.RootElement.GetProperty("data").GetProperty("accessToken").GetString();
            if (token is not null)
            {
                sessions.Add(new Session(account.Role, token));
            }
        }
        catch (Exception)
        {
            Record(stats, "POST auth/login", started, false, 0);
        }
    });
Console.WriteLine($"Signed in {sessions.Count}/{accounts.Count} in {signIn.Elapsed.TotalSeconds:F1}s");
if (sessions.IsEmpty)
{
    Console.WriteLine("Nobody could sign in. Is the database filled, and the rate limiter raised?");
    return 1;
}

// ---- 2. Use the app -----------------------------------------------------------------------------
var pool = sessions.ToArray();
var deadline = DateTime.UtcNow.AddSeconds(options.Seconds);
var run = Stopwatch.StartNew();
var loops = Enumerable.Range(0, options.Concurrency).Select(async n =>
{
    var random = new Random(n);
    while (DateTime.UtcNow < deadline)
    {
        var session = pool[random.Next(pool.Length)];
        var path = Screens.For(session.Role, random);
        var started = Stopwatch.GetTimestamp();
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, path);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", session.Token);
            using var response = await http.SendAsync(request, HttpCompletionOption.ResponseContentRead);
            Record(stats, "GET " + Screens.Name(path), started, response.IsSuccessStatusCode, (int)response.StatusCode);
        }
        catch (Exception)
        {
            Record(stats, "GET " + Screens.Name(path), started, false, 0);
        }
    }
});
await Task.WhenAll(loops);
var elapsed = run.Elapsed.TotalSeconds;

// ---- 3. Report ----------------------------------------------------------------------------------
Console.WriteLine();
Console.WriteLine($"{"Endpoint",-38} {"Requests",9} {"Errors",7} {"Req/s",8} {"p50 ms",8} {"p95 ms",8} {"p99 ms",8} {"Max ms",8}");
var totalRequests = 0;
var totalErrors = 0;
foreach (var (name, s) in stats.OrderBy(s => s.Key, StringComparer.Ordinal))
{
    var lat = s.Latencies.ToArray();
    Array.Sort(lat);
    var isLogin = name.StartsWith("POST", StringComparison.Ordinal);
    var rate = lat.Length / (isLogin ? signIn.Elapsed.TotalSeconds : elapsed);
    Console.WriteLine(
        $"{name,-38} {lat.Length,9} {s.Errors,7} {rate,8:F1} {Pct(lat, 50),8:F0} {Pct(lat, 95),8:F0} {Pct(lat, 99),8:F0} {(lat.Length == 0 ? 0 : lat[^1]),8:F0}");
    if (!isLogin)
    {
        totalRequests += lat.Length;
        totalErrors += s.Errors;
    }

    foreach (var (code, count) in s.StatusCodes.Where(c => c.Key is < 200 or >= 300))
    {
        Console.WriteLine($"{string.Empty,-38}   status {code}: {count}");
    }
}

Console.WriteLine();
Console.WriteLine(
    $"Screens: {totalRequests} requests in {elapsed:F0}s = {totalRequests / elapsed:F0} req/s, "
    + $"errors {totalErrors} ({(totalRequests == 0 ? 0 : 100.0 * totalErrors / totalRequests):F2}%)");
return totalErrors == 0 ? 0 : 2;

static void Record(ConcurrentDictionary<string, EndpointStats> stats, string name, long started, bool ok, int status)
{
    var ms = Stopwatch.GetElapsedTime(started).TotalMilliseconds;
    var s = stats.GetOrAdd(name, _ => new EndpointStats());
    s.Latencies.Add(ms);
    s.StatusCodes.AddOrUpdate(status, 1, (_, c) => c + 1);
    if (!ok)
    {
        Interlocked.Increment(ref s.Errors);
    }
}

static double Pct(double[] sorted, int p) =>
    sorted.Length == 0 ? 0 : sorted[Math.Min(sorted.Length - 1, (int)Math.Ceiling(p / 100.0 * sorted.Length) - 1)];

internal sealed class EndpointStats
{
    public readonly ConcurrentBag<double> Latencies = [];
    public readonly ConcurrentDictionary<int, int> StatusCodes = new();
    public int Errors;
}

internal sealed record Session(string Role, string Token);

internal sealed record Account(string Role, string Email);

internal sealed record LoadOptions(string BaseUrl, int Users, int Concurrency, int Seconds, string Password, double Scale)
{
    public static LoadOptions Parse(string[] args)
    {
        string Get(string name, string fallback)
        {
            var i = Array.IndexOf(args, "--" + name);
            return i >= 0 && i + 1 < args.Length ? args[i + 1] : fallback;
        }

        return new LoadOptions(
            Get("base", "http://localhost:5157/api/v1"),
            int.Parse(Get("users", "300"), CultureInfo.InvariantCulture),
            int.Parse(Get("concurrency", "100"), CultureInfo.InvariantCulture),
            int.Parse(Get("seconds", "60"), CultureInfo.InvariantCulture),
            Get("password", "abi@1234"),
            double.Parse(Get("scale", "1"), CultureInfo.InvariantCulture));
    }
}

/// <summary>Which dummy accounts to sign in as: half workers, three in ten customers, two in ten businesses.</summary>
internal static class Accounts
{
    public static IEnumerable<Account> Pick(LoadOptions o)
    {
        var customers = Math.Max(1, (int)(120000 * o.Scale));
        var workers = Math.Max(1, (int)(70000 * o.Scale));
        var businesses = Math.Max(1, (int)(10000 * o.Scale));
        var random = new Random(42);

        for (var i = 0; i < o.Users; i++)
        {
            yield return (i % 10) switch
            {
                < 5 => new Account("Worker", $"perf_w{1 + random.Next(workers)}@zuno.local"),
                < 8 => new Account("Customer", $"perf_c{1 + random.Next(customers)}@zuno.local"),
                _ => new Account("BusinessOwner", $"perf_b{1 + random.Next(businesses)}@zuno.local"),
            };
        }
    }
}

/// <summary>The screens each role opens most, as the requests the app makes for them.</summary>
internal static class Screens
{
    private static readonly (double Lat, double Lon)[] Places =
    [
        (13.0827, 80.2707), (8.5241, 76.9366), (9.9312, 76.2673), (11.0168, 76.9558), (8.1833, 77.4119),
    ];

    public static string For(string role, Random random)
    {
        var (lat, lon) = Places[random.Next(Places.Length)];
        var near = string.Create(CultureInfo.InvariantCulture, $"latitude={lat}&longitude={lon}&radiusKm=25");
        return role switch
        {
            "Worker" => random.Next(6) switch
            {
                0 => "worker/dashboard",
                1 => "worker/hiring-posts?" + near,
                2 => "worker/hiring-posts/mine",
                3 => "worker/jobs",
                4 => "worker/vacancies",
                _ => "notifications/unread-count",
            },
            "BusinessOwner" => random.Next(5) switch
            {
                0 => "business/dashboard",
                1 => "business/bookings",
                2 => "business/hiring-posts",
                3 => "business/vacancies/summary",
                _ => "notifications",
            },
            _ => random.Next(4) switch
            {
                0 => "customer/services/home",
                1 => "customer/bookings",
                2 => "customer/services/banners",
                _ => "notifications/unread-count",
            },
        };
    }

    /// <summary>A path without its query string, so every location counts as one endpoint.</summary>
    public static string Name(string path) => path.Split('?')[0];
}
