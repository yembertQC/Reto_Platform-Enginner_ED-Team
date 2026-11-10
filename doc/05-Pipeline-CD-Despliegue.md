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
        Z1 --> Z2["📦 Empaqueta src/ en<br/>function-app.zip"]
        V -->|"aws"| A1["Instala dependencias<br/>y comprueba imports"]
        A1 --> A2["🐳 docker build src/Dockerfile"]
        A2 --> A3["📤 push a ECR<br/>tag = sha corto"]
    end

    Z2 --> REL["🏷️ Job release<br/>v AAAAMMDD - sha"]
    A3 --> REL

    subgraph DEPLOY["🚀 Job deploy · environment production"]
        REL --> D{"CLOUD_PROVIDER"}
        D -->|"azure"| DZ["⚡ az functionapp deployment<br/>source config-zip<br/>--build-remote true"]
        D -->|"aws"| DA["λ scripts/deploy-lambda.sh"]
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

---

## 🐹 `cd-go.yml` — CD Go

```mermaid
flowchart TB
    START["git push con cambios en src-go/"] --> T["🧪 go test -race"]
    T --> V{"CLOUD_PROVIDER"}

    V -->|"azure"| Z1["🔑 Login en ACR"]
    V -->|"aws"| A1["🔑 Login en ECR"]
    Z1 --> BLD["🐳 docker build<br/>linux/amd64 · sin attestations"]
    A1 --> BLD
    BLD --> PUSH["📤 push de la imagen<br/>tag = sha corto"]
    PUSH --> REL["🏷️ release go-v AAAAMMDD - sha"]
    REL --> D{"CLOUD_PROVIDER"}
    D -->|"azure"| DZ["🐳 scripts/deploy-containerapp.sh"]
    D -->|"aws"| DA["λ scripts/deploy-lambda.sh"]
    DZ --> SM["✅ smoke-test.sh"]
    DA --> SM

    classDef azure fill:#D4E6F1,stroke:#0078D4,color:#1a1a1a
    classDef aws fill:#FDEBD0,stroke:#FF9900,color:#1a1a1a
    classDef common fill:#F2F3F4,stroke:#777,color:#1a1a1a
    classDef dec fill:#F4ECF7,stroke:#7D3C98,color:#1a1a1a
    class Z1,DZ azure
    class A1,DA aws
    class START,T,BLD,PUSH,REL,SM common
    class V,D dec
```

---

## 🌍 `cd-go-multicloud.yml` — Go en las dos nubes

Construye la imagen **una sola vez** y lleva **exactamente la misma** a Azure y a AWS:

```mermaid
flowchart TB
    BUILD["🏗️ build_once<br/>go test + imagen → GHCR"]

    BUILD --> PAZ["📤 promote_azure<br/>GHCR → ACR"]
    BUILD --> PAWS["📤 promote_aws<br/>GHCR → ECR"]
    BUILD --> REL["🏷️ release<br/>go-mc-v AAAAMMDD - sha"]

    PAZ --> DAZ["🐳 deploy_azure<br/>Container Apps + smoke test"]
    PAWS --> DAWS["λ deploy_aws<br/>Lambda + smoke test"]
    REL --> DAZ
    REL --> DAWS

    DAZ --> CLEAN["🧹 cleanup_ghcr<br/>borra la imagen temporal"]
    DAWS --> CLEAN
    CLEAN --> SUM["📋 final_summary<br/>URLs de las dos nubes"]

    classDef gh fill:#E3E3E3,stroke:#555,color:#1a1a1a
    classDef azure fill:#D4E6F1,stroke:#0078D4,color:#1a1a1a
    classDef aws fill:#FDEBD0,stroke:#FF9900,color:#1a1a1a
    class BUILD,REL,CLEAN,SUM gh
    class PAZ,DAZ azure
    class PAWS,DAWS aws
```

> 🔐 La imagen se promueve por **digest** (`imagen@sha256:...`), una huella única del contenido. Así hay garantía de que Azure y AWS ejecutan **el mismo binario, byte a byte**.

---

## 🧰 Los scripts de despliegue

Los tres CD reutilizan los scripts de [`scripts/`](../scripts). Son **idempotentes**: puedes ejecutarlos muchas veces y el resultado es el mismo (crean la primera vez y actualizan después).

### `deploy-lambda.sh`

```mermaid
flowchart TB
    IN["deploy-lambda.sh función imagen rol"] --> Q1{"¿Existe la Lambda?"}
    Q1 -->|"No"| C["🆕 create-function<br/>imagen ECR · 512 MB · 30 s"]
    Q1 -->|"Sí"| U["🔄 update-function-code<br/>con la nueva imagen"]
    C --> W1["⏳ esperar function-active"]
    U --> W2["⏳ esperar function-updated"]
    W1 --> Q2{"¿Tiene Function URL?"}
    W2 --> Q2
    Q2 -->|"No"| URL["🌐 create-function-url-config<br/>+ permisos públicos"]
    Q2 -->|"Sí"| OUT["📤 url= en GITHUB_OUTPUT"]
    URL --> OUT

    classDef q fill:#F4ECF7,stroke:#7D3C98,color:#1a1a1a
    classDef a fill:#FDEBD0,stroke:#FF9900,color:#1a1a1a
    class Q1,Q2 q
    class C,U,W1,W2,URL,OUT,IN a
```

### `deploy-containerapp.sh`

```mermaid
flowchart TB
    IN["deploy-containerapp.sh app rg env imagen acr puerto"] --> Q{"¿Existe la Container App?"}
    Q -->|"No"| C["🆕 containerapp create<br/>ingress externo · puerto<br/>0 a 10 réplicas · 0.25 vCPU<br/>credenciales del ACR"]
    Q -->|"Sí"| U["🔄 containerapp update<br/>--image nueva"]
    C --> OUT["📤 url=https://fqdn"]
    U --> OUT

    classDef q fill:#F4ECF7,stroke:#7D3C98,color:#1a1a1a
    classDef z fill:#D4E6F1,stroke:#0078D4,color:#1a1a1a
    class Q q
    class C,U,OUT,IN z
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
