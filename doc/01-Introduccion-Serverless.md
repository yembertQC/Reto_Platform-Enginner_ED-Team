# 1 · Introducción a Serverless

⬅️ Anterior: [0 · ¿Qué es Ingeniería de Plataforma?](00-Ingenieria-de-Plataforma.md)

> 🎯 **Objetivo:** entender qué es serverless, en qué se diferencia de Kubernetes y qué servicios usamos en este proyecto.

---

## ¿Qué es serverless?

En el modelo tradicional tú alquilas **máquinas** (o un cluster de Kubernetes) y pagas por ellas **aunque nadie use tu app**. En serverless entregas **tu código o tu contenedor** y la nube:

- 🚀 lo **arranca** cuando llega una petición,
- 📈 lo **escala** si llegan muchas,
- 😴 lo **apaga** (escala a cero) cuando no hay tráfico,
- 💰 te **cobra por uso**, no por tiempo encendido.

```mermaid
flowchart TB
    subgraph TRAD["🏢 Antes: Kubernetes (AKS / EKS)"]
        direction TB
        T1["Tú creas el cluster"] --> T2["Tú gestionas nodos,<br/>red, ingress, balanceador"]
        T2 --> T3["Tú escribes manifiestos<br/>Deployment, Service, HPA..."]
        T3 --> T4["💸 Pagas los nodos<br/>24/7 aunque no haya tráfico"]
    end

    subgraph SLESS["⚡ Ahora: Serverless"]
        direction TB
        S1["Tú subes código<br/>o una imagen"] --> S2["La nube arranca, escala<br/>y te da una URL HTTPS"]
        S2 --> S3["😴 Sin tráfico = 0 instancias"]
        S3 --> S4["💰 Pagas solo<br/>por peticiones y tiempo de uso"]
    end

    classDef old fill:#FADBD8,stroke:#C0392B,color:#1a1a1a
    classDef new fill:#D5F5E3,stroke:#1E8449,color:#1a1a1a
    class T1,T2,T3,T4 old
    class S1,S2,S3,S4 new
```

---

## Kubernetes vs Serverless

| Tema | Kubernetes (lo que había antes) | Serverless (lo que hay ahora) |
|------|----------------------------------|-------------------------------|
| Qué administras | Cluster, nodos, ingress, manifiestos | Solo tu app y su configuración |
| Escalado | HPA: mínimo 2 pods siempre encendidos | Automático, **desde 0** |
| URL pública | LoadBalancer + Traefik + Ingress | Incluida y con HTTPS |
| Tiempo de crear infra | 10-20 minutos (cluster) | 1-3 minutos |
| Coste en reposo | Nodos encendidos 24/7 | Prácticamente 0 |
| Desventaja principal | Complejidad operativa | **Cold start** y menos control |

> 🧠 **Ninguno es "mejor" siempre.** Kubernetes brilla con muchas apps, tráfico constante o necesidades especiales de red. Serverless brilla con tráfico variable, equipos pequeños y apps HTTP sencillas como la nuestra.

---

## ❄️ El cold start (arranque en frío)

Si tu app escaló a cero, la **primera** petición tiene que esperar a que la nube arranque una instancia. Eso es el *cold start*. Las siguientes peticiones ya encuentran la instancia "caliente".

```mermaid
sequenceDiagram
    autonumber
    actor U as 🌍 Usuario
    participant P as ☁️ Plataforma serverless
    participant I as 📦 Instancia de tu app

    rect rgb(253, 235, 208)
    Note over U,I: ❄️ Primera petición tras un rato sin tráfico
    U->>P: GET /health
    P->>I: Arranca una instancia nueva
    Note over I: Descarga imagen o código<br/>e inicia el proceso
    I-->>P: Lista
    P->>I: Reenvía la petición
    I-->>U: 200 healthy (tarda segundos)
    end

    rect rgb(213, 245, 227)
    Note over U,I: 🔥 Peticiones siguientes
    U->>P: GET /
    P->>I: Reenvía a la instancia caliente
    I-->>U: 200 Hola ED Team (milisegundos)
    end
```

Por eso el `smoke-test.sh` del pipeline **reintenta** varias veces antes de dar un despliegue por fallido.

### Ciclo de vida de una instancia

```mermaid
stateDiagram-v2
    state "😴 Cero instancias" as Cero
    state "❄️ Arrancando (cold start)" as Frio
    state "🔥 Atendiendo peticiones" as Caliente
    state "⏳ Ociosa" as Ociosa

    [*] --> Cero
    Cero --> Frio: llega una petición
    Frio --> Caliente: la app responde en /health
    Caliente --> Caliente: más peticiones
    Caliente --> Ociosa: deja de haber tráfico
    Ociosa --> Caliente: nueva petición
    Ociosa --> Cero: pasa el tiempo sin tráfico
```

---

## 🧰 Los servicios que usamos

| Servicio | Nube | Qué despliegas | Lo usamos para | Escala a cero |
|----------|------|----------------|----------------|---------------|
| ⚡ **Azure Functions** (Flex Consumption) | Azure | **Código** (un zip con Python) | App Python | ✅ |
| 🐳 **Azure Container Apps** | Azure | **Imagen de contenedor** | App Go | ✅ (`minReplicas 0`) |
| λ **AWS Lambda** | AWS | **Imagen de contenedor** (o código) | Apps Python y Go | ✅ |

```mermaid
flowchart LR
    Q{"¿Qué tienes?"}
    Q -->|"Código de funciones<br/>(Python, JS, C#...)"| F["⚡ Azure Functions<br/>λ Lambda con código"]
    Q -->|"Un contenedor que<br/>escucha HTTP"| C["🐳 Container Apps<br/>λ Lambda con imagen"]
    C --> NOTE["En Lambda necesitas el<br/>Lambda Web Adapter<br/>(ver página 3)"]

    classDef q fill:#FFE8A3,stroke:#B58900,color:#1a1a1a
    classDef opt fill:#D6EAF8,stroke:#2874A6,color:#1a1a1a
    classDef note fill:#F4ECF7,stroke:#7D3C98,color:#1a1a1a
    class Q q
    class F,C opt
    class NOTE note
```

---

## ✅ Resumen

- Serverless = **no administras servidores**, pagas por uso y escalas a cero.
- El precio a pagar es el **cold start**.
- Usamos **3 servicios**: Azure Functions, Azure Container Apps y AWS Lambda.

➡️ Siguiente: [2 · Arquitectura](02-Arquitectura.md)
