#!/usr/bin/env bash
# Métricas de la plataforma (M2 · Clase 4) con lo que la organización ya produce: los issues de <org>/platform.
# Solo lee. Por team, personas vs. agentes, creadas vs. rechazadas y tiempo de respuesta.
#
#   bash scripts/metrics.sh <org>                                  con tu sesión de gh
#   bash scripts/metrics.sh --desde scripts/ejemplo/issues.json    sin red, con datos de ejemplo
#
# Agente = el issue lleva platform/agent o lo abrió un bot (lo mismo que decide platformctl).
# Tiempo de respuesta = de abrir el issue a que platformctl lo cierra con platform/done: repo creado,
# configurado y con el primer despliegue en marcha. No incluye ese despliegue: para eso, el cronómetro.
# Necesita jq (y gh si lee de la API). Compatible con el bash 3.2 de macOS.
set -euo pipefail

uso() { echo "uso: $0 <org> | --desde <issues.json>" >&2; exit 2; }
[ $# -ge 1 ] || uso
if [ "$1" = "--desde" ]; then
  [ $# -eq 2 ] || uso
  fuente="$2 (datos de ejemplo)"
  issues=$(jq -c . "$2")
else
  [ $# -eq 1 ] || uso
  fuente="$1/platform"
  issues=$(gh api --paginate "repos/$1/platform/issues?state=all&per_page=100" | jq -s -c 'add // []')
fi

jq -r --arg fuente "$fuente" '
  def dur: round | if . < 60 then "\(.) s" elif . % 60 == 0 then "\(. / 60) min" else "\(. / 60 | floor) min \(. % 60) s" end;
  def der(n): tostring | (" " * (n - length)) + .;
  def izq(n): tostring | . + (" " * (n - length));
  def pct(a; b): if b == 0 then 0 else (a * 100 / b | round) end;
  def mediana: sort | if length == 0 then null
    elif length % 2 == 1 then .[length / 2 | floor]
    else (.[length / 2 - 1] + .[length / 2]) / 2 end;
  def plural(n; s): "\(n) \(s)\(if n == 1 then "" else "s" end)";
  def quien(xs): "\(plural(xs | map(select(.agente | not)) | length; "persona")) · \(plural(xs | map(select(.agente)) | length; "agente"))";

  [ .[] | select(.pull_request == null)
    | (.labels | map(.name)) as $l
    | select(any($l[]; startswith("platform/")))
    | { team: ((.body // "") | gsub("\r"; "") | (capture("### Team dueño\n+(?<t>[^\n]+)").t // "?") | ltrimstr(" ") | rtrimstr(" ")),
        agente: (any($l[]; . == "platform/agent") or .user.type == "Bot"),
        estado: (if any($l[]; . == "platform/done") then "creada"
                 elif any($l[]; . == "platform/rejected") then "rechazada" else "pendiente" end),
        dia: .created_at[0:10],
        seg: (if any($l[]; . == "platform/done") and .closed_at
              then (.closed_at | fromdate) - (.created_at | fromdate) else null end) } ] as $s

  | ($s | length) as $n
  | if $n == 0 then "No hay solicitudes en \($fuente): ningún issue lleva etiquetas platform/." else
    ($s | map(select(.estado == "creada"))) as $ok
  | ($s | map(select(.estado == "rechazada"))) as $no
  | ($s | map(select(.estado == "pendiente"))) as $pend
  | "Plataforma · \($fuente)",
    "\($n) solicitudes, del \($s | map(.dia) | min) al \($s | map(.dia) | max)",
    "",
    "\("Por team" | izq(14))\("personas" | der(10))\("agentes" | der(9))\("total" | der(7))",
    ( $s | group_by(.team) | sort_by(-length)[]
      | "  \(.[0].team | izq(12))\(map(select(.agente | not)) | length | der(10))\(map(select(.agente)) | length | der(9))\(length | der(7))" ),
    "  \("total" | izq(12))\($s | map(select(.agente | not)) | length | der(10))\($s | map(select(.agente)) | length | der(9))\($n | der(7))",
    "",
    "\("Creadas" | izq(12))\($ok | length | der(3))  (\(pct($ok | length; $n) | der(2)) %)   \(quien($ok))",
    "\("Rechazadas" | izq(12))\($no | length | der(3))  (\(pct($no | length; $n) | der(2)) %)   \(quien($no))",
    (if ($pend | length) > 0 then "\("Pendientes" | izq(12))\($pend | length | der(3))" else empty end),
    "",
    ( [$ok[] | .seg | select(. != null)] as $t
      | if ($t | length) == 0 then "Tiempo de respuesta: todavía no hay solicitudes creadas." else
        "Tiempo de respuesta (issue → platform/done, \($t | length) creadas)",
        "  \("mediana" | izq(12))\($t | mediana | dur)",
        "  \("peor caso" | izq(12))\($t | max | dur)",
        ( [$ok[] | select(.agente | not) | .seg | select(. != null)] as $p
        | [$ok[] | select(.agente) | .seg | select(. != null)] as $a
        | "  \("personas" | izq(12))\(if ($p | length) > 0 then ($p | mediana | dur) else "—" end)    agentes  \(if ($a | length) > 0 then ($a | mediana | dur) else "—" end)" )
        end )
    end
' <<<"$issues"
