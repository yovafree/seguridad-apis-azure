# Imagen multi-stage de la API de pedidos.
# Build:  docker build -t orders-api:1.0.0 src/Orders.Api
# En Azure: az acr build (lo hace scripts/deploy.sh)

# --- Etapa 1: compilación ---
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY Orders.Api.csproj .
RUN dotnet restore
COPY . .
# El documento OpenAPI ya está versionado en openapi/orders.json; no se regenera aquí.
RUN dotnet publish -c Release -o /app -p:GenerateOpenApi=false --no-restore

# --- Etapa 2: runtime ---
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app .
# Las imágenes de .NET escuchan en 8080 y traen el usuario sin privilegios "app".
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
USER app
ENTRYPOINT ["dotnet", "Orders.Api.dll"]
