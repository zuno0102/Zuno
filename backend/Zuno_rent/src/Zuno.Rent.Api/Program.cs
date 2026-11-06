using System.Security.Claims;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using Zuno.Rent.Api.Common;
using Zuno.Rent.Application;
using Zuno.Rent.Infrastructure;
using Zuno.Rent.Infrastructure.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRentApplication();
builder.Services.AddRentInfrastructure(builder.Configuration);

// Common login: tokens come from the shared login (today the Service API) and are only checked here,
// with the same issuer, audience and key. Rent never issues or refreshes a token.
builder.Services.AddOptions<SharedLoginSettings>()
    .Bind(builder.Configuration.GetSection(SharedLoginSettings.SectionName))
    .ValidateDataAnnotations()
    .ValidateOnStart();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer();
builder.Services
    .AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
    .Configure<IOptions<SharedLoginSettings>>((options, login) =>
    {
        var settings = login.Value;
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = settings.Issuer,
            ValidateAudience = true,
            ValidAudience = settings.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(settings.SigningKey)),
            ValidAlgorithms = [SecurityAlgorithms.HmacSha256],
            ValidateLifetime = true,
            ClockSkew = TimeSpan.Zero,
        };
    });

builder.Services.AddAuthorizationBuilder()
    .AddPolicy(RentPolicies.BusinessOwner, policy => policy.RequireClaim(ClaimTypes.Role, "BusinessOwner"))
    .AddPolicy(RentPolicies.Customer, policy => policy.RequireClaim(ClaimTypes.Role, "Customer"))
    // Shut by default: an endpoint that forgets [Authorize] is closed, not open.
    .SetFallbackPolicy(new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build());

const string WebClientCorsPolicy = "WebClient";
builder.Services.AddCors(options => options.AddPolicy(WebClientCorsPolicy, policy =>
{
    if (builder.Environment.IsDevelopment())
    {
        // The Flutter web dev server picks a new port each run; any localhost origin, Development only.
        policy.SetIsOriginAllowed(origin =>
                Uri.TryCreate(origin, UriKind.Absolute, out var uri) && uri.Host is "localhost" or "127.0.0.1")
            .AllowAnyHeader()
            .AllowAnyMethod();
    }
    else
    {
        var origins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
        policy.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod();
    }
}));

// Behind Render's proxy the caller's real address is in X-Forwarded-For; the rate limits need it.
// The platform is the only route to the container, so whatever sits in front is trusted.
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
    options.ForwardLimit = 1;
});

builder.Services.AddRateLimiter(options =>
{
    var limits = builder.Configuration.GetSection("RateLimiting");
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.OnRejected = (context, cancellationToken) => new ValueTask(context.HttpContext.Response.WriteAsJsonAsync(
        ApiResponse.Fail("Too many requests. Please try again later.", context.HttpContext.TraceIdentifier),
        cancellationToken));

    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
        RateLimitPartition.GetFixedWindowLimiter(
            context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions { PermitLimit = limits.GetValue("GlobalPermitLimit", 100), Window = TimeSpan.FromMinutes(1) }));

    // Each upload writes a file, so far fewer are allowed than ordinary requests.
    options.AddPolicy(RentPolicies.UploadPolicy, context =>
        RateLimitPartition.GetFixedWindowLimiter(
            context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions { PermitLimit = limits.GetValue("UploadPermitLimit", 30), Window = TimeSpan.FromMinutes(1) }));

    // Mobile codes: per signed-in person (else per address), so one account cannot hammer the code
    // checks from many addresses, nor many accounts from one.
    options.AddPolicy(RentPolicies.PhoneCodePolicy, context =>
        RateLimitPartition.GetFixedWindowLimiter(
            context.User.FindFirstValue(ClaimTypes.NameIdentifier) ?? context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions { PermitLimit = limits.GetValue("PhoneCodePermitLimit", 10), Window = TimeSpan.FromMinutes(1) }));
});

builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddProblemDetails();
builder.Services.Configure<ApiBehaviorOptions>(options =>
    options.InvalidModelStateResponseFactory = context => new BadRequestObjectResult(ApiResponse.Fail(
        "One or more validation errors occurred.",
        context.HttpContext.TraceIdentifier,
        context.ModelState
            .Where(entry => entry.Value?.Errors.Count > 0)
            .ToDictionary(entry => entry.Key, entry => entry.Value!.Errors.Select(e => e.ErrorMessage).ToArray()))));

builder.Services
    .AddControllers(options => options.Filters.Add<ApiResponseWrapperFilter>())
    .AddJsonOptions(options => options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));

builder.Services.AddHealthChecks();

var app = builder.Build();

// Read from the built app, the same options the storage writes with, so files are served from
// exactly where they were saved — even when a host adds its own configuration late.
var fileStorage = app.Services.GetRequiredService<IOptions<RentFileStorageSettings>>().Value;

app.UseForwardedHeaders();
app.UseExceptionHandler(_ => { });

// The API answers with JSON and serves uploaded photos; none of it may be sniffed as a page or framed.
app.Use(async (context, next) =>
{
    var headers = context.Response.Headers;
    headers.XContentTypeOptions = "nosniff";
    headers.XFrameOptions = "DENY";
    headers["Referrer-Policy"] = "no-referrer";
    headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'";
    await next();
});

if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
    app.UseHttpsRedirection();
}

app.UseCors(WebClientCorsPolicy);

var uploadsDirectory = Path.Combine(app.Environment.ContentRootPath, fileStorage.RootPath);
Directory.CreateDirectory(uploadsDirectory);
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(uploadsDirectory),
    RequestPath = fileStorage.PublicPath,
});

// After sign-in is read, so a limit can count per person rather than only per address.
app.UseAuthentication();
app.UseRateLimiter();
app.UseAuthorization();

app.MapControllers();
app.MapHealthChecks("/health").AllowAnonymous();

await app.Services.MigrateRentDatabaseAsync();

// Test codes are shown in the app, so they prove nothing about the number: fine to try the flow,
// not protection against fake bookings. Said at every start outside Development until SMS is added.
if (!app.Environment.IsDevelopment()
    && app.Services.GetRequiredService<IOptions<Zuno.Rent.Application.Common.PhoneOtpSettings>>().Value.Mode
        == Zuno.Rent.Application.Common.PhoneOtpModes.Test)
{
    app.Logger.LogWarning("PhoneOtp:Mode is Test: booking codes are shown in the app and no SMS is sent. Add an SMS sender before relying on it against fake bookings.");
}

app.Run();

/// <summary>Exposed so <c>WebApplicationFactory&lt;Program&gt;</c> can host this app in integration tests.</summary>
public partial class Program;
