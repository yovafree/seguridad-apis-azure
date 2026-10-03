# Demo 1 — Publicar la API en APIM

**Objetivo:** mostrar a Azure API Management como **puerta de entrada** única a la API, sin tocar el código del backend.

**API:** `https://<apim>.azure-api.net/demo1/orders`, que solo exige la subscription key.

## Qué hay desplegado

- La API se importó desde [orders.json](../../src/Orders.Api/openapi/orders.json), el OpenAPI que genera la propia API .NET. Cada `operationId` se convierte en una operación de APIM.
- El producto **Basic** requiere suscripción. Hay una sola subscription key, que sirve para todas las demos.
- Código: [infra/modules/apim/main.tf](../../infra/modules/apim/main.tf).

## En vivo

1. En el portal: APIM → **APIs** → *Demo 1 - Suscripción*. Muestra las operaciones importadas.
2. Ejecuta:
   ```bash
   demos/demo1/test.sh          # o demos/demo1/demo1.http
   ```

## Salida esperada (plan B)

```text
1) Backend directo, sin APIM (cualquiera puede llamarlo) -> 200
  HTTP 200
  [{"id":1,"customerId":"cliente-001","product":"Teclado mecánico","quantity":2,"total":179.80},...]

2) Vía APIM sin subscription key -> 401
  HTTP 401
  { "statusCode": 401, "message": "Access denied due to missing subscription key. ..." }

3) Vía APIM con subscription key -> 200
  HTTP 200
  [{"id":1,...}]
```

## Mensaje clave

La subscription key **identifica** al consumidor (sirve para analítica, cuotas y para revocar el acceso), pero **no lo autentica**: es un secreto compartido y estático. La Demo 3 resuelve eso. Y el backend sigue abierto (paso 1); eso se cierra en la Demo 5.
