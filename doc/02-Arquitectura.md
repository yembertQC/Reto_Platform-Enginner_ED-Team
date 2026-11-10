# 2 · Arquitectura

> 🎯 **Objetivo:** ver todas las piezas del sistema y cómo se conectan, de GitHub a la nube y de la nube al usuario.

---

## 🧩 Vista general

```mermaid
flowchart TB
    subgraph GH["🐙 GitHub"]
        REPO["📁 Repositorio<br/>src · src-go · scripts · doc"]
        ACT["⚙️ GitHub Actions<br/>CI · CD · Infra · Wiki"]
        REL["🏷️ Releases"]
        GHCR["📦 GHCR<br/>imagen Go (paquete público)"]
        WIKI["📖 Wiki"]
    end

    subgraph AZ["☁️ Azure · Resource Group"]
        subgraph CAE["Container Apps Environment"]
            ACA["🐳 Container App Go<br/>0 a 10 réplicas"]
        end
        FUNC["⚡ Function App Python<br/>Flex Consumption"]
        ST["💾 Storage Account"]
    end

    subgraph AWS["☁️ AWS"]
        LPY["λ Lambda Python<br/>zip · python3.13"]
        LGO["λ Lambda Go<br/>zip · provided.al2023"]
        LWA["🔌 Layer<br/>Lambda Web Adapter"]
        IAM["🔑 Rol IAM<br/>de ejecución"]
    end

    USER["🌍 Usuario"]

    REPO --> ACT
    ACT --> REL
    ACT --> WIKI
    ACT -->|"zip"| FUNC
    ACT -->|"imagen Go"| GHCR
    ACT -->|"zip"| LPY & LGO

    GHCR -->|"pull anónimo"| ACA
    LWA -.-> LPY & LGO
    IAM -.-> LPY & LGO
    FUNC --- ST

    USER -->|"HTTPS"| FUNC
    USER -->|"HTTPS"| ACA
    USER -->|"HTTPS · Function URL"| LPY
    USER -->|"HTTPS · Function URL"| LGO

    classDef gh fill:#E3E3E3,stroke:#555,color:#1a1a1a
    classDef azure fill:#D4E6F1,stroke:#0078D4,color:#1a1a1a
    classDef aws fill:#FDEBD0,stroke:#FF9900,color:#1a1a1a
    classDef user fill:#D5F5E3,stroke:#1E8449,color:#1a1a1a
    class REPO,ACT,REL,GHCR,WIKI gh
    class ACA,FUNC,ST azure
    class LPY,LGO,LWA,IAM aws
    class USER user
```

| App | Azure | AWS |
|-----|-------|-----|
| 🐍 Python | ⚡ Azure Functions: código en zip, Flask montado con `WsgiFunctionApp` | λ Lambda: zip (runtime `python3.13`) + Lambda Web Adapter como layer |
| 🐹 Go | 🐳 Container Apps: imagen desde GHCR | λ Lambda: zip con el binario `bootstrap` (runtime `provided.al2023`) + Lambda Web Adapter como layer |

> 🧠 **No hay registry en la nube** (ni ACR en Azure ni ECR en AWS). La única imagen que se despliega es la de Go en Container Apps, y vive en **GitHub Container Registry (GHCR)**: el CD la sube con el `GITHUB_TOKEN` y Container Apps la descarga sin credenciales, por eso el paquete debe ser **público** (ver [7 · Configuración de GitHub](07-Configuracion-GitHub.md)). Lambda recibe paquetes **zip**.

---

## 🔀 ¿A qué nube despliega cada pipeline?

```mermaid
flowchart LR
    PUSH["git push a main"]
    PUSH -->|"cambios en src/"| CDPY["cd.yml"]
    PUSH -->|"cambios en src-go/"| CDGO["cd-go.yml"]
    MANUAL["▶️ Ejecución manual"] --> MC["cd-go-multicloud.yml"]

    VAR{"Variable<br/>CLOUD_PROVIDER"}
    CDPY --> VAR
    CDGO --> VAR

    VAR -->|"azure"| AZPY["⚡ Functions (Python)<br/>🐳 Container Apps (Go)"]
    VAR -->|"aws"| AWSX["λ Lambda (Python)<br/>λ Lambda (Go)"]
    MC -->|"siempre ambas"| BOTH["🐳 Container Apps (Go)<br/>+ λ Lambda (Go)"]

    classDef trig fill:#FFE8A3,stroke:#B58900,color:#1a1a1a
    classDef wf fill:#D6EAF8,stroke:#2874A6,color:#1a1a1a
    classDef dec fill:#F4ECF7,stroke:#7D3C98,color:#1a1a1a
    classDef dest fill:#D5F5E3,stroke:#1E8449,color:#1a1a1a
    class PUSH,MANUAL trig
    class CDPY,CDGO,MC wf
    class VAR dec
    class AZPY,AWSX,BOTH dest
```

- `cd.yml` y `cd-go.yml` despliegan a **una sola nube**, la que diga la variable `CLOUD_PROVIDER`.
- `cd-go-multicloud.yml` despliega la app Go en **las dos a la vez**.

---

## 🌐 Cómo viaja una petición

### Azure

```mermaid
sequenceDiagram
    actor U as 🌍 Usuario
    participant F as ⚡ Azure Functions
    participant W as 🧩 WsgiFunctionApp
    participant FL as 🐍 Flask (app.py)
    participant CA as 🐳 Container App
    participant G as 🐹 Go (main.go)

    U->>F: GET https://func-xxx.azurewebsites.net/health
    F->>W: Disparador HTTP (ruta catch-all)
    W->>FL: Llamada WSGI a /health
    FL-->>U: 200 healthy

    U->>CA: GET https://app-go.xxx.azurecontainerapps.io/
    CA->>G: HTTP al puerto 8080
    G-->>U: 200 Hola ED Team
```

### AWS

```mermaid
sequenceDiagram
    actor U as 🌍 Usuario
    participant URL as 🔗 Function URL
    participant L as λ Lambda
    participant A as 🔌 Lambda Web Adapter
    participant APP as 📦 Tu app (Gunicorn o Go)

    U->>URL: GET https://xxxx.lambda-url.us-east-1.on.aws/health
    URL->>L: Evento de invocación
    L->>A: Entrega el evento al adapter (layer)
    A->>APP: Lo convierte en HTTP normal a localhost
    APP-->>A: 200 healthy
    A-->>L: Lo convierte en respuesta de Lambda
    L-->>U: 200 healthy
```

> 🔎 El **Lambda Web Adapter** es la pieza clave en AWS: permite usar una app web normal dentro de Lambda sin reescribirla. Se explica en [3 · Aplicaciones](03-Aplicaciones.md).

---

## 🏷️ Nombres de los recursos

Todos los nombres salen de **variables de GitHub** (ver [7 · Configuración de GitHub](07-Configuracion-GitHub.md)):

| Recurso | Nombre | Ejemplo |
|---------|--------|---------|
| Container Apps Environment | `CONTAINERAPP_ENV_NAME` | `cae-edteam` |
| Container App Go | `<CONTAINER_NAME>-go` | `ed-team-app-go` |
| Function App Python | `FUNCTION_APP_NAME` | `func-edteam-app` |
| Storage Account | `STORAGE_ACCOUNT_NAME` | `stedteamfunc` |
| Paquete GHCR de la imagen Go | `<CONTAINER_NAME>-go` | `ed-team-app-go` |
| Lambda Python | `LAMBDA_NAME` | `ed-team-app` |
| Lambda Go | `<LAMBDA_NAME>-go` | `ed-team-app-go` |
| Rol IAM de Lambda | `<LAMBDA_NAME>-lambda-role` | `ed-team-app-lambda-role` |

### Artefactos y releases

| Artefacto | Formato |
|-----------|---------|
| Imagen Go en Azure (GHCR) | `ghcr.io/<owner-en-minúsculas>/<CONTAINER_NAME>-go:<sha_corto>` (el multi-cloud despliega por digest `@sha256:...`) |
| Paquete Python para Azure Functions | `function-app.zip` (artifact del run) |
| Paquete Python para Lambda | `lambda-python.zip` (artifact del run) |
| Paquete Go para Lambda | `lambda-go.zip` con el binario `bootstrap` (artifact del run) |
| Release Python | `v<AAAAMMDD>-<sha_corto>` |
| Release Go | `go-v<AAAAMMDD>-<sha_corto>` |
| Release Go multi-cloud | `go-mc-v<AAAAMMDD>-<sha_corto>` |

---

## 📂 Mapa del repositorio

```mermaid
flowchart LR
    ROOT["📁 repo"]
    ROOT --> SRC["📁 src/<br/>app Python"]
    ROOT --> SRCGO["📁 src-go/<br/>app Go"]
    ROOT --> SCR["📁 scripts/<br/>deploy-lambda.sh<br/>deploy-containerapp.sh<br/>smoke-test.sh<br/>build-wiki.sh"]
    ROOT --> WF["📁 .github/workflows/<br/>8 pipelines"]
    ROOT --> DOC["📁 doc/<br/>esta wiki"]

    SRC --> S1["app.py · function_app.py<br/>host.json · requirements.txt<br/>run.sh · Dockerfile"]
    SRCGO --> S2["main.go · main_test.go<br/>go.mod · Dockerfile"]

    classDef dir fill:#FFF5D6,stroke:#B58900,color:#1a1a1a
    classDef file fill:#F2F3F4,stroke:#777,color:#1a1a1a
    class ROOT,SRC,SRCGO,SCR,WF,DOC dir
    class S1,S2 file
```

➡️ Siguiente: [3 · Aplicaciones](03-Aplicaciones.md)
