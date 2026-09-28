// Port 26.10 (Sprint 26) — `functions.js` do basic8 (tooltips Bootstrap).
// Porta fiel de `basic8/app/javascript/src/functions.js` (16 linhas) adaptada
// ao runtime do Frequencia (importmap + Stimulus, SEM esbuild):
//
//   1. O fonte usa `import * as bootstrap from "bootstrap"` — no Frequencia o
//      importmap pina "bootstrap" para o bundle UMD (`bootstrap.bundle.min.js`,
//      config/importmap.rb), que NÃO expõe named exports ES e define o global
//      `window.bootstrap` ao ser avaliado (o entry `application.js` faz o
//      import side-effect ANTES deste módulo). Por isso usamos
//      `window.bootstrap.Tooltip` — a API que o projeto JÁ expõe via o pin
//      existente, SEM duplicar/alterar o pin (critério 26.10).
//
//   2. No basic8, `tooltips()` é chamado pelo Stimulus `application_controller.js`
//      (`connect() { tooltips() }`). No Frequencia o Stimulus NÃO está no
//      runtime (importmap sem pins de stimulus/turbo — controllers
//      sidebar/theme/hello/username_preview são inertes; decisão registrada na
//      Linha do Tempo da 26.10). Equivalente compatível com importmap:
//      chamada no top-level do módulo — módulos ES são deferred, então o DOM
//      já está parseado quando o entry o importa. A API exportada permanece
//      disponível para uma futura integração Stimulus (Sprint 25) sem quebra.
//
//   3. `dispose` em `turbo:before-cache`/`turbo:before-visit` portado fielmente.
//      Sem Turbo pinado os eventos não disparam (no-op documentado): sem
//      navegação drive, toda visita é full reload e o módulo re-roda.

let tooltipInstances = []

export const disposeTooltips = function () {
  tooltipInstances.forEach((tooltip) => tooltip.dispose())
  tooltipInstances = []
}

export const tooltips = function () {
  const tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]')
  tooltipInstances = [...tooltipTriggerList].map((tooltipTriggerEl) => new window.bootstrap.Tooltip(tooltipTriggerEl))
}

// NOTE: equivalente do `connect()` do Stimulus do fonte — sem Stimulus no
// runtime (ver item 2), a inicialização roda aqui no top-level do módulo.
tooltips()

document.addEventListener("turbo:before-cache", disposeTooltips)
document.addEventListener("turbo:before-visit", disposeTooltips)