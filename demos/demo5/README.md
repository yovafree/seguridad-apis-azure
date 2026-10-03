# Demo 5 — Cerrar el backend: solo se llega a través de APIM

**Objetivo:** hasta ahora todas las protecciones se podían **saltar** llamando directamente al backend. Aquí APIM pasa a ser el único camino.

**API:** `/demo5/orders`, que apunta a un **segundo backend** (misma imagen) que ya está cerrado. El backend abierto de las demos 1-4 se usa como "antes".

## Qué hay desplegado (dos capas independientes)

| Capa | Cómo | Dónde |
|---|---|---|
| **Red** | El ingress de la Container App solo permite la **IP pública de APIM** | `allowed_ips` en [infra/main.tf](../../infra/main.tf) |
| **Identidad** | APIM pide un token con su **Managed Identity** ([demo5-backend-mi.xml](../../infra/policies/demo5-backend-mi.xml)) y la Container App (Easy Auth) solo acepta tokens de esa identidad | [infra/modules/container-app](../../infra/modules/container-app/main.tf) |

- La restricción por IP funciona porque APIM **Developer** (clásico) tiene una IP pública **estática**. ⚠️ Basic v2 y Standard v2 no tienen una IP de salida determinista: con esos tiers solo aplica la capa de identidad.
- La capa de identidad no usa secretos y no depende del tier ni de la red.

## En vivo

```bash
demos/demo5/lockdown.sh       # o demos/demo5/demo5.http
```

Muéstralo en el portal: Container App `<prefijo>-orders-locked` → **Ingress** → *IP restrictions*, y → **Authentication**.

## Salida esperada (plan B)

```text
1) Backend abierto (demos 1-4), directo -> 200: ¡se salta APIM y todas sus políticas!
  HTTP 200
  [{"id":1,...}]

2) Backend cerrado, directo -> 403 (ingress: solo la IP de APIM)
  HTTP 403

3) Backend cerrado vía APIM (/demo5, Managed Identity) -> 200
  HTTP 200
  [{"id":1,...}]
```

> En el paso 2 la IP se bloquea antes de que actúe Easy Auth. Para ver también la capa de identidad (401 sin token), agrega tu IP en `lockdown_extra_allowed_ips` antes del despliegue.

## Para producción

**VNet + ingress interno**: APIM Standard v2 (integración VNet) o Premium, más un entorno de Container Apps **interno** y DNS privado. Así el backend no tiene endpoint público. No se usa en la demo porque el modo interno del entorno no se puede cambiar después de crearlo y el despliegue tarda más.

## Mensaje clave

Sin cerrar el backend, el gateway es **opcional** para un atacante. Con identidad + red, APIM es el **único camino**.
