using FluentValidation;
using Microsoft.Extensions.DependencyInjection;
using Zuno.Rent.Application.Common;

namespace Zuno.Rent.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddRentApplication(this IServiceCollection services)
    {
        var assembly = typeof(DependencyInjection).Assembly;

        services.AddMediatR(config =>
        {
            config.RegisterServicesFromAssembly(assembly);
            config.AddOpenBehavior(typeof(ValidationBehavior<,>));
        });

        services.AddValidatorsFromAssembly(assembly);
        services.AddMemoryCache();

        return services;
    }
}
