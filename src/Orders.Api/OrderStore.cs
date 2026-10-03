using System.Collections.Concurrent;

namespace Orders.Api;

/// <summary>
/// Almacén en memoria. Se reinicia con cada revisión/reinicio del contenedor
/// (vuelven los datos semilla).
/// </summary>
public sealed class OrderStore
{
    private readonly ConcurrentDictionary<int, Order> _orders = new();
    private int _lastId;

    public OrderStore()
    {
        Add("cliente-001", "Teclado mecánico", 2, 89.90m);
        Add("cliente-002", "Monitor 27\"", 1, 329.00m);
        Add("cliente-001", "Mouse inalámbrico", 3, 24.50m);
    }

    public IEnumerable<Order> GetAll() => _orders.Values.OrderBy(o => o.Id);

    public Order? Get(int id) => _orders.GetValueOrDefault(id);

    public Order Add(string customerId, string product, int quantity, decimal unitPrice)
    {
        var id = Interlocked.Increment(ref _lastId);
        var order = new Order(id, customerId, product, quantity, Math.Round(quantity * unitPrice, 2));
        _orders[id] = order;
        return order;
    }

    public bool Remove(int id) => _orders.TryRemove(id, out _);
}
