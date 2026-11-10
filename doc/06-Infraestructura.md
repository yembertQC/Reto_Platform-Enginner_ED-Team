# 6 · Infraestructura

> 🎯 **Objetivo:** saber qué recursos se crean en cada nube, quién los crea y cómo se borran para no gastar dinero.

---

## ▶️ Los workflows de infraestructura

| Workflow | Cómo se lanza | Parámetros |
|----------|---------------|------------|
| [`infraestructure.yml`](../.github/workflows/infraestructure.yml) | Manual (Actions → *Provision Infrastructure (Serverless)* → Run workflow) | `cloud_provider`: `azure` / `aws` · `action`: `create` / `destroy` |
| [`infra-multicloud.yml`](../.github/workflows/infra-multicloud.yml) | Manual | `action`: `create` / `destroy`. Lanza `infraestructure.yml` para **Azure y AWS** a la vez |

```mermaid
flowchart LR
    YOU["👩‍💻 Run workflow"]
    YOU --> MC["infra-multicloud.yml<br/>create o destroy"]
    YOU --> ONE["infraestructure.yml<br/>nube + acción"]
    MC -->|"gh workflow run<br/>cloud = azure"| ONE
    MC -->|"gh workflow run<br/>cloud = aws"| ONE

    ONE --> AZC["☁️ azure-create"]
    ONE --> AZD["🗑️ azure-destroy"]
    ONE --> AWC["☁️ aws-create"]
    ONE --> AWD["🗑️ aws-destroy"]

    classDef you fill:#FFE8A3,stroke:#B58900,color:#1a1a1a
    classDef wf fill:#E3E3E3,stroke:#555,color:#1a1a1a
    classDef azure fill:#D4E6F1,stroke:#0078D4,color:#1a1a1a
    classDef aws fill:#FDEBD0,stroke:#FF9900,color:#1a1a1a
    class YOU you
    class MC,ONE wf
    class AZC,AZD azure
    class AWC,AWD aws
```

---

## 🤝 ¿Quién crea cada recurso?

Hay recursos que **no se pueden crear sin el artefacto ya construido** (una Container App necesita saber qué imagen ejecutar y una Lambda, qué zip). Por eso el trabajo se reparte:

```mermaid
flowchart TB
    subgraph INFRA["🏗️ infraestructure.yml (una vez)"]
        I2["🌐 Container Apps Environment"]
        I3["💾 Storage Account"]
        I4["⚡ Function App vacía"]
        I6["🔑 Rol IAM de Lambda"]
    end

    subgraph CD["🚀 Pipelines CD (en cada despliegue)"]
        G1["📦 Imagen Go en GHCR<br/>(se publica en cada deploy a Azure)"]
        C1["🐳 Container App Go<br/>(se crea en el primer deploy)"]
        C2["λ Lambda Python + Function URL<br/>(se crea en el primer deploy)"]
        C3["λ Lambda Go + Function URL<br/>(se crea en el primer deploy)"]
        C4["⚡ Código Python<br/>(se sube en cada deploy)"]
    end

    G1 --> C1
    I2 --> C1
    I4 --> C4
    I6 --> C2 & C3

    classDef infra fill:#FFF5D6,stroke:#B58900,color:#1a1a1a
    classDef cd fill:#D5F5E3,stroke:#1E8449,color:#1a1a1a
    class I2,I3,I4,I6 infra
    class G1,C1,C2,C3,C4 cd
```

> 🧠 **No se crea ningún registry de contenedores** (ni ACR ni ECR): la imagen de Go vive en GitHub Container Registry (GHCR), que no hay que aprovisionar, y las Lambdas reciben paquetes zip.

---

## ☁️ Azure

```mermaid
flowchart TB
    GHCR["📦 GHCR (GitHub)<br/>ghcr.io/owner/CONTAINER_NAME-go<br/>paquete público"]
    subgraph RG["📦 Resource Group (ya existe, NO se crea ni se borra)"]
        subgraph ENV["🌐 Container Apps Environment<br/>CONTAINERAPP_ENV_NAME"]
            APP["🐳 Container App<br/>CONTAINER_NAME-go"]
        end
        FUNC["⚡ Function App<br/>FUNCTION_APP_NAME<br/>Flex Consumption · Python 3.13"]
        PLAN["📋 Plan Flex Consumption<br/>(se crea con la Function App)"]
        ST["💾 Storage Account<br/>STORAGE_ACCOUNT_NAME"]
    end

    GHCR -->|"pull anónimo<br/>(sin credenciales)"| APP
    FUNC --- PLAN
    FUNC -->|"guarda paquetes<br/>y estado"| ST

    classDef gh fill:#E3E3E3,stroke:#555,color:#1a1a1a
    classDef azure fill:#D4E6F1,stroke:#0078D4,color:#1a1a1a
    class GHCR gh
    class APP,FUNC,PLAN,ST azure
```

| Paso de `azure-create` | Comando principal |
|------------------------|-------------------|
| 1. Verifica que existe el Resource Group | `az group show` |
| 2. Registra los resource providers necesarios | `az provider register` (`Microsoft.App`, `Microsoft.Web`, `Microsoft.Storage`) |
| 3. Crea el entorno de Container Apps | `az containerapp env create --logs-destination none` |
| 4. Crea la cuenta de almacenamiento | `az storage account create --sku Standard_LRS` |
| 5. Crea la Function App | `az functionapp create --flexconsumption-location … --runtime python` |

> 📌 El *summary* de `azure-create` recuerda el paso manual que queda: tras el primer CD de Go, hacer **público** el paquete `<CONTAINER_NAME>-go` de GHCR (una sola vez). Ver [7 · Configuración de GitHub](07-Configuracion-GitHub.md).

> 💡 Se desactivan **Log Analytics** y **Application Insights** para que el entorno sea barato y el `destroy` no deje recursos sueltos. Para el curso basta con los logs en streaming (ver [9 · Operación](09-Operacion-y-Troubleshooting.md)).

`azure-destroy` borra, en orden: Container App → Environment → Function App y su plan → Storage Account. **El Resource Group se conserva.** Las imágenes de GHCR **tampoco se borran**: si quieres eliminarlas, hazlo desde la pestaña *Packages* de GitHub.

---

## ☁️ AWS

```mermaid
flowchart TB
    subgraph REG["🌎 Región AWS_REGION"]
        ROLE["🔑 IAM Role<br/>LAMBDA_NAME-lambda-role<br/>AWSLambdaBasicExecutionRole"]
        LWA["🔌 Layer pública de AWS<br/>LambdaAdapterLayerX86"]
        L1["λ Lambda Python<br/>LAMBDA_NAME · zip · python3.13<br/>512 MB · 30 s"]
        L2["λ Lambda Go<br/>LAMBDA_NAME-go · zip · provided.al2023<br/>512 MB · 30 s"]
        U1["🔗 Function URL"]
        U2["🔗 Function URL"]
        CW["📜 CloudWatch Logs<br/>/aws/lambda/..."]
    end

    ROLE -.->|"asume el rol"| L1 & L2
    LWA -.->|"layer"| L1 & L2
    U1 --> L1
    U2 --> L2
    L1 & L2 -->|"escriben logs"| CW

    classDef aws fill:#FDEBD0,stroke:#FF9900,color:#1a1a1a
    class ROLE,LWA,L1,L2,U1,U2,CW aws
```

| Paso de `aws-create` | Comando principal |
|----------------------|-------------------|
| 1. Crea el rol que asumirán las Lambdas | `aws iam create-role` + `attach-role-policy AWSLambdaBasicExecutionRole` |

Las Lambdas (con su paquete zip, la layer del Lambda Web Adapter y su Function URL) las crea el primer CD con [`deploy-lambda.sh`](../scripts/deploy-lambda.sh). La layer no se crea: la publica AWS en su cuenta `753240598075` y la función solo la referencia.

`aws-destroy` borra: las dos Lambdas (y con ellas sus Function URLs) → sus log groups → el rol IAM.

> 🧠 **Mínimo privilegio:** el rol de las Lambdas solo puede **escribir logs**. Si tu app no necesita nada más, no le des nada más.

---

## 💰 Costes y limpieza

| Recurso | ¿Cobra en reposo? |
|---------|-------------------|
| Azure Functions Flex Consumption | No (escala a cero) |
| Container Apps con `minReplicas 0` | No (escala a cero) |
| AWS Lambda | No |
| Storage Account | Céntimos por lo almacenado |
| GHCR (paquete público) | No: GitHub Packages es gratuito para paquetes públicos |

> ✅ **Buena práctica del curso:** cuando termines una sesión, ejecuta `infra-multicloud.yml` con `destroy`.

➡️ Siguiente: [7 · Configuración de GitHub](07-Configuracion-GitHub.md)
