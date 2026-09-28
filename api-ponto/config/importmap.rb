# Importmap configuration
# Pinning CDN URLs for JavaScript libraries (no Node.js required)

pin "application"
pin "jquery", to: "https://cdn.jsdelivr.net/npm/jquery@3.7.1/dist/jquery.min.js"
pin "bootstrap", to: "https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
pin "admin-lte", to: "https://cdn.jsdelivr.net/npm/admin-lte@4.0.0/dist/js/adminlte.min.js"

# Port 26.10 — módulos locais de `app/javascript/src/` (ex.: `src/functions`
# com os tooltips Bootstrap). `pin_all_from` é o padrão nativo do
# importmap-rails para módulos locais fora de `controllers/` — gera o pin
# `src/functions` → asset com digest; o entry `application.js` importa o
# specifier bare `src/functions`. Sem esbuild/bundler na runtime.
pin_all_from "app/javascript/src", under: "src"