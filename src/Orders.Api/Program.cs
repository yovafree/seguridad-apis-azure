using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.OpenApi;
using Orders.Api;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi(options =>
{
    // APIM importa OpenAPI 3.1 solo de forma parcial; con 3.0 validate-content usa el esquema completo.
    options.OpenApiVersion = OpenApiSpecVersion.OpenApi3_0;
    options.AddDocumentTransformer((document, _, _) =>
    {
        document.Info.Title = "Orders API";
        document.Info.Description = "API de pedidos para las demos de seguridad con Azure API Management.";
        // La URL del backend la define APIM (service_url); no publicamos servidores en el documento.
        document.Servers?.Clear();
        return Task.CompletedTask;
    });
});
// Por defecto ASP.NET acepta números como strings ("quantity": "5") y el esquema queda como
// type: [integer, string]. Con Strict el contrato es exacto y validate-content puede aplicarlo.
builder.Services.ConfigureHttpJsonOptions(options =>
    options.SerializerOptions.NumberHandling = JsonNumberHandling.Strict);
builder.Services.AddValidation();
builder.Services.AddProblemDetails();
builder.Services.AddSingleton<OrderStore>();

var app = builder.Build();

// A propósito: el backend "filtra" información de la plataforma en los headers.
// La demo 4 muestra cómo APIM los elimina sin tocar este código.
// (Kestrel ya agrega "Server: Kestrel" por defecto.)
app.Use(async (context, next) =>
{
    context.Response.OnStarting(() =>
    {
        context.Response.Headers["X-Powered-By"] = "ASP.NET";
        context.Response.Headers["X-AspNet-Version"] = "4.0.30319";
        return Task.CompletedTask;
    });

    // Una línea por request en los logs del contenedor: sirve para demostrar
    // que los requests rechazados por APIM nunca llegan aquí.
    app.Logger.LogInformation("Backend recibió {Method} {Path}", context.Request.Method, context.Request.Path);
    await next();
});

app.MapOpenApi(); // /openapi/v1.json

app.MapGet("/health", () => Results.Ok(new { status = "ok" }))
   .ExcludeFromDescription(); // no se publica en APIM

var orders = app.MapGroup("/orders").WithTags("Orders");

// Los nombres (operationId) en kebab-case se convierten en los ids de operación de APIM;
// Terraform los usa para las políticas por operación (roles de la Demo 3).
orders.MapGet("/", (OrderStore store) => TypedResults.Ok(store.GetAll()))
      .WithName("list-orders")
      .WithSummary("Lista todos los pedidos");

orders.MapGet("/{id:int}", Results<Ok<Order>, NotFound> (int id, OrderStore store) =>
          store.Get(id) is { } order ? TypedResults.Ok(order) : TypedResults.NotFound())
      .WithName("get-order")
      .WithSummary("Obtiene un pedido por id");

orders.MapPost("/", (CreateOrderRequest request, OrderStore store) =>
      {
          var order = store.Add(request.CustomerId, request.Product, request.Quantity, request.UnitPrice);
          return TypedResults.Created($"/orders/{order.Id}", order);
      })
      .WithName("create-order")
      .WithSummary("Crea un pedido")
      .ProducesValidationProblem();

orders.MapDelete("/{id:int}", Results<NoContent, NotFound> (int id, OrderStore store) =>
          store.Remove(id) ? TypedResults.NoContent() : TypedResults.NotFound())
      .WithName("delete-order")
      .WithSummary("Elimina un pedido");

app.Run();
