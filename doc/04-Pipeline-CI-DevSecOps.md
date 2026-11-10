# 4 · Pipeline CI DevSecOps

> 🎯 **Objetivo:** entender cómo se revisa automáticamente la **calidad y la seguridad** del código antes de desplegarlo.

**DevSecOps** = meter la **seguridad** dentro del ciclo de desarrollo, de forma automática, en vez de dejarla para el final.

> 🛠️ **En clave de plataforma:** este CI es la capa de **seguridad por defecto** del *golden path* ([página 0](00-Ingenieria-de-Plataforma.md)). Ningún equipo tiene que configurar CodeQL ni Grype: quien sigue el golden path recibe los escaneos incluidos.

---

## 🔁 ¿Cuándo se ejecuta?

| Workflow | Se dispara con | Solo si cambian archivos en |
|----------|----------------|------------------------------|
| [`ci.yml`](../.github/workflows/ci.yml) — CI Python | push o Pull Request a `main`, o manual | `src/**` |
| [`ci-go.yml`](../.github/workflows/ci-go.yml) — CI Go | push o Pull Request a `main`, o manual | `src-go/**` |

```mermaid
flowchart LR
    PR["🔀 Pull Request<br/>o push a main"]

    subgraph CI["🛡️ CI DevSecOps (en paralelo)"]
        TEST["🧪 Tests<br/>go test -race<br/>(solo Go)"]
        SAST["🔍 SAST<br/>CodeQL<br/>analiza el código"]
        SCA["📚 SCA<br/>dependency-review<br/>analiza dependencias<br/>(solo en PRs)"]
        SCAN["🐳 Container Scan<br/>Grype<br/>analiza la imagen"]
    end

    SEC["🔐 GitHub → Security<br/>Code scanning alerts"]
    COMMENT["💬 Comentario<br/>en el Pull Request"]

    PR --> TEST & SAST & SCA & SCAN
    SAST --> SEC
    SCAN --> SEC
    SCA --> COMMENT

    classDef trig fill:#FFE8A3,stroke:#B58900,color:#1a1a1a
    classDef job fill:#D6EAF8,stroke:#2874A6,color:#1a1a1a
    classDef out fill:#D5F5E3,stroke:#1E8449,color:#1a1a1a
    class PR trig
    class TEST,SAST,SCA,SCAN job
    class SEC,COMMENT out
```

---

## 🔍 Las tres capas de seguridad

```mermaid
flowchart TB
    subgraph L1["1️⃣ Tu código"]
        C["main.go · app.py"]
    end
    subgraph L2["2️⃣ Código de terceros"]
        D["Flask · gunicorn · lib/pq<br/>azure-functions"]
    end
    subgraph L3["3️⃣ La imagen completa"]
        I["Sistema operativo base<br/>+ paquetes + tu app"]
    end

    C -->|"lo revisa"| SAST["🔍 SAST · CodeQL"]
    D -->|"lo revisa"| SCA["📚 SCA · dependency-review"]
    I -->|"lo revisa"| CS["🐳 Container Scan · Grype"]

    classDef layer fill:#F2F3F4,stroke:#777,color:#1a1a1a
    classDef tool fill:#D6EAF8,stroke:#2874A6,color:#1a1a1a
    class C,D,I layer
    class SAST,SCA,CS tool
```

| Capa | Herramienta | Qué busca | Ejemplo de hallazgo |
|------|-------------|-----------|---------------------|
| **SAST** (Static Application Security Testing) | GitHub **CodeQL**, queries `security-extended` | Errores de seguridad en **tu código** sin ejecutarlo | SQL injection en `/search` |
| **SCA** (Software Composition Analysis) | `actions/dependency-review-action` | Dependencias con **vulnerabilidades conocidas (CVE)** que añade el PR | Una versión vieja de Flask con CVE |
| **Container Scan** | **Anchore Grype** (`anchore/scan-action`) | Vulnerabilidades en la **imagen Docker** (SO base + paquetes) | `openssl` desactualizado en la imagen base |

---

## ⚙️ Jobs en detalle

| Job | Cuándo | Configuración clave |
|-----|--------|---------------------|
| `test` (solo Go) | Siempre | `go test -v -race ./...` — `-race` detecta condiciones de carrera |
| `SAST` | Siempre | Python: `build-mode: none` · Go: `autobuild` · sube resultados a GitHub Security |
| `SCA` | Solo en **Pull Requests** | `warn-only: true` (avisa pero no bloquea) · comenta el resumen en el PR |
| `Container_security` | Siempre | Construye el Dockerfile · `severity-cutoff: high` · `fail-build: false` · sube SARIF |

> 📝 **SARIF** es un formato estándar de resultados de análisis. GitHub lo entiende y muestra cada hallazgo en **Security → Code scanning** con el archivo y la línea.

### ¿Por qué no se rompe el pipeline si hay vulnerabilidades?

`warn-only: true` y `fail-build: false` están puestos **a propósito** para el curso: así puedes ver los hallazgos sin que el pipeline quede bloqueado. En un proyecto real normalmente se activaría el bloqueo:

```yaml
# Endurecer el Container Scan
fail-build: true
severity-cutoff: high

# Endurecer el SCA
fail-on-severity: high
```

---

## 👀 Dónde ver los resultados

| Resultado | Dónde |
|-----------|-------|
| Alertas de CodeQL y Grype | **Repositorio → Security → Code scanning** |
| Resumen de dependencias | Comentario automático en el **Pull Request** |
| Logs de cada job | **Actions → (ejecución) → (job)** |

➡️ Siguiente: [5 · Pipeline CD Despliegue](05-Pipeline-CD-Despliegue.md)
