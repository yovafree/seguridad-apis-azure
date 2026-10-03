# Demo 4 — Validación y transformación

**Objetivo:** rechazar requests inválidos **antes** de que lleguen al backend y quitar de las respuestas la información sobre la tecnología.

**API:** `/demo4/orders`. El "antes" es la misma llamada a `/demo1`, que no tiene validación.

## Qué hay desplegado

| Fragment | Qué hace |
|---|---|
| [demo4-validate.xml](../../infra/policies/demo4-validate.xml) | `validate-content` valida el body contra el esquema OpenAPI: tipos, `quantity` 1-100 y **sin propiedades extra**. `validate-parameters` valida path y query |
| [demo4-strip-headers.xml](../../infra/policies/demo4-strip-headers.xml) | Elimina `Server`, `X-Powered-By` y `X-AspNet-Version` |

El esquema sale del propio código: `[Range(1, 100)]` en [Models.cs](../../src/Orders.Api/Models.cs) se convierte en `minimum: 1, maximum: 100` en el OpenAPI que importa APIM.

> El backend envía `X-Powered-By` y `X-AspNet-Version` **a propósito** ([Program.cs](../../src/Orders.Api/Program.cs)) para la demo.

## En vivo

```bash
demos/demo4/test.sh            # o demos/demo4/demo4.http (A1 vs A2, B1 vs B2, C)
```

## Salida esperada (plan B)

```text
==> A) Headers de respuesta: ¿se ve la tecnología del backend?
Vía /demo1 (sin limpieza)
  HTTP/1.1 200 OK
  x-powered-by: ASP.NET
  x-aspnet-version: 4.0.30319
Vía /demo4 (con limpieza)
  HTTP/1.1 200 OK
  (sin Server / X-Powered-By / X-AspNet-Version)

==> B) Campo extra no declarado ("isAdmin": true)
Vía /demo1 -> 201 (¡el backend lo acepta sin quejarse!)
  HTTP 201
Vía /demo4 -> 400 (lo rechaza APIM: el backend nunca lo ve)
  HTTP 400
  {"title":"Bad Request","status":400,"detail":"... Property 'isAdmin' has not been defined and the schema does not allow additional properties. ...","rechazadoPor":"API Management (validate-content)"}

==> C) quantity = 500 (el esquema permite 1-100)
Vía /demo4 -> 400
  HTTP 400
  {..."detail":"... Integer 500 exceeds maximum value of 100. Path 'quantity' ..."}
```

> El ingress de Container Apps puede reemplazar el header `Server`. Comprueba en el ensayo qué valor llega.

## Mensaje clave

- **Validar en el borde** protege a todos los backends, también a los que no validan, y ahorra cómputo.
- El contrato (OpenAPI) pasa a ser **ejecutable**: si no está en el esquema, no entra (*mass assignment*).
- **No filtrar la tecnología** deja al atacante con menos información.
