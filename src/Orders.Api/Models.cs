using System.ComponentModel.DataAnnotations;

namespace Orders.Api;

/// <summary>Pedido almacenado en memoria.</summary>
public sealed record Order(int Id, string CustomerId, string Product, int Quantity, decimal Total);

/// <summary>
/// Cuerpo de POST /orders. Las anotaciones se usan dos veces:
/// 1) la validación integrada de .NET 10 (AddValidation) rechaza el request en el backend, y
/// 2) el generador OpenAPI las convierte en minLength/maxLength/minimum/maximum del esquema,
///    que es lo que APIM usa en validate-content para rechazarlo ANTES de llegar al backend.
/// </summary>
public sealed class CreateOrderRequest
{
    [Required, StringLength(50, MinimumLength = 1)]
    public required string CustomerId { get; init; }

    [Required, StringLength(100, MinimumLength = 1)]
    public required string Product { get; init; }

    [Range(1, 100)]
    public required int Quantity { get; init; }

    [Range(0.01, 10000)]
    public required decimal UnitPrice { get; init; }
}
