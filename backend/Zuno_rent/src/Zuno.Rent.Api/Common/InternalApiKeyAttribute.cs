using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Extensions.Options;

namespace Zuno.Rent.Api.Common;

/// <summary>The key the three Zuno APIs share for their calls to each other (section <c>InternalApi</c>).</summary>
public class InternalApiSettings
{
    public const string SectionName = "InternalApi";

    public const string HeaderName = "X-Zuno-Internal-Key";

    public string Key { get; set; } = string.Empty;
}

/// <summary>
/// Lets a request in only with the shared internal key; anything else is 404, so the endpoint does not
/// exist to the outside. With no key configured every call is refused.
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method)]
public sealed class InternalApiKeyAttribute : Attribute, IAuthorizationFilter
{
    public void OnAuthorization(AuthorizationFilterContext context)
    {
        var key = context.HttpContext.RequestServices.GetRequiredService<IOptions<InternalApiSettings>>().Value.Key;
        var sent = context.HttpContext.Request.Headers[InternalApiSettings.HeaderName].ToString();
        if (string.IsNullOrWhiteSpace(key)
            || !CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(sent), Encoding.UTF8.GetBytes(key)))
        {
            context.Result = new NotFoundResult();
        }
    }
}
