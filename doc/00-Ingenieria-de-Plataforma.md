# 0 · ¿Qué es Ingeniería de Plataforma?

> 🎯 **Objetivo:** entender qué es la Ingeniería de Plataforma, qué problema resuelve y por qué este proyecto es, en pequeño, una plataforma.

---

## 🤔 El problema

Imagina una empresa con 20 equipos de desarrollo. Cada equipo, para poner su app en producción, tiene que aprender a la vez:

Docker · Kubernetes o serverless · Azure **y** AWS · redes · certificados · CI/CD · escáneres de seguridad · secretos · logs · costes...

```mermaid
flowchart TB
    subgraph SIN["😵 Sin plataforma: cada equipo se lo monta solo"]
        direction LR
        E1["👩‍💻 Equipo A<br/>su pipeline<br/>sus scripts<br/>su forma de desplegar"]
        E2["👨‍💻 Equipo B<br/>otro pipeline<br/>otros scripts<br/>otra forma"]
        E3["🧑‍💻 Equipo C<br/>copia-pega de A<br/>pero desactualizado"]
    end
    SIN --> P1["🔁 Trabajo repetido 20 veces"]
    SIN --> P2["🧠 Sobrecarga cognitiva"]
    SIN --> P3["🔓 Seguridad desigual"]
    SIN --> P4["🐢 Entregas lentas"]

    classDef team fill:#FADBD8,stroke:#C0392B,color:#1a1a1a
    classDef pain fill:#F2F3F4,stroke:#777,color:#1a1a1a
    class E1,E2,E3 team
    class P1,P2,P3,P4 pain
```

A esto se le llama **carga cognitiva**: todo lo que un desarrollador tiene que tener en la cabeza que **no es** su producto.

---

## 💡 La solución: una plataforma interna

La **Ingeniería de Plataforma** (*Platform Engineering*) es la disciplina de **diseñar, construir y mantener una Plataforma Interna de Desarrollo** (*IDP, Internal Developer Platform*) que los equipos usan en **autoservicio** para construir, desplegar y operar sus aplicaciones.

> 🧠 **En una frase:** el equipo de plataforma convierte lo difícil y repetido en un **camino fácil, seguro y reutilizable**, y lo trata como un **producto** cuyos clientes son los desarrolladores.

```mermaid
flowchart TB
    subgraph DEVS["👩‍💻 Equipos de producto: se centran en SU app"]
        direction LR
        A["Equipo A"]
        B["Equipo B"]
        C["Equipo C"]
    end

    subgraph IDP["🛠️ Plataforma Interna (IDP): autoservicio"]
        direction LR
        G1["🛤️ Golden paths<br/>pipelines listos"]
        G2["🏗️ Infra con un clic<br/>create / destroy"]
        G3["🛡️ Seguridad incluida<br/>escáneres, secretos"]
        G4["📖 Docs y plantillas"]
        G5["📊 Observabilidad"]
    end

    subgraph CLOUD["☁️ Nubes y herramientas"]
        direction LR
        AZ["Azure"]
        AW["AWS"]
        GH["GitHub"]
    end

    PT["👷 Equipo de plataforma<br/>construye y mejora la IDP<br/>como un producto"]

    DEVS -->|"usan sin tickets"| IDP
    IDP --> CLOUD
    PT -->|"mantiene"| IDP
    DEVS -.->|"feedback"| PT

    classDef dev fill:#D5F5E3,stroke:#1E8449,color:#1a1a1a
    classDef idp fill:#D6EAF8,stroke:#2874A6,color:#1a1a1a
    classDef cloud fill:#F2F3F4,stroke:#777,color:#1a1a1a
    classDef pt fill:#FFE8A3,stroke:#B58900,color:#1a1a1a
    class A,B,C dev
    class G1,G2,G3,G4,G5 idp
    class AZ,AW,GH cloud
    class PT pt
```

---

## 🧱 Conceptos clave

| Concepto | Qué significa | Ejemplo en este repo |
|----------|---------------|----------------------|
| **Plataforma como producto** | La plataforma tiene usuarios (los devs), se diseña escuchándolos, tiene documentación y se mejora por versiones | Esta wiki, el laboratorio, el job summary con la URL |
| **Autoservicio** | El dev consigue lo que necesita **sin abrir un ticket** ni esperar a otra persona | `infraestructure.yml` → *Run workflow* → infra creada |
| **Golden path** (camino dorado) | La forma recomendada, ya resuelta y segura, de hacer algo. Es **opcional pero tan cómoda** que todos la eligen | Push a `src-go/` → tests, escaneo, build, deploy y smoke test sin hacer nada más |
| **Abstracción** | Ocultar detalles que el dev no necesita, sin impedir verlos | `CLOUD_PROVIDER=azure` o `aws`: el dev no necesita saber los comandos de cada nube |
| **Guardrails** (barandillas) | Controles automáticos que evitan errores graves sin frenar | CodeQL, Grype, environment `production` con aprobación |
| **Reutilización** | Resolver una vez y usarlo en todas partes | `scripts/deploy-lambda.sh` lo usan 3 pipelines |
| **Thinnest Viable Platform** | Empezar con la plataforma **más pequeña que aporte valor** y crecer según la demanda | Este repo: unos pocos workflows y scripts, no un portal gigante |

### 🛤️ Golden path vs camino libre

```mermaid
flowchart LR
    START["💡 Tengo una app nueva"]
    START -->|"🛤️ Golden path"| GP1["Copio la estructura del repo"] --> GP2["git push"] --> GP3["✅ En producción<br/>segura y documentada<br/>en minutos"]
    START -->|"🧗 Camino libre"| FP1["Investigo Lambda,<br/>Functions, IAM, ACR..."] --> FP2["Escribo mis scripts<br/>y pipelines"] --> FP3["Configuro seguridad<br/>(si me acuerdo)"] --> FP4["⏳ En producción<br/>en días o semanas"]

    classDef gp fill:#D5F5E3,stroke:#1E8449,color:#1a1a1a
    classDef fp fill:#FDEBD0,stroke:#CA6F1E,color:#1a1a1a
    classDef s fill:#FFE8A3,stroke:#B58900,color:#1a1a1a
    class START s
    class GP1,GP2,GP3 gp
    class FP1,FP2,FP3,FP4 fp
```

> El camino libre **no se prohíbe** (a veces hace falta), pero el golden path es tan cómodo que es la opción natural.

---

## 🆚 DevOps, SRE y Platform Engineering

No compiten: se complementan.

| | DevOps | SRE | Platform Engineering |
|-|--------|-----|----------------------|
| **Qué es** | Una **cultura**: desarrollo y operaciones trabajan juntos y automatizan | Una **práctica** de fiabilidad con ingeniería de software | Una **disciplina** que construye la plataforma interna |
| **Pregunta que responde** | ¿Cómo colaboramos y entregamos rápido? | ¿Cómo mantenemos el sistema fiable? | ¿Cómo hacemos que entregar rápido y seguro sea **fácil para todos**? |
| **Herramientas típicas** | CI/CD, IaC, automatización | SLOs, presupuestos de error, guardias, postmortems | Golden paths, portales (p. ej. Backstage), plantillas, autoservicio |
| **En este repo** | Pipelines CI/CD, infra como código | Smoke tests, health checks | Scripts reutilizables, abstracción multi-cloud, wiki, laboratorio |

```mermaid
flowchart LR
    DEVOPS["🤝 DevOps<br/>la cultura y los principios"] --> PE["🛠️ Platform Engineering<br/>los convierte en una plataforma<br/>que cualquiera puede usar"]
    SRE["📈 SRE<br/>fiabilidad y operación"] --> PE
    PE --> DX["😊 Mejor experiencia<br/>de desarrollo"]
    PE --> SPEED["🚀 Entregas más rápidas"]
    PE --> SAFE["🛡️ Seguridad y cumplimiento<br/>por defecto"]

    classDef a fill:#D6EAF8,stroke:#2874A6,color:#1a1a1a
    classDef p fill:#FFE8A3,stroke:#B58900,color:#1a1a1a
    classDef r fill:#D5F5E3,stroke:#1E8449,color:#1a1a1a
    class DEVOPS,SRE a
    class PE p
    class DX,SPEED,SAFE r
```

---

## 👥 Cómo se organizan los equipos

Según el modelo **Team Topologies**, el equipo de plataforma da servicio a los equipos de producto (*stream-aligned*) para que estos puedan ir rápido sin depender de nadie:

```mermaid
flowchart TB
    subgraph PROD["Equipos de producto (stream-aligned)"]
        direction LR
        T1["🛒 Equipo Tienda"]
        T2["💳 Equipo Pagos"]
        T3["📱 Equipo App móvil"]
    end
    PLAT["🛠️ Equipo de plataforma<br/>ofrece la IDP como servicio"]
    ENAB["🎓 Equipo habilitador<br/>enseña y acompaña<br/>(ej. seguridad)"]

    PLAT -->|"X as a Service:<br/>autoservicio"| T1 & T2 & T3
    ENAB -.->|"facilita: forma<br/>y luego se retira"| T2
    T1 & T2 & T3 -.->|"necesidades y feedback"| PLAT

    classDef prod fill:#D5F5E3,stroke:#1E8449,color:#1a1a1a
    classDef plat fill:#D6EAF8,stroke:#2874A6,color:#1a1a1a
    classDef en fill:#F4ECF7,stroke:#7D3C98,color:#1a1a1a
    class T1,T2,T3 prod
    class PLAT plat
    class ENAB en
```

---

## 🧩 Las capas de una plataforma interna

| Capa | Qué ofrece | En este repo | Lo que faltaría en una empresa real |
|------|-----------|--------------|-------------------------------------|
| 🖥️ Interfaz para devs | Dónde se piden las cosas | GitHub Actions (*Run workflow*) + wiki | Un portal (Backstage, Port...) con catálogo de servicios |
| 🛤️ Integración y entrega | Pipelines estándar | `ci*.yml`, `cd*.yml` | Workflows reutilizables (`workflow_call`) versionados para todos los repos |
| 🏗️ Infraestructura | Recursos bajo demanda | `infraestructure.yml` con CLI | IaC declarativa con estado (Terraform, Bicep, Pulumi) |
| 🛡️ Seguridad | Guardrails | CodeQL, Grype, SCA, aprobaciones | OIDC en vez de claves fijas, políticas (OPA, Azure Policy), firma de imágenes |
| 📊 Observabilidad | Logs, métricas, trazas | Logs básicos | Dashboards, alertas y SLOs estándar por servicio |
| 💰 Costes | Visibilidad del gasto | `destroy` manual | Etiquetas, presupuestos y alertas de coste |
| 📖 Conocimiento | Documentación | Esta wiki (docs as code) | Docs generadas por servicio en el portal |

---

## 📏 ¿Cómo sé si una plataforma funciona?

Se mide, como cualquier producto. Las métricas más usadas son las **DORA**:

| Métrica DORA | Pregunta | Cómo ayuda este repo |
|--------------|----------|----------------------|
| **Frecuencia de despliegue** | ¿Cada cuánto llega algo a producción? | Cada push a `main` despliega solo |
| **Lead time de cambios** | ¿Cuánto tarda un commit en estar en producción? | Minutos: build → release → deploy automáticos |
| **Tasa de fallos de cambios** | ¿Qué % de despliegues rompe algo? | Tests + smoke test frenan lo roto |
| **Tiempo de recuperación** | ¿Cuánto tardamos en arreglar un fallo? | Releases con tag por commit: se sabe qué se desplegó y se puede volver a una versión anterior |

Y además, la **experiencia del desarrollador**: ¿la gente **elige** usar la plataforma? ¿cuánto tarda alguien nuevo en hacer su primer despliegue? (en este repo: el [laboratorio](08-Laboratorio-Paso-a-Paso.md)).

---

## ✅ Resumen

- **Ingeniería de Plataforma** = construir una **plataforma interna de autoservicio**, tratada como **producto**, que reduce la carga cognitiva de los equipos.
- Sus herramientas son los **golden paths**, la **abstracción**, los **guardrails** y la **documentación**.
- Este repo es una **plataforma mínima**: pipelines estándar, scripts reutilizables, multi-cloud con una variable, seguridad por defecto y docs como código.
- Igual de importante es saber **qué no hacer**: ver [13 · ⛔ Qué NO hacer](13-Que-NO-hacer.md).

➡️ Siguiente: [1 · Introducción a Serverless](01-Introduccion-Serverless.md)
