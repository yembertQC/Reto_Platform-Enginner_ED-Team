# 5 · Pipeline CD Despliegue

> 🎯 **Objetivo:** seguir el camino del código desde un `git push` hasta una URL pública en Azure o AWS.

**CD** (Continuous Delivery / Deployment) = cada cambio que llega a `main` se construye, se versiona y se despliega **automáticamente**.

---

## 🗂️ Los tres pipelines de CD

| Workflow | App | Se dispara con | Destino |
|----------|-----|----------------|---------|
| [`cd.yml`](../.github/workflows/cd.yml) | 🐍 Python | push a `main` con cambios en `src/`, o manual | `CLOUD_PROVIDER`: Azure Functions **o** Lambda |
| [`cd-go.yml`](../.github/workflows/cd-go.yml) | 🐹 Go | push a `main` con cambios en `src-go/`, o manual | `CLOUD_PROVIDER`: Container Apps **o** Lambda |
| [`cd-go-multicloud.yml`](../.github/workflows/cd-go-multicloud.yml) | 🐹 Go | Solo manual | Container Apps **y** Lambda a la vez |

Todos siguen la misma idea:

```mermaid
flowchart LR
    B["🏗️ Build<br/>empaquetar la app"] --> R["🏷️ Release<br/>versionar en GitHub"] --> D["🚀 Deploy<br/>subir a la nube"] --> S["✅ Smoke test<br/>¿responde?"]

    classDef s fill:#D6EAF8,stroke:#2874A6,color:#1a1a1a
    classDef ok fill:#D5F5E3,stroke:#1E8449,color:#1a1a1a
    class B,R,D s
    class S ok
```

---

## 🐍 `cd.yml` — CD Python

```mermaid
flowchart TB
    START["git push con cambios en src/"] --> V{"CLOUD_PROVIDER"}

    subgraph BUILD["🏗️ Job build"]
        V -->|"azure"| Z1["Instala dependencias<br/>y comprueba imports"]
        Z1 --> Z2["📦 Empaqueta src/ en<br/>function-app.zip<br/>(sin run.sh)"]
        V -->|"aws"| A1["Instala dependencias<br/>y comprueba imports"]
        A1 --> A2["📦 pip --target manylinux2014_x86_64<br/>+ app.py + run.sh<br/>→ lambda-python.zip"]
        A2 --> A3["📤 upload-artifact<br/>lambda-python"]
    end

    Z2 --> REL["🏷️ Job release<br/>v AAAAMMDD - sha"]
    A3 --> REL

    subgraph DEPLOY["🚀 Job deploy · environment production"]
        REL --> D{"CLOUD_PROVIDER"}
        D -->|"azure"| DZ["⚡ az functionapp deployment<br/>source config-zip<br/>--build-remote true"]
        D -->|"aws"| DA["λ download-artifact +<br/>scripts/deploy-lambda.sh<br/>python3.13 · handler run.sh"]
        DZ --> SM["✅ scripts/smoke-test.sh"]
        DA --> SM
    end

    SM --> SUM["📋 Resumen con la URL<br/>en el job summary"]

    classDef azure fill:#D4E6F1,stroke:#0078D4,color:#1a1a1a
    classDef aws fill:#FDEBD0,stroke:#FF9900,color:#1a1a1a
    classDef common fill:#F2F3F4,stroke:#777,color:#1a1a1a
    classDef dec fill:#F4ECF7,stroke:#7D3C98,color:#1a1a1a
    class Z1,Z2,DZ azure
    class A1,A2,A3,DA aws
    class START,REL,SM,SUM common
    class V,D dec
```

> 🧠 **Remote build:** a Azure se sube solo el código. Azure instala las dependencias de `requirements.txt` en sus servidores, con el sistema operativo correcto.

> 📦 **En AWS el zip lleva las dependencias dentro:** el job `build` las instala con `pip --target` pidiendo wheels de Linux x86_64 para Python 3.13 (`--platform manylinux2014_x86_64 --only-binary=:all:`), así el paquete sirve en Lambda aunque se haya construido en otra máquina. El zip pasa al job `deploy` como **artifact** de GitHub Actions; el job `build` ya no necesita credenciales de AWS.

---

## 🐹 `cd-go.yml` — CD Go

```mermaid
flowchart TB
    START["git push con cambios en src-go/"] --> T["🧪 go test -race"]

    subgraph BUILD["🏗️ Job build"]
        T --> V{"CLOUD_PROVIDER"}
        V -->|"azure"| Z1["🔑 Login en GHCR<br/>con GITHUB_TOKEN"]
        Z1 --> Z2["🐳 docker build<br/>linux/amd64 · un solo manifiesto"]
        Z2 --> Z3["📤 push a GHCR<br/>tag = sha corto"]
        V -->|"aws"| A1["🏗️ go build → bootstrap<br/>CGO_ENABLED=0 · linux/amd64"]
        A1 --> A2["📦 lambda-go.zip<br/>upload-artifact"]
    end

    Z3 --> REL["🏷️ release go-v AAAAMMDD - sha"]
    A2 --> REL
    REL --> D{"CLOUD_PROVIDER"}
    D -->|"azure"| DZ["🐳 scripts/deploy-containerapp.sh<br/>¿paquete GHCR público?"]
    D -->|"aws"| DA["λ download-artifact +<br/>scripts/deploy-lambda.sh<br/>provided.al2023 · handler bootstrap"]
    DZ --> SM["✅ smoke-test.sh"]
    DA --> SM

    classDef azure fill:#D4E6F1,stroke:#0078D4,color:#1a1a1a
    classDef aws fill:#FDEBD0,stroke:#FF9900,color:#1a1a1a
    classDef common fill:#F2F3F4,stroke:#777,color:#1a1a1a
    classDef dec fill:#F4ECF7,stroke:#7D3C98,color:#1a1a1a
    class Z1,Z2,Z3,DZ azure
    class A1,A2,DA aws
    class START,T,REL,SM common
    class V,D dec
```

- El job se llama `build` y su salida `artifact` es la referencia de la imagen (Azure) o el nombre del zip (AWS); aparece en la release y en el resumen.
- **Azure:** no hay registry en Azure. La imagen va a `ghcr.io/<owner-en-minúsculas>/<CONTAINER_NAME>-go:<sha_corto>`; el job tiene el permiso `packages: write` y se autentica con el `GITHUB_TOKEN`, sin secretos de la nube.
- **AWS:** no hay imagen ni ECR. El binario se llama `bootstrap` porque es lo que ejecuta el runtime `provided.al2023`.

> ⚠️ **Primera ejecución en Azure:** los paquetes de GHCR **nacen privados**, aunque el repo sea público, y Container Apps descarga la imagen **sin credenciales**. Antes de desplegar, `deploy-containerapp.sh` comprueba que la imagen se puede descargar de forma anónima; si no, el job falla con el mensaje *"el paquete de GHCR es privado"* y el enlace al paquete. Hazlo público **una sola vez** (*Package settings → Danger Zone → Change visibility → Public*) y relanza el workflow. Ver [7 · Configuración de GitHub](07-Configuracion-GitHub.md).

---

## 🌍 `cd-go-multicloud.yml` — Go en las dos nubes

Construye **una sola vez**, en un único job, los dos artefactos del mismo commit (la imagen para Azure y el zip para AWS) y despliega en paralelo:

```mermaid
flowchart TB
    BUILD["🏗️ build_once<br/>go test + imagen → GHCR<br/>+ lambda-go.zip"]

    BUILD --> REL["🏷️ release<br/>go-mc-v AAAAMMDD - sha"]

    REL --> DAZ["🐳 deploy_azure<br/>Container Apps por digest<br/>+ smoke test"]
    REL --> DAWS["λ deploy_aws<br/>Lambda desde el zip<br/>+ smoke test"]
    BUILD -.->|"imagen@sha256"| DAZ
    BUILD -.->|"artifact lambda-go"| DAWS

    DAZ --> SUM["📋 final_summary<br/>URLs de las dos nubes"]
    DAWS --> SUM

    classDef gh fill:#E3E3E3,stroke:#555,color:#1a1a1a
    classDef azure fill:#D4E6F1,stroke:#0078D4,color:#1a1a1a
    classDef aws fill:#FDEBD0,stroke:#FF9900,color:#1a1a1a
    class BUILD,REL,SUM gh
    class DAZ azure
    class DAWS aws
```

- Usa el **mismo paquete de GHCR** que `cd-go.yml` (`<CONTAINER_NAME>-go`), así que también tiene que ser público.
- Azure despliega la imagen por **digest** (`imagen@sha256:...`), una huella única del contenido: Container Apps ejecuta exactamente la imagen construida en ese run, aunque alguien mueva el tag.
- Ya no hay pasos de "promote" a ACR/ECR ni un job que borre la imagen de GHCR al final: Container Apps vuelve a descargarla cada vez que **escala desde cero**, así que borrarla rompería la app.

---

## 🧰 Los scripts de despliegue

Los tres CD reutilizan los scripts de [`scripts/`](../scripts). Son **idempotentes**: puedes ejecutarlos muchas veces y el resultado es el mismo (crean la primera vez y actualizan después).

### `deploy-lambda.sh`

```mermaid
flowchart TB
    IN["deploy-lambda.sh función zip rol<br/>runtime handler puerto"] --> L{"¿Existe la layer del<br/>Lambda Web Adapter?"}
    L -->|"No"| ERR["❌ Falla con mensaje<br/>(revisar LWA_LAYER_VERSION)"]
    L -->|"Sí"| Q1{"¿Existe la Lambda?<br/>¿de qué tipo?"}
    Q1 -->|"Image (antigua)"| DEL["♻️ delete-function<br/>se recrea como zip<br/>(cambia la Function URL)"]
    DEL --> C
    Q1 -->|"No existe"| C["🆕 create-function<br/>zip · runtime · layer LWA<br/>512 MB · 30 s"]
    Q1 -->|"Zip"| U["🔄 update-function-code (zip)<br/>+ update-function-configuration<br/>runtime · handler · layer · env"]
    C --> W1["⏳ esperar function-active"]
    U --> W2["⏳ esperar function-updated"]
    W1 --> Q2{"¿Tiene Function URL?"}
    W2 --> Q2
    Q2 -->|"No"| URL["🌐 create-function-url-config<br/>+ permisos públicos"]
    Q2 -->|"Sí"| OUT["📤 url= en GITHUB_OUTPUT"]
    URL --> OUT

    classDef q fill:#F4ECF7,stroke:#7D3C98,color:#1a1a1a
    classDef a fill:#FDEBD0,stroke:#FF9900,color:#1a1a1a
    classDef err fill:#FADBD8,stroke:#C0392B,color:#1a1a1a
    class L,Q1,Q2 q
    class C,U,DEL,W1,W2,URL,OUT,IN a
    class ERR err
```

Las dos Lambdas reciben las variables `PORT`, `AWS_LWA_PORT`, `AWS_LWA_READINESS_CHECK_PATH=/health` y `ENVIRONMENT=production`; la de Python además `AWS_LAMBDA_EXEC_WRAPPER=/opt/bootstrap` (ver [3 · Aplicaciones](03-Aplicaciones.md)).

### `deploy-containerapp.sh`

```mermaid
flowchart TB
    IN["deploy-containerapp.sh app rg env imagen puerto"] --> P{"¿La imagen de GHCR se<br/>descarga sin credenciales?"}
    P -->|"No (HTTP 401/403...)"| ERR["❌ Falla: paquete privado<br/>+ enlace para hacerlo público"]
    P -->|"Sí"| Q{"¿Existe la Container App?"}
    Q -->|"No"| C["🆕 containerapp create<br/>ingress externo · puerto<br/>0 a 10 réplicas · 0.25 vCPU<br/>sin credenciales de registry"]
    Q -->|"Sí"| U["🔄 containerapp update<br/>--image nueva"]
    C --> OUT["📤 url=https://fqdn"]
    U --> OUT

    classDef q fill:#F4ECF7,stroke:#7D3C98,color:#1a1a1a
    classDef z fill:#D4E6F1,stroke:#0078D4,color:#1a1a1a
    classDef err fill:#FADBD8,stroke:#C0392B,color:#1a1a1a
    class P,Q q
    class C,U,OUT,IN z
    class ERR err
```

### `smoke-test.sh`

Comprueba que `/health` contiene `healthy` y que `/` contiene `Hola ED Team`. Reintenta hasta 20 veces cada 10 segundos para dar tiempo al **cold start**.

---

## 🛑 Aprobación manual: environment `production`

Los jobs `deploy` de `cd.yml` y `cd-go.yml` usan el environment **`production`**. Si configuras revisores obligatorios, el pipeline **se pausa** hasta que alguien apruebe:

```mermaid
sequenceDiagram
    actor Dev as 👩‍💻 Desarrollador
    participant GA as ⚙️ GitHub Actions
    actor Rev as 🧑‍⚖️ Revisor
    participant Cloud as ☁️ Nube

    Dev->>GA: git push a main
    GA->>GA: build + release
    GA->>Rev: ⏸️ Deploy a production pendiente de aprobación
    Rev->>GA: ✅ Approve and deploy
    GA->>Cloud: Despliega
    Cloud-->>GA: URL pública
    GA->>GA: Smoke test
    GA-->>Dev: Resumen con la URL
```

---

## 📋 ¿Dónde veo la URL de mi app?

Al terminar, cada pipeline escribe un **job summary** (Actions → la ejecución → Summary) con una tabla de URLs:

| Endpoint | URL |
|----------|-----|
| App | `https://…/` |
| Health check | `https://…/health` |

➡️ Siguiente: [6 · Infraestructura](06-Infraestructura.md)
