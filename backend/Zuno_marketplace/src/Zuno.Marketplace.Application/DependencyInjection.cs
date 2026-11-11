using FluentValidation;
using Microsoft.Extensions.DependencyInjection;
using Zuno.Marketplace.Application.Common;

namespace Zuno.Marketplace.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddMarketplaceApplication(this IServiceCollection services)
    {
        var assembly = typeof(DependencyInjection).Assembly;

        services.AddMediatR(config =>
        {
            config.RegisterServicesFromAssembly(assembly);
            config.AddOpenBehavior(typeof(ValidationBehavior<,>));
        });

        services.AddValidatorsFromAssembly(assembly);
        services.AddMemoryCache();
        services.AddScoped<MarketplaceReference>();

        return services;
    }
}
