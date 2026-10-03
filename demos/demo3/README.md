# Demo 3 — Autenticación JWT con Entra ID

**Objetivo:** pasar de una subscription key (secreto compartido) a una **autenticación real** con tokens de Microsoft Entra ID, con autorización por operación.

**API:** `/demo3/orders`.

## Qué hay desplegado

- **Entra ID** ([infra/modules/identity](../../infra/modules/identity/main.tf)):

  | App registration | Qué es |
  |---|---|
  | `<prefijo>-orders-api` | La API. Expone los **app roles** `Orders.Read` y `Orders.Write` |
  | `<prefijo>-orders-client-full` | Cliente (client credentials) con los dos roles |
  | `<prefijo>-orders-client-reader` | Cliente (client credentials) solo con `Orders.Read` |

- **APIM**:
  - [demo3-jwt.xml](../../infra/policies/demo3-jwt.xml): `validate-azure-ad-token` comprueba firma, emisor y audiencia. Si falla, responde **401**. Si el token no trae el rol que exige la operación, responde **403**.
  - Cada operación declara su rol: `GET` → `Orders.Read`; `POST`/`DELETE` → `Orders.Write`.

> Con client credentials no hay usuario: los permisos llegan como **app roles** en el claim `roles`, no como scopes (`scp`).

## En vivo

```bash
scripts/get-token.sh reader --decode      # opcional: mostrar aud, azp y roles
demos/demo3/test.sh                       # o demos/demo3/demo3.http
```

## Salida esperada (plan B)

```text
1) Sin token -> 401
  HTTP 401
  {"title":"Unauthorized","status":401,"detail":"JWT not present.", ...}

2) Cliente 'reader' lee (tiene Orders.Read) -> 200
  HTTP 200
  [{"id":1,...}]

3) Cliente 'reader' intenta crear (requiere Orders.Write) -> 403
  HTTP 403
  {"title":"Forbidden","status":403,"detail":"El token no incluye el rol requerido: Orders.Write", ...}

4) Cliente 'full' crea (tiene Orders.Write) -> 201
  HTTP 201
  {"id":4,"customerId":"cliente-200","product":"Webcam","quantity":1,"total":45.00}
```

## Si algo falla

| Síntoma | Solución |
|---|---|
| `get-token.sh` da `Forbidden` de Key Vault | La asignación RBAC aún no se propagó: espera 1-2 min |
| El token no trae `roles` | Revisa que el `apply` terminó y que tienes rol de *Application Administrator* |

## Mensaje clave

APIM **autentica** (¿quién eres?) y **autoriza** (¿puedes hacer esto?) antes de que el request llegue al backend, que sigue sin una sola línea de código de seguridad.
