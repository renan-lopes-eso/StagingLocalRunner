# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj and restore dependencies
COPY ["src/StagingApp/StagingApp.csproj", "StagingApp/"]
RUN dotnet restore "StagingApp/StagingApp.csproj"

# Copy all code and build
COPY src/StagingApp/. StagingApp/
WORKDIR "/src/StagingApp"
RUN dotnet build "StagingApp.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "StagingApp.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
EXPOSE 8080

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Copy published app
COPY --from=publish /app/publish .

# Default environment variables
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Staging

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["dotnet", "StagingApp.dll"]
