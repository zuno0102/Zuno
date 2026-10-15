using Microsoft.AspNetCore.Mvc.Filters;

namespace Zuno.Api.Common;

/// <summary>
/// Wraps every 2xx controller result carrying a body in <see cref="ApiResponse"/> so success and
/// failure payloads share one shape. Results with no body (204) or already-wrapped results pass through.
/// </summary>
public class ApiResponseWrapperFilter : IActionFilter
{
    public void OnActionExecuting(ActionExecutingContext context)
    {
    }

    public void OnActionExecuted(ActionExecutedContext context)
    {
        if (context.Result is not Microsoft.AspNetCore.Mvc.ObjectResult objectResult)
        {
            return;
        }

        if (objectResult.Value is ApiResponse)
        {
            return;
        }

        var statusCode = objectResult.StatusCode ?? StatusCodes.Status200OK;
        if (statusCode is < 200 or >= 300)
        {
            return;
        }

        objectResult.Value = ApiResponse.Ok(objectResult.Value, context.HttpContext.TraceIdentifier);
    }
}
