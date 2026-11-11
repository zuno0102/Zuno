# Build context: backend/  (so the shared Directory.Build.props is included)
#   docker build -f Zuno_marketplace/Dockerfile -t zuno-marketplace .
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY Directory.Build.props ./
COPY Zuno_marketplace/src/Zuno.Marketplace.Api/Zuno.Marketplace.Api.csproj Zuno_marketplace/src/Zuno.Marketplace.Api/
COPY Zuno_marketplace/src/Zuno.Marketplace.Application/Zuno.Marketplace.Application.csproj Zuno_marketplace/src/Zuno.Marketplace.Application/
COPY Zuno_marketplace/src/Zuno.Marketplace.Domain/Zuno.Marketplace.Domain.csproj Zuno_marketplace/src/Zuno.Marketplace.Domain/
COPY Zuno_marketplace/src/Zuno.Marketplace.Infrastructure/Zuno.Marketplace.Infrastructure.csproj Zuno_marketplace/src/Zuno.Marketplace.Infrastructure/
RUN dotnet restore Zuno_marketplace/src/Zuno.Marketplace.Api/Zuno.Marketplace.Api.csproj

COPY Zuno_marketplace/src/ Zuno_marketplace/src/
RUN dotnet publish Zuno_marketplace/src/Zuno.Marketplace.Api/Zuno.Marketplace.Api.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app
COPY --from=build /app .

ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 8080
ENTRYPOINT ["sh", "-c", "ASPNETCORE_URLS=http://+:${PORT:-8080} dotnet Zuno.Marketplace.Api.dll"]
