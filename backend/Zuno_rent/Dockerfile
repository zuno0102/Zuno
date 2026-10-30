# Build context: backend/  (so the shared Directory.Build.props is included)
#   docker build -f Zuno_rent/Dockerfile -t zuno-rent .
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY Directory.Build.props ./
COPY Zuno_rent/src/Zuno.Rent.Api/Zuno.Rent.Api.csproj Zuno_rent/src/Zuno.Rent.Api/
COPY Zuno_rent/src/Zuno.Rent.Application/Zuno.Rent.Application.csproj Zuno_rent/src/Zuno.Rent.Application/
COPY Zuno_rent/src/Zuno.Rent.Domain/Zuno.Rent.Domain.csproj Zuno_rent/src/Zuno.Rent.Domain/
COPY Zuno_rent/src/Zuno.Rent.Infrastructure/Zuno.Rent.Infrastructure.csproj Zuno_rent/src/Zuno.Rent.Infrastructure/
RUN dotnet restore Zuno_rent/src/Zuno.Rent.Api/Zuno.Rent.Api.csproj

COPY Zuno_rent/src/ Zuno_rent/src/
RUN dotnet publish Zuno_rent/src/Zuno.Rent.Api/Zuno.Rent.Api.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app
COPY --from=build /app .

ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 8080
ENTRYPOINT ["sh", "-c", "ASPNETCORE_URLS=http://+:${PORT:-8080} dotnet Zuno.Rent.Api.dll"]
