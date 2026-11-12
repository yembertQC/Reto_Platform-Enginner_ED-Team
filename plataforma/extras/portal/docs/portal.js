// Portal de la plataforma: la cara de la IDP sobre IssueOps.
//
// - Crear:       cada formulario de platform/.github/ISSUE_TEMPLATE es una acción. El portal lo pinta,
//                valida lo que puede (config/plataforma.json) y abre el issue en GitHub ya relleno.
//                No hay backend ni tokens: quien envía el issue es la persona, con su sesión de GitHub.
// - Catálogo:    catalog/catalog.yml.
//
// Vive en platform/docs/ y se publica con GitHub Pages: <org>.github.io/platform/. Lo propuso un
// equipo de producto con un pull request (InnerSource); el team platform lo revisó por CODEOWNERS.
// - Solicitudes: issues del repo platform y su etiqueta platform/*.
//
// Todo sale de la API pública de GitHub (60 consultas por hora por IP sin sesión; el portal usa 3 por carga).
// Con ?demo (o window.PORTAL_DEMO) usa demo.json: datos de ejemplo para enseñar el portal sin organización.
(function () {
  "use strict";

  const C = window.PORTAL || {};
  const DEMO = window.PORTAL_DEMO === true || new URLSearchParams(location.search).has("demo");
  const PLACEHOLDER = "__" + "ORG__"; // partido para que bootstrap.sh no lo sustituya
  let ORG = C.org && C.org !== PLACEHOLDER ? C.org : "";
  if (!ORG) {
    const m = location.hostname.match(/^([^.]+)\.github\.io$/i);
    ORG = m ? m[1] : DEMO ? "mi-org" : "";
  }
  const P = C.platformRepo || "platform";
  const CAT = C.catalogRepo || "catalog";
  const BR = C.branch || "main";
  const API = "https://api.github.com";
  const RAW = "https://raw.githubusercontent.com";
  const GH = "https://github.com";

  const STATES = {
    pending: ["En cola", "Recibida; la plataforma la va a evaluar."],
    running: ["Creando", "Validada; se está creando el repo."],
    done: ["Lista", "Repo creado y primer despliegue lanzado."],
    rejected: ["Rechazada", "No cumple una regla; el motivo está en el issue."],
    failed: ["Falló", "Error de la plataforma; lo revisa el team platform."],
  };
  const ORDER = ["failed", "rejected", "done", "running", "pending"];

  const state = { templates: [], config: null, catalog: [], issues: [], selected: 0 };
  const $ = (id) => document.getElementById(id);

  // ---------- utilidades ----------
  function h(tag, attrs, ...kids) {
    const el = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (v == null || v === false) continue;
      if (k === "class") el.className = v;
      else if (k === "text") el.textContent = v;
      else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
      else el.setAttribute(k, v === true ? "" : v);
    }
    for (const kid of kids.flat()) if (kid != null && kid !== false) el.append(kid instanceof Node ? kid : String(kid));
    return el;
  }
  async function getJSON(url) {
    const r = await fetch(url, { headers: { Accept: "application/vnd.github+json" } });
    if (!r.ok) {
      const e = new Error(r.status === 403 || r.status === 429 ? "rate" : "HTTP " + r.status);
      e.status = r.status;
      throw e;
    }
    return r.json();
  }
  async function getText(url) {
    const r = await fetch(url);
    if (!r.ok) throw new Error("HTTP " + r.status);
    return r.text();
  }
  function b64utf8(s) {
    const bin = atob(String(s).replace(/\n/g, ""));
    return new TextDecoder().decode(Uint8Array.from(bin, (c) => c.charCodeAt(0)));
  }
  function explain(err) {
    if (err && err.message === "rate") return "GitHub limita a 60 consultas por hora sin sesión. Vuelve a cargar en unos minutos.";
    if (err && err.status === 404) return "No se encontró en la organización " + ORG + ". ¿Se ejecutó bootstrap.sh?";
    return "No se pudo cargar (" + (err && err.message ? err.message : "error") + ").";
  }
  const rtf = new Intl.RelativeTimeFormat("es", { numeric: "auto" });
  function ago(iso) {
    const s = (new Date(iso) - Date.now()) / 1000;
    const steps = [["year", 31536000], ["month", 2592000], ["day", 86400], ["hour", 3600], ["minute", 60]];
    for (const [u, n] of steps) if (Math.abs(s) >= n) return rtf.format(Math.round(s / n), u);
    return "ahora mismo";
  }
  const repoURL = (r) => `${GH}/${ORG}/${r}`;

  // ---------- carga ----------
  async function load() {
    if (DEMO) {
      const d = await getText("demo.json").then(JSON.parse);
      return {
        templates: { status: "fulfilled", value: d.templates },
        config: { status: "fulfilled", value: d.config },
        catalog: { status: "fulfilled", value: d.catalog },
        issues: { status: "fulfilled", value: d.issues },
      };
    }
    const [templates, config, catalog, issues] = await Promise.allSettled([
      getJSON(`${API}/repos/${ORG}/${P}/contents/.github/ISSUE_TEMPLATE?ref=${BR}`).then((list) =>
        Promise.all(
          list
            .filter((f) => /\.ya?ml$/.test(f.name) && !/^config\.ya?ml$/.test(f.name))
            .map(async (f) => ({ file: f.name, form: jsyaml.load(await getText(f.download_url)) }))
        )
      ),
      getText(`${RAW}/${ORG}/${P}/${BR}/config/plataforma.json`).then(JSON.parse),
      getJSON(`${API}/repos/${ORG}/${CAT}/contents/catalog.yml?ref=${BR}`).then(
        (f) => (jsyaml.load(b64utf8(f.content)) || {}).servicios || []
      ),
      getJSON(`${API}/repos/${ORG}/${P}/issues?state=all&per_page=50`).then((l) => l.filter((i) => !i.pull_request)),
    ]);
    return { templates, config, catalog, issues };
  }

  // ---------- Crear ----------
  // Cada campo dropdown con pocas opciones se pinta como botones; con config/plataforma.json se
  // desactivan las opciones que la plataforma rechazaría (región de otra nube, tamaño no permitido).
  function renderActions() {
    const ul = $("actions");
    ul.replaceChildren();
    if (!state.templates.length) {
      $("panel").replaceChildren(h("p", { class: "empty", text: "Todavía no hay formularios en platform/.github/ISSUE_TEMPLATE." }));
      return;
    }
    state.templates.forEach((t, i) => {
      ul.append(
        h("li", null,
          h("button", { type: "button", "aria-pressed": String(i === state.selected), onclick: () => { state.selected = i; renderActions(); } },
            h("b", { text: t.form.name || t.file }),
            t.form.description ? h("span", { text: t.form.description }) : null))
      );
    });
    renderPanel(state.templates[state.selected]);
  }

  function renderPanel(t) {
    const form = t.form;
    const cfg = state.config;
    const fields = (form.body || []).filter((f) => f.type !== "markdown");
    const els = {};

    const f = h("form", { class: "req", novalidate: true, onsubmit: (e) => e.preventDefault() });
    for (const item of form.body || []) {
      const a = item.attributes || {};
      if (item.type === "markdown") { f.append(h("p", { class: "md", text: String(a.value || "").trim() })); continue; }
      const id = item.id || a.label;
      const req = !!(item.validations && item.validations.required);
      const fid = "f-" + id;
      let help = a.description || "";
      let control;

      if (item.type === "input") {
        const pattern = id === "nombre" && cfg && cfg.nombre_regex ? cfg.nombre_regex : null;
        if (pattern && cfg.nombre_ayuda) help = "Convención: " + cfg.nombre_ayuda + ".";
        control = h("input", { type: "text", id: fid, placeholder: a.placeholder || " ", required: req, pattern, autocomplete: "off", spellcheck: "false" });
        els[id] = { get: () => control.value.trim(), el: control };
      } else if (item.type === "textarea") {
        control = h("textarea", { id: fid, placeholder: a.placeholder || "", required: req });
        els[id] = { get: () => control.value.trim(), el: control };
      } else if (item.type === "dropdown") {
        const opts = (a.options || []).map(String);
        if (!a.multiple && opts.length <= 6) {
          control = h("div", { class: "seg", role: "radiogroup", "aria-labelledby": fid + "-l" },
            opts.map((o) => h("label", null, h("input", { type: "radio", name: fid, value: o }), h("span", { text: o }))));
          els[id] = { get: () => (control.querySelector("input:checked") || {}).value || "", el: control, radios: true };
        } else {
          control = h("select", { id: fid, multiple: !!a.multiple },
            a.multiple ? null : h("option", { value: "", text: "Elige…" }), opts.map((o) => h("option", { value: o, text: o })));
          els[id] = { get: () => [...control.selectedOptions].map((o) => o.value).filter(Boolean).join(", "), el: control };
        }
      } else if (item.type === "checkboxes") {
        control = h("div", { class: "checks" }, (a.options || []).map((o, i) =>
          h("label", null, h("input", { type: "checkbox", id: `${fid}-${i}`, value: o.label }), " ", o.label)));
        els[id] = { get: () => [...control.querySelectorAll("input:checked")].map((x) => x.value).join(", "), el: control, skipURL: true };
      } else continue;

      els[id].label = a.label || id;
      els[id].required = req;
      f.append(h("div", { class: "field" },
        h(item.type === "dropdown" && els[id].radios ? "span" : "label", { class: "lbl", for: els[id].radios ? null : fid, id: fid + "-l" },
          a.label || id, req ? h("i", { text: "obligatorio" }) : null),
        help ? h("p", { class: "help", text: help }) : null,
        control));
    }

    const problems = h("p", { class: "err", "aria-live": "polite" });
    const link = h("a", { class: "btn", target: "_blank", rel: "noopener", "aria-disabled": "true", href: "#" }, "Abrir en GitHub y enviar ↗");
    const pre = h("pre");
    const go = h("div", { class: "go" }, link,
      h("small", { text: "GitHub muestra el formulario con estos datos. Revísalo y pulsa «Create». Si algún desplegable llega vacío, elígelo allí: el resto ya va relleno." }));
    const preview = h("details", { class: "preview" }, h("summary", { text: "Ver el issue que se va a crear" }), pre);

    // Lo que permite config/plataforma.json: regiones de la nube elegida, ambientes y tamaños.
    // La plataforma lo vuelve a validar al recibir el issue; aquí solo se evita pedir algo que se rechazará.
    function limit(field, allowed, autoPick) {
      if (!field || !field.radios || !allowed) return;
      const radios = [...field.el.querySelectorAll("input")];
      for (const r of radios) {
        r.disabled = !allowed.includes(r.value);
        r.parentElement.title = r.disabled ? "No permitido por la plataforma" : "";
        if (r.disabled && r.checked) r.checked = false;
      }
      const usable = radios.filter((r) => !r.disabled);
      if (autoPick && usable.length === 1) usable[0].checked = true;
    }
    function syncRegions() {
      if (!cfg) return;
      if (els.nube && cfg.nubes) limit(els.region, (cfg.nubes[els.nube.get()] || {}).regiones, true);
      limit(els.ambiente, cfg.ambientes, false);
      limit(els.tamano, cfg.tamanos_permitidos, false);
    }

    function update() {
      syncRegions();
      const values = {};
      const missing = [];
      for (const [id, e] of Object.entries(els)) {
        values[id] = e.get();
        if (e.required && !values[id]) missing.push(e.label);
      }
      const bad = Object.values(els).filter((e) => e.el.validity && !e.el.validity.valid && e.el.value).map((e) => e.label);
      const msg = [];
      if (missing.length) msg.push("Falta: " + missing.join(", ") + ".");
      if (bad.length) msg.push("Revisa: " + bad.join(", ") + ".");
      problems.textContent = msg.join(" ");

      const title = (form.title || "") + (values.nombre || "");
      pre.textContent = fields.map((it) => {
        const id = it.id || it.attributes.label;
        return `### ${it.attributes.label}\n\n${values[id] || "_No response_"}`;
      }).join("\n\n");

      const q = new URLSearchParams({ template: t.file, title });
      for (const [id, e] of Object.entries(els)) if (values[id] && !e.skipURL) q.set(id, values[id]);
      const ok = !missing.length && !bad.length;
      link.href = ok ? `${GH}/${ORG}/${P}/issues/new?${q}` : "#";
      link.setAttribute("aria-disabled", String(!ok));
    }
    f.addEventListener("input", update);
    f.addEventListener("change", update);

    $("panel").replaceChildren(
      h("div", { class: "action-head" }, h("h2", { text: form.name || t.file }), form.description ? h("p", { text: form.description }) : null),
      f, problems, preview, go);
    update();
  }

  // ---------- Catálogo ----------
  function fillSelect(sel, values) {
    const first = sel.options[0];
    sel.replaceChildren(first, ...[...new Set(values.filter(Boolean))].sort().map((v) => h("option", { value: v, text: v })));
  }
  function renderCatalog() {
    const q = $("q").value.trim().toLowerCase();
    const ft = $("fTeam").value, fl = $("fTec").value, fn = $("fNube").value;
    const list = state.catalog.filter((s) =>
      (!ft || s.team === ft) && (!fl || s.tecnologia === fl) && (!fn || s.nube === fn) &&
      (!q || `${s.nombre} ${s.descripcion || ""}`.toLowerCase().includes(q)));
    $("catStatus").textContent = state.catalog.length
      ? `${list.length} de ${state.catalog.length} servicios`
      : "El catálogo está vacío. El primer servicio que pidas aparecerá aquí.";
    $("services").replaceChildren(...list.map((s) => h("li", { class: "svc" },
      h("h3", { text: s.nombre }),
      s.descripcion ? h("p", { text: s.descripcion }) : null,
      h("div", { class: "chips" },
        h("span", { class: "chip team", text: "@" + s.team }),
        h("span", { class: "chip", text: s.tecnologia }),
        h("span", { class: "chip", text: `${s.nube} · ${s.region}` }),
        s.ambiente ? h("span", { class: "chip", text: `${s.ambiente}${s.tamano ? " · " + s.tamano : ""}` }) : null),
      h("div", { class: "meta" },
        h("span", { text: `Pedido por @${s.autor}` }),
        h("span", { text: s.origen === "agente" ? "agente de IA" : "persona" }),
        s.fecha ? h("span", { text: String(s.fecha) }) : null),
      h("div", { class: "links" },
        h("a", { href: repoURL(s.nombre), target: "_blank", rel: "noopener", text: "Repositorio" }),
        h("a", { href: repoURL(s.nombre) + "/actions", target: "_blank", rel: "noopener", text: "Despliegues" }),
        s.issue ? h("a", { href: s.issue, target: "_blank", rel: "noopener", text: "Petición" }) : null))));
  }

  // ---------- Solicitudes ----------
  function stateOf(issue) {
    const names = (issue.labels || []).map((l) => (typeof l === "string" ? l : l.name));
    for (const s of ORDER) if (names.includes("platform/" + s)) return s;
    return issue.state === "closed" ? "done" : "pending";
  }
  function renderRequests() {
    $("legend").replaceChildren(...Object.entries(STATES).map(([k, [name, why]]) =>
      h("span", { title: why }, h("span", { class: "st " + k, text: name }))));
    const list = state.issues.filter((i) => (i.labels || []).some((l) => String(l.name || l).startsWith("platform/")));
    $("reqStatus").textContent = list.length ? "" : "Todavía no hay solicitudes.";
    $("reqStatus").hidden = !!list.length;
    $("requests").hidden = !list.length;
    $("requests").replaceChildren(...list.map((i) => {
      const s = stateOf(i);
      const agent = (i.labels || []).some((l) => (l.name || l) === "platform/agent") || (i.user && i.user.type === "Bot");
      return h("li", { class: "req-row" },
        h("span", { class: "num", text: "#" + i.number }),
        h("a", { class: "t", href: i.html_url, target: "_blank", rel: "noopener", text: i.title }),
        h("span", { class: "by", text: `@${i.user ? i.user.login : "?"} · ${agent ? "agente de IA · " : ""}${ago(i.created_at)}` }),
        h("span", { class: "state" }, h("span", { class: "st " + s, title: STATES[s][1], text: STATES[s][0] })));
    }));
  }

  // ---------- vistas ----------
  const VIEWS = ["crear", "catalogo", "solicitudes"];
  function route() {
    const v = VIEWS.includes(location.hash.slice(1)) ? location.hash.slice(1) : "crear";
    for (const name of VIEWS) $("view-" + name).hidden = name !== v;
    for (const a of document.querySelectorAll(".tabs a")) {
      if (a.dataset.view === v) a.setAttribute("aria-current", "page");
      else a.removeAttribute("aria-current");
    }
  }

  function renderFoot() {
    const repos = [P, "pipelines", "template-go", "template-python", CAT];
    $("foot").replaceChildren(
      ...repos.map((r) => h("a", { href: repoURL(r), target: "_blank", rel: "noopener", text: r })),
      h("span", { text: DEMO ? "Vista de ejemplo con datos inventados" : "Datos de la API pública de GitHub" }));
  }

  async function main() {
    window.addEventListener("hashchange", route);
    route();
    $("orgName").textContent = ORG || "organización";
    document.title = (ORG ? ORG + " · " : "") + "Portal de la plataforma";
    renderFoot();
    if (!ORG) {
      $("banner").hidden = false;
      $("banner").textContent = "No sé de qué organización es este portal: config.js no tiene el nombre y la URL no es <org>.github.io.";
      return;
    }
    if (DEMO) {
      $("banner").hidden = false;
      $("banner").textContent = "Vista de ejemplo: el catálogo y las solicitudes son inventados y los enlaces no llevan a repos reales.";
    }

    let r;
    try { r = await load(); } catch (e) {
      $("banner").hidden = false; $("banner").className = "banner warn"; $("banner").textContent = explain(e); return;
    }
    if (r.config.status === "fulfilled") state.config = r.config.value;

    if (r.templates.status === "fulfilled") { state.templates = r.templates.value; renderActions(); }
    else $("panel").replaceChildren(h("p", { class: "empty", text: "Las acciones no cargaron. " + explain(r.templates.reason) }));

    if (r.catalog.status === "fulfilled") {
      state.catalog = r.catalog.value;
      fillSelect($("fTeam"), state.catalog.map((s) => s.team));
      fillSelect($("fTec"), state.catalog.map((s) => s.tecnologia));
      fillSelect($("fNube"), state.catalog.map((s) => s.nube));
      for (const id of ["q", "fTeam", "fTec", "fNube"]) $(id).addEventListener("input", renderCatalog);
      $("nCat").textContent = state.catalog.length || "";
      renderCatalog();
    } else $("catStatus").textContent = explain(r.catalog.reason);

    if (r.issues.status === "fulfilled") {
      state.issues = r.issues.value;
      const open = state.issues.filter((i) => ["pending", "running"].includes(stateOf(i))).length;
      $("nReq").textContent = open || "";
      renderRequests();
    } else $("reqStatus").textContent = explain(r.issues.reason);
  }

  main();
})();
