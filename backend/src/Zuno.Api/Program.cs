using System.Security.Claims;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using Asp.Versioning;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Options;
using Serilog;
using Swashbuckle.AspNetCore.SwaggerGen;
using Zuno.Api.Authorization;
using Zuno.Api.Common;
using Zuno.Api.Configuration;
using Zuno.Api.ExceptionHandling;
using Zuno.Api.RateLimiting;
using Zuno.Application;
using Zuno.Application.Common.Settings;
using Zuno.Infrastructure;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((context, _, loggerConfiguration) =>
    loggerConfiguration.ReadFrom.Configuration(context.Configuration));

builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration, builder.Environment.IsDevelopment());

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer();

// Validation is wired from the same JwtSettings the token *issuer* uses, resolved through options
// rather than read straight out of configuration here. Reading it here meant the two halves could
// disagree: the issuer picked up a late configuration source and signed with one key while this
// validator kept the key that was present at start-up, so every token the app had just minted came
// back 401. JwtSettings already validates on start, so a missing section still fails at boot.
builder.Services
    .AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
    .Configure<IOptions<JwtSettings>>((options, jwtSettings) =>
    {
        var settings = jwtSettings.Value;

        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = settings.Issuer,
            ValidateAudience = true,
            ValidAudience = settings.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(settings.SigningKey)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.Zero,
        };
    });

builder.Services.AddAuthorizationBuilder()
    .AddPolicy(AuthorizationPolicyNames.RequireCustomerRole, policy => policy.RequireClaim(ClaimTypes.Role, "Customer"))
    .AddPolicy(AuthorizationPolicyNames.RequireBusinessOwnerRole, policy => policy.RequireClaim(ClaimTypes.Role, "BusinessOwner"))
    .AddPolicy(AuthorizationPolicyNames.RequireWorkerRole, policy => policy.RequireClaim(ClaimTypes.Role, "Worker"))
    .AddPolicy(AuthorizationPolicyNames.RequireSuperAdminRole, policy => policy.RequireClaim(ClaimTypes.Role, "SuperAdmin"))
    // Shut by default. Every endpoint today carries its own [Authorize], but that is a habit rather
    // than a guarantee: the next controller somebody adds is public until they remember the
    // attribute, and nothing fails to tell them. With a fallback, forgetting closes an endpoint
    // instead of opening it, and the handful that are genuinely public say so with
    // [AllowAnonymous] — a decision visible in the diff.
    .SetFallbackPolicy(new AuthorizationPolicyBuilder()
        .RequireAuthenticatedUser()
        .Build());

const string WebClientCorsPolicy = "WebClient";

builder.Services.AddCors(options =>
{
    options.AddPolicy(WebClientCorsPolicy, policy =>
    {
        if (builder.Environment.IsDevelopment())
        {
            // The Flutter web dev server picks an arbitrary port per run, so any localhost
            // origin is allowed here — this policy is never active outside Development.
            policy.SetIsOriginAllowed(origin =>
                    Uri.TryCreate(origin, UriKind.Absolute, out var uri) && uri.Host is "localhost" or "127.0.0.1")
                .AllowAnyHeader()
                .AllowAnyMethod();
        }
        else
        {
            var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
            policy.WithOrigins(allowedOrigins).AllowAnyHeader().AllowAnyMethod();
        }
    });
});

// Read the caller's real address out of the proxy's headers. See app.UseForwardedHeaders() below
// for why the rate limiter is useless without this when hosted.
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;

    // The proxy's own address is not knowable in advance on a platform like Render — it is assigned
    // and changes — so the default "only trust these networks" check would reject every header and
    // leave us back where we started. Clearing both lists trusts whatever sits in front of the
    // application, which is safe only because the platform is the only route to it: Render does not
    // expose the container directly, so nothing can reach this port without passing their edge.
    // Move this app anywhere it can be addressed directly and these lists must be filled in, or a
    // caller could claim any address they like and dodge the limits.
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
    options.ForwardLimit = 1;
});

builder.Services.AddZunoRateLimiting(builder.Configuration);

builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
builder.Services.AddProblemDetails();

builder.Services.Configure<ApiBehaviorOptions>(options =>
{
    options.InvalidModelStateResponseFactory = context =>
    {
        var errors = context.ModelState
            .Where(entry => entry.Value?.Errors.Count > 0)
            .ToDictionary(
                entry => entry.Key,
                entry => entry.Value!.Errors.Select(e => e.ErrorMessage).ToArray());

        var response = ApiResponse.Fail(
            "One or more validation errors occurred.",
            context.HttpContext.TraceIdentifier,
            errors);

        return new BadRequestObjectResult(response);
    };
});

builder.Services
    .AddApiVersioning(options =>
    {
        options.DefaultApiVersion = new ApiVersion(1, 0);
        options.AssumeDefaultVersionWhenUnspecified = true;
        options.ReportApiVersions = true;
    })
    .AddApiExplorer(options =>
    {
        options.GroupNameFormat = "'v'VVV";
        options.SubstituteApiVersionInUrl = true;
    });

builder.Services
    .AddControllers(options => options.Filters.Add<ApiResponseWrapperFilter>())
    .AddJsonOptions(options =>
        // DTOs already emit enums as their string names, so accept the same form on the way in —
        // clients send "PerEvent", not the brittle underlying number.
        options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));

builder.Services.ConfigureOptions<ConfigureSwaggerOptions>();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var fileStorageSettings = builder.Configuration.GetSection(FileStorageSettings.SectionName).Get<FileStorageSettings>()
    ?? new FileStorageSettings();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    var apiVersionDescriptionProvider = app.Services.GetRequiredService<Asp.Versioning.ApiExplorer.IApiVersionDescriptionProvider>();

    app.UseSwagger();
    app.UseSwaggerUI(options =>
    {
        foreach (var description in apiVersionDescriptionProvider.ApiVersionDescriptions)
        {
            options.SwaggerEndpoint($"/swagger/{description.GroupName}/swagger.json", description.GroupName.ToUpperInvariant());
        }
    });
}

// First in the pipeline, so everything after it sees the real caller.
//
// Hosted behind a reverse proxy — Render, and any other platform that terminates TLS for you —
// every request arrives from the proxy, so Connection.RemoteIpAddress is the proxy's address and
// not the person's. The rate limiter partitions on that address, which means without this the
// whole user base shares one bucket: five sign-in attempts a minute between everybody, and the
// hundred-a-minute global limit reached by the site simply being busy. Running locally there is no
// proxy, no X-Forwarded-For header, and this does nothing.
app.UseForwardedHeaders();

// Request logging goes outside the exception handler, so what it records is the status the client
// actually received. The other way round, every exception passed up through this middleware before
// the handler below turned it into a response, so an ordinary wrong-password sign-in — a 401 to the
// caller — was written to the log as "responded 500". Hundreds of them, which is the kind of noise
// that hides the real 500 when one happens. The handler does its own logging of the exception
// itself, at warning for the expected ones and error for the rest, so nothing is lost here.
app.UseSerilogRequestLogging();

app.UseExceptionHandler(_ => { });

// Headers on every response, set before anything can write one.
//
// None of these defend the API against a scripted attacker — they defend a person using a browser
// against their own browser's helpfulness: guessing that an uploaded file is HTML and running it,
// framing a page to capture clicks, or forwarding the full URL to a third-party site. Uploaded
// customer and worker photographs are served from this same application, which is exactly the
// content sniffing is dangerous on.
app.Use(async (context, next) =>
{
    var headers = context.Response.Headers;

    headers.XContentTypeOptions = "nosniff";
    headers.XFrameOptions = "DENY";
    headers["Referrer-Policy"] = "no-referrer";
    // The API answers with JSON and serves images; it never needs to run a script or be embedded.
    headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'";

    await next();
});

// Tells a browser never to speak to this host over plain HTTP again. Out of Development only:
// in Development the API is reached over http on a LAN address, and HSTS there would poison the
// browser's cache for that host.
if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseCors(WebClientCorsPolicy);

var uploadsDirectory = Path.Combine(app.Environment.ContentRootPath, fileStorageSettings.RootPath);
Directory.CreateDirectory(uploadsDirectory);
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(uploadsDirectory),
    RequestPath = fileStorageSettings.PublicPath,
});

app.UseRateLimiter();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

if (app.Environment.IsDevelopment())
{
    try
    {
        await Zuno.Infrastructure.Persistence.Seed.AdminUserSeeder.SeedAsync(app.Services);
    }
    catch (Exception ex)
    {
        // Dev-only convenience seeding must never crash the app — e.g. the database may not
        // be up yet. Auth endpoints will surface a clear per-request error until it is.
        app.Logger.LogWarning(ex, "Skipping Super Admin seed: database was not reachable at startup.");
    }
}

app.Run();

/// <summary>Exposed so `WebApplicationFactory&lt;Program&gt;` can bootstrap this app in integration tests.</summary>
public partial class Program;
