# 12 · Glosario

| Término | Significado |
|---------|-------------|
| **ACR** (Azure Container Registry) | Registro privado de imágenes Docker de Azure. |
| **Antipatrón** | Solución que parece buena pero causa problemas a medio plazo (ver [13 · Qué NO hacer](13-Que-NO-hacer.md)). |
| **Artifact** (GitHub Actions) | Archivo que un job guarda para que otro job lo use (por ejemplo `function-app.zip`). |
| **Azure Container Apps** | Servicio serverless de Azure que ejecuta contenedores y escala según el tráfico, incluso a cero. |
| **Azure Functions** | Servicio serverless de Azure que ejecuta funciones disparadas por eventos (HTTP, colas, temporizadores...). |
| **CD** (Continuous Delivery / Deployment) | Automatizar la entrega: cada cambio aprobado se construye y despliega solo. |
| **CI** (Continuous Integration) | Automatizar la verificación de cada cambio: tests y análisis en cada push o PR. |
| **CloudWatch Logs** | Servicio de AWS donde Lambda guarda los logs. |
| **CODEOWNERS** | Archivo que define quién debe revisar los cambios de cada ruta del repositorio. |
| **CodeQL** | Motor de análisis estático de GitHub que busca vulnerabilidades en el código. |
| **Cold start** | Retraso de la primera petición cuando la plataforma tiene que arrancar una instancia nueva. |
| **Container Apps Environment** | "Barrio" donde viven una o varias Container Apps; comparten red y configuración. |
| **CVE** | Identificador público de una vulnerabilidad conocida (por ejemplo `CVE-2024-1234`). |
| **CWE** | Catálogo de *tipos* de debilidad (CWE-89 = SQL injection). |
| **Dependabot** | Servicio de GitHub que detecta dependencias vulnerables o desactualizadas y abre PRs para actualizarlas. |
| **DevSecOps** | Integrar la seguridad en todo el ciclo de desarrollo y operación, de forma automática. |
| **Digest** | Huella `sha256:...` que identifica el contenido exacto de una imagen. |
| **Dockerfile** | Receta para construir una imagen de contenedor. |
| **DORA** | Cuatro métricas de entrega de software: frecuencia de despliegue, lead time, tasa de fallos y tiempo de recuperación. |
| **Drift** | Diferencia entre lo que dice el código/pipeline y lo que realmente hay en la nube (normalmente por cambios a mano). |
| **ECR** (Elastic Container Registry) | Registro privado de imágenes Docker de AWS. |
| **Environment** (GitHub) | Destino de despliegue con reglas (revisores, ramas permitidas, esperas). |
| **Flex Consumption** | Plan de Azure Functions que escala a cero y cobra por ejecución. |
| **Function URL** | URL HTTPS pública que AWS asigna directamente a una Lambda, sin API Gateway. |
| **GHCR** (GitHub Container Registry) | Registro de imágenes de GitHub (`ghcr.io`). |
| **Golden path** | Camino recomendado, ya resuelto y seguro, para hacer algo en una plataforma. |
| **Grype** | Escáner de vulnerabilidades de imágenes de contenedor (de Anchore). |
| **Guardrail** | Control automático que evita errores graves sin frenar al equipo. |
| **IAM Role** | Identidad de AWS con permisos que un servicio (como Lambda) puede asumir. |
| **Idempotente** | Que se puede ejecutar varias veces con el mismo resultado. |
| **IDP** (Internal Developer Platform) | Plataforma interna de autoservicio que usan los equipos para construir, desplegar y operar sus apps. |
| **Ingeniería de Plataforma** | Disciplina que construye y mantiene la IDP tratándola como un producto (ver [página 0](00-Ingenieria-de-Plataforma.md)). |
| **Job summary** | Resumen en Markdown que un job escribe y que se ve en la pestaña *Summary* de la ejecución. |
| **Lambda** | Servicio serverless de AWS que ejecuta código o contenedores bajo demanda. |
| **Lambda Web Adapter** | Extensión que permite ejecutar una app web normal dentro de Lambda traduciendo eventos a HTTP. |
| **Mermaid** | Lenguaje para dibujar diagramas con texto dentro de Markdown. |
| **Mínimo privilegio** | Dar solo los permisos estrictamente necesarios. |
| **Multi-stage build** | Dockerfile con varias etapas: se compila en una y se copia solo el resultado a otra más pequeña. |
| **OIDC** | Forma de que GitHub Actions obtenga credenciales temporales de la nube sin guardar claves fijas. |
| **Platform as a product** | Tratar la plataforma como un producto: usuarios, feedback, roadmap y documentación. |
| **Push protection** | Función de secret scanning que bloquea un push si contiene un secreto. |
| **Release** (GitHub) | Versión etiquetada del código (tag + notas). |
| **Remote build** | Azure instala las dependencias de Python en sus servidores al recibir el código. |
| **Resource Group** | Contenedor lógico de recursos en Azure. |
| **Ruleset** | Conjunto de reglas de GitHub que protege ramas o tags (PR obligatorio, sin force push, etc.). |
| **SARIF** | Formato estándar para resultados de análisis de seguridad. |
| **SAST** | Análisis estático de seguridad: revisa el código sin ejecutarlo. |
| **SCA** | Análisis de composición: revisa las dependencias de terceros. |
| **Scale to zero** | Bajar a cero instancias cuando no hay tráfico (coste cero en reposo). |
| **Secret** (GitHub) | Valor cifrado que los workflows pueden usar y que se oculta en los logs. |
| **Serverless** | Modelo en el que no administras servidores: la nube arranca, escala y cobra por uso. |
| **Service Principal** | Identidad de aplicación en Azure (la "cuenta" que usa GitHub Actions). |
| **SHA pinning** | Fijar una GitHub Action a un commit concreto (`@<sha>`) en vez de a un tag que puede moverse. |
| **Smoke test** | Prueba rápida tras desplegar para confirmar que lo básico funciona. |
| **SRE** (Site Reliability Engineering) | Práctica que aplica ingeniería de software a la fiabilidad y la operación. |
| **Team Topologies** | Modelo de organización de equipos (producto, plataforma, habilitadores...) y cómo interactúan. |
| **Ticket-ops** | Antipatrón: todo se pide por ticket y lo hace otra persona a mano. |
| **Well-Architected (GitHub)** | Marco de buenas prácticas de GitHub organizado en pilares: seguridad, gobierno, colaboración, productividad y arquitectura. |
| **Workflow** | Archivo YAML en `.github/workflows/` que define un pipeline de GitHub Actions. |
| **WSGI** | Estándar de Python para conectar servidores web con apps (Flask, Django). |

➡️ Siguiente: [13 · ⛔ Qué NO hacer](13-Que-NO-hacer.md) · ⬅️ Volver al [Inicio](Home.md)
