# Seguridad de APIs en Azure: API Management, .NET, rate limiting y políticas

Repositorio de demos para la charla. Cinco demos reproducibles muestran cómo **Azure API Management (APIM)** protege una API **.NET 10** sin modificar su código.

Toda la infraestructura se despliega **una sola vez, el día anterior**. Cada demo es una API distinta de APIM con sus políticas ya activas, así que durante la charla **no se ejecuta Terraform**: para pasar de una demo a otra solo cambia la URL.

| # | Demo | URL | Qué se ve |
|---|---|---|---|
| 1 | [Publicar la API en APIM](demos/demo1/README.md) | `/demo1/orders` | Backend abierto 200; APIM: 401 sin key, 200 con key |
| 2 | [Rate limiting y cuotas](demos/demo2/README.md) | `/demo2/orders` | 10 x 200 y luego 429 ProblemDetails con `Retry-After` (+ k6 y KQL opcionales) |
| 3 | [JWT con Entra ID](demos/demo3/README.md) | `/demo3/orders` | `validate-azure-ad-token` y roles: 401 / 200 / 403 / 201 |
| 4 | [Validación y transformación](demos/demo4/README.md) | `/demo4/orders` | Campo extra: 201 en `/demo1` vs 400 en `/demo4`; headers limpios |
| 5 | [Backend cerrado](demos/demo5/README.md) | `/demo5/orders` | Backend cerrado directo 403; vía APIM (Managed Identity) 200 |

```text
                    ┌───────────── Azure API Management (Developer) ─────────────┐
                    │ /demo1  suscripción                                         │──┐
 cliente / k6 ─────▶│ /demo2  + rate limit + cuota                                │  │ backend abierto
                    │ /demo3  + JWT (Entra ID) + roles                            │  │ (orders-open)
                    │ /demo4  + validación + limpieza de headers                  │──┘
                    │ /demo5  + Managed Identity hacia el backend                 │──┐ backend cerrado
                    └──────────────────────────┬──────────────────────────────────┘  │ (orders-locked: solo
                              logs/telemetría  ▼                                      │  IP de APIM + Easy Auth)
                         Log Analytics + Application Insights                         ▼
                              Azure Container Apps: Orders.Api (.NET 10), 2 apps con la misma imagen
```

## Decisiones técnicas (verificadas en la documentación, octubre 2026)

- **APIM Developer_1** (configurable con `apim_sku`):
  - Soporta todas las políticas usadas.
  - Tiene una **IP pública dedicada y estática**, necesaria para cerrar el backend por IP en la Demo 5.
  - ⚠️ **Basic v2 / Standard v2** no tienen IP de salida determinista: con ellos, el backend solo se puede cerrar por identidad (o por VNet en Standard v2).
  - ⚠️ La página de `quota-by-key` indica que aplica a los tiers clásicos (Developer/Basic/Standard/Premium) y no menciona los v2.
  - ⏱️ **Developer tarda 30-60 minutos en crearse.**
- **Una API de APIM por demo** (el mismo OpenAPI importado cinco veces) y **dos Container Apps** (abierta y cerrada) con la misma imagen. El costo extra es mínimo y evita aplicar cambios en vivo.
- **Providers fijados** en [infra/versions.tf](infra/versions.tf):
  - azurerm `5.8.0`, azuread `3.10.0` y azapi `2.13.0`.
  - Terraform **>= 1.11**, por los atributos write-only de Key Vault.
- **azapi solo donde azurerm no llega:** Easy Auth de Container Apps.
- **OpenAPI 3.0:**
  - .NET 10 genera 3.1 por defecto, y APIM importa 3.1 solo de forma parcial. La API se compila con `--openapi-version OpenApi3_0`.
  - El archivo resultante está versionado en [src/Orders.Api/openapi/orders.json](src/Orders.Api/openapi/orders.json) y Terraform lo importa con `file()`, así el despliegue no depende de que el backend esté vivo.
- **Políticas como policy fragments:**
  - Hay un `.xml` por política y por demo en [infra/policies](infra/policies). Se ven en el portal (*Policy fragments*).
  - Cada API incluye sus fragments desde [api-policy.xml.tftpl](infra/policies/api-policy.xml.tftpl). La lista por demo está en `local.demos` de [infra/modules/apim/main.tf](infra/modules/apim/main.tf).

## Prerrequisitos

| Herramienta | Versión | Para qué |
|---|---|---|
| Suscripción de Azure | Rol **Owner**, o **Contributor + User Access Administrator** | Crear recursos y asignaciones RBAC (AcrPull, Key Vault) |
| Tenant de Entra ID | Rol **Application Administrator** o **Cloud Application Administrator** | Crear app registrations y conceder app roles (admin consent) |
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) | 2.60+ | Autenticación, `az acr build`, Key Vault |
| [Terraform](https://developer.hashicorp.com/terraform/install) | **>= 1.11** (probado con 1.16.5) | Infraestructura |
| bash | Git Bash, WSL, Linux o macOS | Scripts (no requieren `jq`) |
| [k6](https://grafana.com/docs/k6/latest/set-up/install-k6/) | reciente | Demo 2 (opcional) |
| VS Code + [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client) | — | Archivos `.http` (alternativa a los scripts) |
| .NET 10 SDK | 10.0.x | Solo para ejecutar la API en local o regenerar el OpenAPI |
| Docker | opcional | Solo con `BUILD_MODE=docker` (si tu suscripción no permite ACR Tasks) |

## Despliegue (una sola vez, el día ANTES de la charla)

```bash
az login
az account set --subscription "<suscripción>"

# 1. Edita infra/environments/demo.tfvars: prefix y apim_publisher_email como mínimo.
# 2. Despliega todo (~45-70 min, sobre todo por APIM Developer):
scripts/deploy.sh

# 3. Comprueba que las cinco demos responden:
scripts/check.sh
```

[scripts/deploy.sh](scripts/deploy.sh) hace lo siguiente:

1. `terraform init`.
2. Crea el resource group y el ACR.
3. Construye y publica la imagen con `az acr build`.
4. `terraform plan` y `apply` con `demo.tfvars`.
5. Genera `demos/.env` (URLs, subscription key y tokens).

[scripts/check.sh](scripts/check.sh) hace una llamada por demo. Todas deben dar 2xx, salvo el backend cerrado directo, que debe dar 403.

### Backend de estado

Por defecto el estado es **local** (`infra/terraform.tfstate`). Contiene los client secrets de Entra ID y la subscription key, así que no lo compartas. Para guardarlo cifrado en Azure Storage con acceso por Entra ID, sigue [infra/backend.tf.example](infra/backend.tf.example).

## Durante la charla (1 hora)

**10 minutos antes:** `scripts/check.sh`. Comprueba las cinco demos y regenera `demos/.env` con tokens nuevos, que duran ~60-90 min.

| Min. | Bloque | Comandos |
|---|---|---|
| 0-10 | Introducción | — |
| 10-17 | Demo 1 | `demos/demo1/test.sh` |
| 17-27 | Demo 2 | `demos/demo2/rate-limit.sh demo1` → `demos/demo2/rate-limit.sh` (opcional: `k6.sh`, `kql.sh`) |
| 27-37 | Demo 3 | `demos/demo3/test.sh` |
| 37-45 | Demo 4 | `demos/demo4/test.sh` |
| 45-52 | Demo 5 | `demos/demo5/lockdown.sh` |
| 52-60 | Cierre y preguntas | — |

- Las demos son **independientes**: puedes saltarte o repetir cualquiera, en cualquier orden.
- Cada script hace pausas entre pasos (Enter). Desactívalas con `NO_PAUSE=1`.
- Si repites la Demo 2 antes de que pasen 60 s, los 429 aparecen antes porque el contador sigue activo.
- Cada demo tiene también un `.http` para REST Client con los mismos pasos.

### Plan B (si falla la conexión)

- Cada README de demo tiene una sección **"Salida esperada (plan B)"**. Esas salidas se **derivaron de la configuración y de la documentación**, no de una ejecución real: valídalas en el ensayo.
- Durante el ensayo guarda las salidas reales: `NO_PAUSE=1 demos/demoN/test.sh | tee demos/demoN/capturas/salida.txt`.
- Toma las capturas que lista `demos/demoN/capturas/README.md`.

## Seguridad del propio repo

- **Sin secretos en git:**
  - `.gitignore` excluye `*.tfstate` y `.env`.
  - `demo.tfvars` no contiene secretos.
- **Client secrets:**
  - Se generan en Entra ID (`azuread_application_password`) con rotación cada 30 días.
  - Se copian a **Key Vault** con `value_wo` (no se guardan en el estado para ese recurso).
  - Los scripts los leen desde Key Vault. ⚠️ El recurso `azuread_application_password` sí conserva el valor en el estado: usa el backend remoto si compartes el estado.
- **Configuración de APIM:** tenant y audiencia son **named values** de APIM. La subscription key sale como output `sensitive`.
- **Sin credenciales entre servicios:**
  - Container Apps → ACR: Managed Identity (sin admin user).
  - APIM → backend cerrado: Managed Identity.

## Costos y limpieza

APIM Developer cuesta aproximadamente USD 50/mes (se cobra por hora). Container Apps (2 apps de 1 réplica), ACR Basic, Key Vault y Log Analytics suman poco. Al terminar:

```bash
scripts/destroy.sh
```

## Estructura

```text
src/Orders.Api/          API .NET 10 (Minimal API), Dockerfile multi-stage, openapi/orders.json
infra/                   main.tf, variables.tf, outputs.tf, providers.tf, versions.tf, backend.tf.example
infra/modules/           apim (incluye diagnostics.tf), container-app, identity, keyvault, observability
infra/policies/          un .xml por política/demo + plantillas .tftpl (API y operación)
infra/environments/      demo.tfvars
demos/demo1..demo5/      README (pasos + plan B), .http, scripts, capturas/
scripts/                 deploy.sh, check.sh, get-token.sh, export-env.sh, destroy.sh, lib.sh
docs/                    alternativa con App Service
```

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| `Se requiere Terraform >= 1.11` | Actualiza Terraform (p. ej. `choco upgrade terraform` o `winget upgrade Hashicorp.Terraform`) |
| `az acr build` falla (ACR Tasks no disponible en la suscripción) | `BUILD_MODE=docker scripts/deploy.sh` |
| 403 de Key Vault al crear secrets o en `get-token.sh` | La asignación RBAC tarda en propagarse: espera 1-2 min y repite |
| 401 en la Demo 3 con un token válido | El token expiró (~60-90 min). `demos/demo3/test.sh` ya pide tokens nuevos; para los `.http`, ejecuta `scripts/export-env.sh` |
| La importación del OpenAPI falla por la versión `3.0.4` | Cambia `"openapi": "3.0.4"` por `"3.0.1"` en `orders.json` (el contenido es compatible) y vuelve a aplicar |
| El nombre de APIM/Key Vault está "ocupado" tras un destroy | Ambos quedan en soft-delete; el provider los purga al destruir (`features` en [providers.tf](infra/providers.tf)) |

## Ejecutar la API en local

```bash
dotnet run --project src/Orders.Api --urls http://localhost:5099
curl -i http://localhost:5099/orders          # muestra Server / X-Powered-By a propósito
dotnet build src/Orders.Api                   # regenera openapi/orders.json
```
