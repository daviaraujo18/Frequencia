# Sprint 24.1 — infraestrutura de build Node/Sass.
#
# Expõe o build compilado (app/assets/builds/application.css, gerado por `yarn build:css`)
# e os webfonts do Font Awesome (pacote npm local) ao Propshaft.
Rails.application.config.assets.paths << Rails.root.join("app/assets/builds")
Rails.application.config.assets.paths << Rails.root.join("node_modules/@fortawesome/fontawesome-free/webfonts")

# Sprint 26.7 — webfonts do Bootstrap Icons (bi-*): o diretório `fonts/` do pacote
# é registrado por seus ARQUIVOS (Propshaft expõe cada arquivo pelo seu logical
# path/flat — ex.: `bootstrap-icons.woff2`, NÃO `fonts/bootstrap-icons.woff2`).
# Por isso o `./fonts/...` default do SCSS não resolve (achado da 26.8);
# o override `$bootstrap-icons-font-dir: "."` no application.scss alinha as URLs
# compiladas ao logical path flat (mesmo padrão 24.1 do Font Awesome).
Rails.application.config.assets.paths << Rails.root.join("node_modules/bootstrap-icons/font/fonts")
