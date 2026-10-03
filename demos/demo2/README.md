# Demo 2 — Rate limiting y cuotas

**Objetivo:** proteger la API contra el abuso (scraping, clientes con bugs, fuerza bruta) sin tocar el backend.

**API:** `/demo2/orders`. El "antes" es la misma ráfaga contra `/demo1`, que no tiene límite.

## Qué hay desplegado

La API incluye estos fragments ([infra/policies](../../infra/policies)):

| Fragment | Política | Detalle |
|---|---|---|
| [demo2-rate-limit.xml](../../infra/policies/demo2-rate-limit.xml) | `rate-limit-by-key` | **10 llamadas / 60 s** por suscripción. Agrega `X-RateLimit-Remaining` |
| [demo2-quota.xml](../../infra/policies/demo2-quota.xml) | `quota-by-key` | **1000 llamadas / día** por suscripción |
| [common-on-error.xml](../../infra/policies/common-on-error.xml) | `on-error` | Devuelve **429 + `Retry-After`** en formato ProblemDetails (también para la cuota, que por defecto daría 403) |

## En vivo

```bash
demos/demo2/rate-limit.sh demo1     # "antes": 15 x 200
demos/demo2/rate-limit.sh           # "después": 10 x 200 y 5 x 429

# Opcional
demos/demo2/k6.sh                   # carga: 60 llamadas en 30 s
demos/demo2/kql.sh                  # logs (la ingesta tarda 2-5 min), o queries.kql en el portal
```

> Ejecuta `k6.sh` al principio de la demo para que los logs ya estén disponibles cuando llegues a KQL.

## Salida esperada (plan B)

```text
==> Enviando 15 llamadas a https://<apim>.azure-api.net/demo2/orders
  #1   HTTP 200  restantes: 9
  ...
  #10  HTTP 200  restantes: 0
  #11  HTTP 429  Retry-After: 53s
  ...
==> Resumen
  2xx: 10
  429: 5

Detalle de una respuesta 429 (ProblemDetails)
  HTTP 429
  Content-Type: application/problem+json
  Retry-After: 52
  {"type":"https://tools.ietf.org/html/rfc6585#section-4","title":"Too Many Requests","status":429,
   "detail":"Demasiadas solicitudes. Espera antes de reintentar (ver header Retry-After).", ...}
```

> El conteo puede variar en ±1: el rate limiting de APIM es distribuido y la documentación dice que "nunca es completamente exacto".

k6: `Total: 61 · 2xx: ~10 · 429: ~51`. KQL: una fila por minuto con `total` y `limitadas`.

## Mensaje clave

- **Rate limit** = protección de corto plazo (picos). **Cuota** = contrato de consumo (plan comercial).
- La **llave** decide quién comparte el contador: aquí, la suscripción. También podría ser la IP o la identidad del token.
- Los 429 nunca llegan al backend: en los logs, `BackendResponseCode` aparece vacío.
