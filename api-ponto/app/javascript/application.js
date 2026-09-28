// Application JavaScript entry point
// Carrega jQuery, Bootstrap JS e AdminLTE JS via importmap (CDN)
//
// Nota: jQuery é carregado como side-effect — expõe window.$ e window.jQuery
// globalmente para compatibilidade com scripts legados da Estação JavaFX.

import "jquery"
import "bootstrap"
import "admin-lte"

// Port 26.10 — tooltips Bootstrap (`[data-bs-toggle="tooltip"]`) + dispose
// turbo (porta do basic8 `app/javascript/src/functions.js`). Inicializa no
// top-level do módulo (equivalente do `connect()` do Stimulus — decisão
// registrada na Linha do Tempo da 26.10). A ORDEM importa: este import deve
// vir DEPOIS de `import "bootstrap"` — o bundle UMD pinado no importmap
// define o global `window.bootstrap` consumido pelo módulo de tooltips.
// Specifier `src/functions` (bare) resolvido pelo pin `pin_all_from ... src`
// do importmap.rb — padrão nativo importmap, sem esbuild.
import "src/functions"