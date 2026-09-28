# Schema Físico Confirmado — Módulo `presenca` (MySQL de Produção)

> **[⟰ Voltar ao Índice](00-indice.md)** · **[⌂ Home](../README.md)**

## Propósito

Registro do **schema físico real** das tabelas do módulo `presenca`, extraído diretamente do MySQL (via `08-coleta-schema.md`). Este documento **fecha o inventário**, serve de base para o **PRD** e para a migração de dados.

> **Fonte da coleta:** acesso direto ao MySQL local (`127.0.0.1:3306`, MariaDB 10.4.32), banco **`intranet`** — mesmo `jdbc:mysql://localhost/intranet` do `hibernate.properties`.
> ⚠️ **Aviso de dados:** as contagens de linhas sugerem **banco de teste/amostra** (muitas tabelas com exatamente 100 linhas). A **estrutura (schema) é autêntica**; os **dados não são de produção** (não servem para migração de dados, apenas para validação estrutural).

---

## Resumo Geral

- **22 tabelas** `presenca_*` encontradas (19 entidades + 3 de junção), todas `BASE TABLE`.
- **View `presenca_frequentadorestacao` NÃO existe** neste banco (ver Pendências #9).
- **9 FKs para outros módulos** no schema: `tjpi_*` (vinculado, vinculo, previnculadointervencao), `aproc_manifestacao`, `global_orgao`, `global_predio`, `sistema_usuario`, `admin_user`.
- Charset: **`latin1` / `latin1_swedish_ci`** (legado) — importante para migração de acentuação.
- Engine: **InnoDB** (compatível com `MySQL5InnoDBDialect`).

---

## Schema Completo (SHOW CREATE TABLE)

### `presenca_calculodiario`
```sql
CREATE TABLE `presenca_calculodiario` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `aberto` bit(1) NOT NULL,
  `ausencia` bit(1) NOT NULL,
  `data` date DEFAULT NULL,
  `excepcional` int(11) NOT NULL,
  `falta` bit(1) NOT NULL,
  `informacao` varchar(255) DEFAULT NULL,
  `meta` int(11) NOT NULL,
  `normal` int(11) NOT NULL,
  `total` int(11) NOT NULL,
  `registroMensal_id` int(11) DEFAULT NULL,
  `frequentador_id` int(11) DEFAULT NULL,
  `faltaCompensada` bit(1) DEFAULT b'0',
  `descontadoEmFolha` bit(1) DEFAULT b'0',
  `faltaADescontar` bit(1) DEFAULT b'0',
  `horarioRecalculo` datetime DEFAULT NULL,
  `permitidoAcumularHoras` bit(1) DEFAULT NULL,
  `permitidoCompensarFalta` bit(1) DEFAULT NULL,
  `permitidoContabilizarHorasMesmoComMetaZero` bit(1) DEFAULT NULL,
  `segundosParaCompensarFalta` int(11) NOT NULL,
  `saidaAntecipada` bit(1) DEFAULT NULL,
  `permitidoSaidaAntecipada` bit(1) DEFAULT NULL,
  `limitado` bit(1) DEFAULT NULL,
  `liberadoLimitacaoInicioHoraExtra` bit(1) DEFAULT NULL,
  `liberadoBloqueioMaxHoraExtra` bit(1) DEFAULT b'0',
  PRIMARY KEY (`id`),
  KEY `FK32F8B5D72BE99F15` (`frequentador_id`),
  KEY `FK32F8B5D7F029004A` (`registroMensal_id`),
  KEY `idx_data` (`data`),
  KEY `idx_data_frequentador` (`data`,`frequentador_id`),
  KEY `idx_frequentador_data` (`frequentador_id`,`data`),
  CONSTRAINT `FK32F8B5D72BE99F15` FOREIGN KEY (`frequentador_id`) REFERENCES `presenca_frequentador` (`id`),
  CONSTRAINT `FK32F8B5D7F029004A` FOREIGN KEY (`registroMensal_id`) REFERENCES `presenca_registromensalfrequencia` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=14253258
```

### `presenca_debitoremanscentenegociavel`
```sql
CREATE TABLE `presenca_debitoremanscentenegociavel` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `manifestacao_id` bigint(20) DEFAULT NULL,
  `registroMensalFrequencia_id` int(11) DEFAULT NULL,
  `responsavel_id` bigint(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FKD1DA2D27824ABD55` (`registroMensalFrequencia_id`),
  KEY `FKD1DA2D277523F763` (`manifestacao_id`),
  KEY `FKD1DA2D2755D2C86A` (`responsavel_id`),
  CONSTRAINT `FKD1DA2D2755D2C86A` FOREIGN KEY (`responsavel_id`) REFERENCES `sistema_usuario` (`id`),
  CONSTRAINT `FKD1DA2D277523F763` FOREIGN KEY (`manifestacao_id`) REFERENCES `aproc_manifestacao` (`id`),
  CONSTRAINT `FKD1DA2D27824ABD55` FOREIGN KEY (`registroMensalFrequencia_id`) REFERENCES `presenca_registromensalfrequencia` (`id`)
) ENGINE=InnoDB
```

### `presenca_diaexcepcional`
```sql
CREATE TABLE `presenca_diaexcepcional` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `frequentador_id` int(11) DEFAULT NULL,
  `momentoInicial` datetime DEFAULT NULL,
  `momentoFinal` datetime DEFAULT NULL,
  `descricao` varchar(255) DEFAULT NULL,
  `momentoRegistro` datetime DEFAULT NULL,
  `observacao` varchar(255) DEFAULT NULL,
  `ativo` bit(1) NOT NULL,
  `tipoFrequenciaExcepcional` varchar(255) DEFAULT NULL,
  `setorAtingido_id` int(11) DEFAULT NULL,
  `responsavel_id` bigint(20) DEFAULT NULL,
  `predio_id` bigint(20) DEFAULT NULL,
  `momentoFinalOriginal` datetime DEFAULT NULL,
  `momentoInicialOriginal` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK5FE11C77E8220233` (`setorAtingido_id`),
  KEY `FK5FE11C7755D2C86A` (`responsavel_id`),
  KEY `FK5FE11C772BE99F15` (`frequentador_id`),
  KEY `FK5FE11C773D46E989` (`predio_id`),
  KEY `idXList` (`ativo`,`momentoFinal`,`momentoInicial`,`tipoFrequenciaExcepcional`,`predio_id`,`frequentador_id`),
  CONSTRAINT `FK5FE11C772BE99F15` FOREIGN KEY (`frequentador_id`) REFERENCES `presenca_frequentador` (`id`),
  CONSTRAINT `FK5FE11C773D46E989` FOREIGN KEY (`predio_id`) REFERENCES `global_predio` (`id`),
  CONSTRAINT `FK5FE11C7755D2C86A` FOREIGN KEY (`responsavel_id`) REFERENCES `sistema_usuario` (`id`),
  CONSTRAINT `FK5FE11C77E8220233` FOREIGN KEY (`setorAtingido_id`) REFERENCES `global_orgao` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=7917566
```

### `presenca_direito`
```sql
CREATE TABLE `presenca_direito` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `frequentador_id` int(11) DEFAULT NULL,
  `descricao` varchar(255) DEFAULT NULL,
  `tipoDireito` varchar(255) DEFAULT NULL,
  `momentoInicial` datetime DEFAULT NULL,
  `momentoFinal` datetime DEFAULT NULL,
  `ativo` bit(1) NOT NULL,
  `momentoRegistro` datetime DEFAULT NULL,
  `observacao` varchar(255) DEFAULT NULL,
  `responsavel_id` bigint(20) DEFAULT NULL,
  `manifestacao_id` bigint(20) DEFAULT NULL,
  `intervencao_id` bigint(20) DEFAULT NULL,
  `momentoFinalOriginal` datetime DEFAULT NULL,
  `momentoInicialOriginal` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK8EB454E42BE99F15` (`frequentador_id`),
  KEY `FK8EB454E47523F763` (`manifestacao_id`),
  KEY `FK8EB454E455D2C86A` (`responsavel_id`),
  KEY `FK8EB454E46CCCAAAD` (`intervencao_id`),
  CONSTRAINT `FK8EB454E42BE99F15` FOREIGN KEY (`frequentador_id`) REFERENCES `presenca_frequentador` (`id`),
  CONSTRAINT `FK8EB454E455D2C86A` FOREIGN KEY (`responsavel_id`) REFERENCES `sistema_usuario` (`id`),
  CONSTRAINT `FK8EB454E46CCCAAAD` FOREIGN KEY (`intervencao_id`) REFERENCES `tjpi_previnculadointervencao` (`id`),
  CONSTRAINT `FK8EB454E47523F763` FOREIGN KEY (`manifestacao_id`) REFERENCES `aproc_manifestacao` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=125009
```

### `presenca_estacao_predio`
```sql
CREATE TABLE `presenca_estacao_predio` (
  `estacaoPonto_id` int(11) NOT NULL,
  `predio_id` bigint(20) NOT NULL,
  KEY `FK411571583D46E989` (`predio_id`),
  KEY `FK411571584B7CF2F5` (`estacaoPonto_id`),
  CONSTRAINT `FK411571583D46E989` FOREIGN KEY (`predio_id`) REFERENCES `global_predio` (`id`),
  CONSTRAINT `FK411571584B7CF2F5` FOREIGN KEY (`estacaoPonto_id`) REFERENCES `presenca_estacaoponto` (`id`)
) ENGINE=InnoDB
```

### `presenca_estacaoponto`
```sql
CREATE TABLE `presenca_estacaoponto` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `codigoAtivacao` varchar(255) DEFAULT NULL,
  `codigoUnicoMaquina` varchar(255) DEFAULT NULL,
  `descricao` varchar(255) DEFAULT NULL,
  `anydesk` varchar(11) DEFAULT NULL,
  `teamviewer` varchar(15) DEFAULT NULL,
  `momentoFim` date DEFAULT NULL,
  `momentoInicio` date DEFAULT NULL,
  `obsAdmin` varchar(255) DEFAULT NULL,
  `responsavel_id` bigint(20) DEFAULT NULL,
  `versao` varchar(255) DEFAULT NULL,
  `liberadoBatidaManual` bit(1) DEFAULT NULL,
  `ativo` bit(1) DEFAULT NULL,
  `ativo_bkp` bit(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `codigoAtivacao` (`codigoAtivacao`),
  KEY `FK7813D6BC55D2C86A` (`responsavel_id`),
  CONSTRAINT `FK7813D6BC55D2C86A` FOREIGN KEY (`responsavel_id`) REFERENCES `sistema_usuario` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=633
```

### `presenca_estacaoponto_ping`
```sql
CREATE TABLE `presenca_estacaoponto_ping` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ip` varchar(255) DEFAULT NULL,
  `momento` datetime DEFAULT NULL,
  `versao` varchar(255) DEFAULT NULL,
  `estacaoPonto_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FKF2039154B7CF2F5` (`estacaoPonto_id`),
  KEY `presenca_epping_estacao_id_versao_IDX` (`estacaoPonto_id`,`versao`) USING BTREE,
  CONSTRAINT `FKF2039154B7CF2F5` FOREIGN KEY (`estacaoPonto_id`) REFERENCES `presenca_estacaoponto` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=94300258
```

### `presenca_frequentador`
```sql
CREATE TABLE `presenca_frequentador` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ativo` bit(1) NOT NULL,
  `vinculoPrincipal_id` bigint(20) DEFAULT NULL,
  `permitirManual` bit(1) DEFAULT NULL,
  `limitarAcumuloHoras` bit(1) DEFAULT NULL,
  `dataCadastro` datetime NOT NULL,
  `observacao` text DEFAULT NULL,
  `digitaisHash` text DEFAULT NULL,
  `diferenciado_id` bigint(20) DEFAULT NULL,
  `oficial_id` bigint(20) DEFAULT NULL,
  `temporario_id` bigint(20) DEFAULT NULL,
  `vinculado_id` bigint(20) DEFAULT NULL,
  `localTrabalhoPresenca_id` bigint(20) DEFAULT NULL,
  `cadastrador_id` bigint(20) DEFAULT NULL,
  `limitarPrediosPermitidosBaterPonto` bit(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FKFEC52F5C88D43AA8` (`temporario_id`),
  KEY `FKFEC52F5C7920819D` (`localTrabalhoPresenca_id`),
  KEY `FKFEC52F5CB8B99017` (`vinculado_id`),
  KEY `FKFEC52F5C8F61C153` (`oficial_id`),
  KEY `FKFEC52F5C8419A687` (`diferenciado_id`),
  KEY `FKFEC52F5CF7B04FEE` (`cadastrador_id`),
  KEY `FKFEC52F5C920953A9` (`vinculoPrincipal_id`),
  CONSTRAINT `FKFEC52F5C7920819D` FOREIGN KEY (`localTrabalhoPresenca_id`) REFERENCES `global_predio` (`id`),
  CONSTRAINT `FKFEC52F5C8419A687` FOREIGN KEY (`diferenciado_id`) REFERENCES `presenca_regimefrequentador` (`id`),
  CONSTRAINT `FKFEC52F5C88D43AA8` FOREIGN KEY (`temporario_id`) REFERENCES `presenca_regimefrequentador` (`id`),
  CONSTRAINT `FKFEC52F5C8F61C153` FOREIGN KEY (`oficial_id`) REFERENCES `presenca_regimefrequentador` (`id`),
  CONSTRAINT `FKFEC52F5C920953A9` FOREIGN KEY (`vinculoPrincipal_id`) REFERENCES `tjpi_vinculo` (`id`),
  CONSTRAINT `FKFEC52F5CB8B99017` FOREIGN KEY (`vinculado_id`) REFERENCES `tjpi_vinculado` (`id`),
  CONSTRAINT `FKFEC52F5CF7B04FEE` FOREIGN KEY (`cadastrador_id`) REFERENCES `sistema_usuario` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=8825
```

### `presenca_frequentador_predio`
```sql
CREATE TABLE `presenca_frequentador_predio` (
  `frequentador_id` int(11) NOT NULL,
  `predio_id` bigint(20) NOT NULL,
  UNIQUE KEY `U_Freq_Pred` (`frequentador_id`,`predio_id`),
  KEY `FKDCC8B94A2BE99F15` (`frequentador_id`),
  KEY `FKDCC8B94A3D46E989` (`predio_id`),
  CONSTRAINT `FKDCC8B94A2BE99F15` FOREIGN KEY (`frequentador_id`) REFERENCES `presenca_frequentador` (`id`),
  CONSTRAINT `FKDCC8B94A3D46E989` FOREIGN KEY (`predio_id`) REFERENCES `global_predio` (`id`)
) ENGINE=InnoDB
```

### `presenca_gestorindividual`
```sql
CREATE TABLE `presenca_gestorindividual` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `vinculado_id` bigint(20) DEFAULT NULL,
  `frequentador_id` int(11) DEFAULT NULL,
  `dataCriacao` datetime DEFAULT NULL,
  `dataExclusao` datetime DEFAULT NULL,
  `observacao` text DEFAULT NULL,
  `ativo` bit(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK94EC18432BE99F15` (`frequentador_id`),
  KEY `FK94EC1843B8B99017` (`vinculado_id`),
  CONSTRAINT `FK94EC18432BE99F15` FOREIGN KEY (`frequentador_id`) REFERENCES `presenca_frequentador` (`id`),
  CONSTRAINT `FK94EC1843B8B99017` FOREIGN KEY (`vinculado_id`) REFERENCES `tjpi_vinculado` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=937
```

### `presenca_historicotarefa`
```sql
CREATE TABLE `presenca_historicotarefa` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `dtAdicao` datetime DEFAULT NULL,
  `dtExecucao` datetime DEFAULT NULL,
  `hashTarefa` text DEFAULT NULL,
  `tipoEntidade` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2589453
```

### `presenca_regime`
```sql
CREATE TABLE `presenca_regime` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `nome` varchar(255) DEFAULT NULL,
  `hashExpediente` text DEFAULT NULL,
  `modalidade` varchar(255) DEFAULT NULL,
  `permitidoCompensarFalta` bit(1) DEFAULT NULL,
  `permitidoAcumularHoras` bit(1) DEFAULT NULL,
  `permitidoContabilizarHorasMesmoComMetaZero` bit(1) DEFAULT NULL,
  `excluido` bit(1) DEFAULT NULL,
  `visivel` bit(1) DEFAULT NULL,
  `liberadoLimitacaoInicioHoraExtra` bit(1) NOT NULL,
  `limiteCredito` int(11) DEFAULT NULL,
  `limiteDebito` int(11) DEFAULT NULL,
  `limiteDiasCargaMinima` int(11) DEFAULT NULL,
  `percentualCargaMinima` int(11) DEFAULT NULL,
  `podeFaltar` bit(1) NOT NULL,
  `global` bit(1) NOT NULL,
  `inicio` date DEFAULT NULL,
  `padrao_id` bigint(20) DEFAULT NULL,
  `anterior_id` bigint(20) DEFAULT NULL,
  `maximoBancoHorasDiarioEmSegundos` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK458B52F5818E24CA` (`anterior_id`),
  KEY `FK458B52F558BF18B5` (`padrao_id`),
  CONSTRAINT `FK458B52F558BF18B5` FOREIGN KEY (`padrao_id`) REFERENCES `presenca_regime` (`id`),
  CONSTRAINT `FK458B52F5818E24CA` FOREIGN KEY (`anterior_id`) REFERENCES `presenca_regime` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=324
```

### `presenca_regime_categoriavinculo`
```sql
CREATE TABLE `presenca_regime_categoriavinculo` (
  `regime_id` bigint(20) NOT NULL,
  `categoria` varchar(255) DEFAULT NULL,
  KEY `FK5CEAAF87B0C84CB5` (`regime_id`),
  CONSTRAINT `FK5CEAAF87B0C84CB5` FOREIGN KEY (`regime_id`) REFERENCES `presenca_regime` (`id`)
) ENGINE=InnoDB
```

### `presenca_regimefrequentador`
```sql
CREATE TABLE `presenca_regimefrequentador` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `frequentador_id` int(11) DEFAULT NULL,
  `tipo` varchar(255) DEFAULT NULL,
  `regime_id` bigint(20) DEFAULT NULL,
  `momentoInicial` datetime DEFAULT NULL,
  `momentoFinal` datetime DEFAULT NULL,
  `dataAlteracao` datetime DEFAULT NULL,
  `excluido` bit(1) DEFAULT NULL,
  `momentoFinalOriginal` datetime DEFAULT NULL,
  `momentoInicialOriginal` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FKD557E4892BE99F15` (`frequentador_id`),
  KEY `FKD557E489B0C84CB5` (`regime_id`),
  CONSTRAINT `FKD557E4892BE99F15` FOREIGN KEY (`frequentador_id`) REFERENCES `presenca_frequentador` (`id`),
  CONSTRAINT `FKD557E489B0C84CB5` FOREIGN KEY (`regime_id`) REFERENCES `presenca_regime` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=36532
```

### `presenca_registroestacaoponto`
```sql
CREATE TABLE `presenca_registroestacaoponto` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `arquivoCriptografado` text DEFAULT NULL,
  `momentoProcessamento` datetime DEFAULT NULL,
  `momentoSinc` datetime DEFAULT NULL,
  `processado` bit(1) NOT NULL,
  `estacao_id` int(11) DEFAULT NULL,
  `ip` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FKD04B8A6F987EA1D3` (`estacao_id`),
  CONSTRAINT `FKD04B8A6F987EA1D3` FOREIGN KEY (`estacao_id`) REFERENCES `presenca_estacaoponto` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4973560
```

### `presenca_registrofrequencia`
```sql
CREATE TABLE `presenca_registrofrequencia` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `horario` varchar(255) DEFAULT NULL,
  `modo` varchar(255) DEFAULT NULL,
  `momento` datetime DEFAULT NULL,
  `momentoSincOffline` datetime DEFAULT NULL,
  `operacao` varchar(255) DEFAULT NULL,
  `ressalva` bit(1) NOT NULL,
  `zona` varchar(255) DEFAULT NULL,
  `frequentador_id` int(11) DEFAULT NULL,
  `manifestacao_id` bigint(20) DEFAULT NULL,
  `estacaoPonto_id` int(11) DEFAULT NULL,
  `intervencao_id` bigint(20) DEFAULT NULL,
  `lotacaoEpoca_id` int(11) DEFAULT NULL,
  `ativo` bit(1) DEFAULT NULL,
  `momentoParaCalculo` datetime DEFAULT NULL,
  `registroEstacaoPonto_id` bigint(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK4847F1502BE99F15` (`frequentador_id`),
  KEY `FK4847F1507523F763` (`manifestacao_id`),
  KEY `FK4847F1504B7CF2F5` (`estacaoPonto_id`),
  KEY `FK4847F15086502E9C` (`lotacaoEpoca_id`),
  KEY `FK4847F1506CCCAAAD` (`intervencao_id`),
  KEY `FK4847F150B6C9BB35` (`registroEstacaoPonto_id`),
  CONSTRAINT `FK4847F1502BE99F15` FOREIGN KEY (`frequentador_id`) REFERENCES `presenca_frequentador` (`id`),
  CONSTRAINT `FK4847F1504B7CF2F5` FOREIGN KEY (`estacaoPonto_id`) REFERENCES `presenca_estacaoponto` (`id`),
  CONSTRAINT `FK4847F1506CCCAAAD` FOREIGN KEY (`intervencao_id`) REFERENCES `tjpi_previnculadointervencao` (`id`),
  CONSTRAINT `FK4847F1507523F763` FOREIGN KEY (`manifestacao_id`) REFERENCES `aproc_manifestacao` (`id`),
  CONSTRAINT `FK4847F15086502E9C` FOREIGN KEY (`lotacaoEpoca_id`) REFERENCES `global_orgao` (`id`),
  CONSTRAINT `FK4847F150B6C9BB35` FOREIGN KEY (`registroEstacaoPonto_id`) REFERENCES `presenca_registroestacaoponto` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=9190008
```

### `presenca_registromensalfrequencia`
```sql
CREATE TABLE `presenca_registromensalfrequencia` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `frequentador_id` int(11) DEFAULT NULL,
  `mes` int(11) NOT NULL,
  `ano` int(11) NOT NULL,
  `diasEmAberto` int(11) NOT NULL,
  `faltas` int(11) NOT NULL,
  `faltasADescontar` int(11) DEFAULT NULL,
  `faltasACompensar` int(11) DEFAULT NULL,
  `acumulado` int(11) NOT NULL,
  `ausentes` int(11) NOT NULL,
  `data` date DEFAULT NULL,
  `dataFim` date DEFAULT NULL,
  `dataInicio` date DEFAULT NULL,
  `metaAtual` int(11) NOT NULL,
  `metaAtualDias` int(11) NOT NULL,
  `metaMensal` int(11) NOT NULL,
  `metaMensalDias` int(11) NOT NULL,
  `momentoUltimoCalculo` datetime DEFAULT NULL,
  `retido` int(11) NOT NULL,
  `saldoLiquido` int(11) NOT NULL,
  `tempoAusenteDeFalta` int(11) NOT NULL,
  `trabalhado` int(11) NOT NULL,
  `trabalhadoDias` int(11) NOT NULL,
  `trabalhadoExcepcional` int(11) NOT NULL,
  `trabalhadoNormal` int(11) NOT NULL,
  `retificado` int(11) DEFAULT NULL,
  `creditoADevolver` int(11) DEFAULT NULL,
  `finalizado` bit(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `presenca_rmf_fid_mes_ano_IDX` (`frequentador_id`,`mes`,`ano`) USING BTREE,
  KEY `FK67CC3D582BE99F15` (`frequentador_id`),
  CONSTRAINT `FK67CC3D582BE99F15` FOREIGN KEY (`frequentador_id`) REFERENCES `presenca_frequentador` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=464652
```

### `presenca_relatoriofrequenciafinal`
```sql
CREATE TABLE `presenca_relatoriofrequenciafinal` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `ano` varchar(255) DEFAULT NULL,
  `dataAlteracao` datetime DEFAULT NULL,
  `dataGeracao` datetime DEFAULT NULL,
  `mes` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC
```

### `presenca_relatoriofrequentador`
```sql
CREATE TABLE `presenca_relatoriofrequentador` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `resultado` int(11) NOT NULL,
  `saldoBruto` int(11) NOT NULL,
  `valorRetroativo` int(11) NOT NULL,
  `frequentador_id` int(11) DEFAULT NULL,
  `relatorioFrequenciaFinal_id` bigint(20) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FK702B87212BE99F15` (`frequentador_id`),
  KEY `FK702B87217C826355` (`relatorioFrequenciaFinal_id`),
  CONSTRAINT `FK702B87212BE99F15` FOREIGN KEY (`frequentador_id`) REFERENCES `presenca_frequentador` (`id`),
  CONSTRAINT `FK702B87217C826355` FOREIGN KEY (`relatorioFrequenciaFinal_id`) REFERENCES `presenca_relatoriofrequenciafinal` (`id`)
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC
```

### `presenca_retificadorbancohoras`
```sql
CREATE TABLE `presenca_retificadorbancohoras` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `ano` int(11) NOT NULL,
  `mes` int(11) NOT NULL,
  `momentoRegistro` datetime DEFAULT NULL,
  `informacao` text DEFAULT NULL,
  `observacao` text DEFAULT NULL,
  `segundosARetificar` int(11) NOT NULL,
  `tipo` varchar(255) DEFAULT NULL,
  `responsavel_login` varchar(30) DEFAULT NULL,
  `calculoDiario_id` int(11) DEFAULT NULL,
  `frequentador_id` int(11) DEFAULT NULL,
  `excluido` bit(1) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FKA126AB782BE99F15` (`frequentador_id`),
  KEY `FKA126AB7882012866` (`responsavel_login`),
  KEY `FKA126AB7860A69AFF` (`calculoDiario_id`),
  CONSTRAINT `FKA126AB782BE99F15` FOREIGN KEY (`frequentador_id`) REFERENCES `presenca_frequentador` (`id`),
  CONSTRAINT `FKA126AB7860A69AFF` FOREIGN KEY (`calculoDiario_id`) REFERENCES `presenca_calculodiario` (`id`),
  CONSTRAINT `FKA126AB7882012866` FOREIGN KEY (`responsavel_login`) REFERENCES `admin_user` (`login`)
) ENGINE=InnoDB AUTO_INCREMENT=52767
```

### `presenca_valorretroativo`
```sql
CREATE TABLE `presenca_valorretroativo` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `ano` int(11) NOT NULL,
  `dataGeracao` datetime DEFAULT NULL,
  `mes` int(11) NOT NULL,
  `numeroHora` int(11) NOT NULL,
  `processo` varchar(255) DEFAULT NULL,
  `frequentador_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `FKC19C6D2BE99F15` (`frequentador_id`),
  CONSTRAINT `FKC19C6D2BE99F15` FOREIGN KEY (`frequentador_id`) REFERENCES `presenca_frequentador` (`id`)
) ENGINE=InnoDB
```

### `presenca_versaoestacaoponto`
```sql
CREATE TABLE `presenca_versaoestacaoponto` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `novidade` varchar(255) DEFAULT NULL,
  `numVersao` varchar(255) DEFAULT NULL,
  `releaseDate` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `numVersao` (`numVersao`)
) ENGINE=InnoDB AUTO_INCREMENT=12
```

---

## Checklist de Reconciliação (schema físico × bean Java)

| Verificação | Bean Java (esperado) | Banco real (confirmado) | Resolução |
|-------------|----------------------|--------------------------|-----------|
| **`presenca_registrofrequencia` unique** | `uniqueConstraints` de 6 col (Java l.28) | **NÃO há unique index no banco** — só PK + FKs | ⚠️ **Divergência:** unicidade/dedup NÃO é ensinada no DB; só na aplicação (`getRegistroByData`). Reforçar no alvo via índice único OU manter dedup lógico confirmando voluntariamente |
| **`estacaoponto.codigoAtivacao` unique** | unique | ✅ **UNIQUE KEY `codigoAtivacao``** confirmado | ✅ Ok |
| **`versaoestacaoponto.numVersao` unique** | unique | ✅ **UNIQUE KEY `numVersao``` confirmado | ✅ Ok |
| **`digitaisHash` tipo** | `@Lob` String (Java) | **`text`** | ✅ Ok (mapeado como text, não blob) |
| **`RelatorioFrequenciaFinal.mes/ano`** | String (Java) | **`varchar(255)`** | ✅ **Ok — banco é String também** (DUV-008 parcialmente: orgao não existe, ver abaixo) |
| **`RelatorioFrequenciaFinal.orgao`** | campo **comentado** no bean | **coluna NÃO existe** | ✅ **Sem coluna `orgao`** (DUV-008: coluna ausente no banco também → não portar) |
| **`retificadorbancohoras.calculoDiario_id`** | **não mapeado** no bean | **coluna EXISTE** (`calculoDiario_id` int, FK→`presenca_calculodiario`) | ⚠️ **Divergência confirmada:** coluna existe no banco mas bean NÃO mapeia (DUV-007). O DAO `findByCalculoDiario` referencia uma coluna real, mas o bean não expõe o campo — inconsistência de camada a resolver |
| **`registromensalfrequencia.segsAcumulavelMensal`** | **não mapeado** no bean | **coluna NÃO existe** | ✅ **Confirmado ausente** (DUV-006: método DAO `getUltimoAcumulavel` é morto) |
| **`debitoremanscentenegociavel`** | entidade (código morto) | tabela existe, **0 linhas**, FKs p/ `aproc` + `registromensal` | ✅ Confirma código morto (DUV-009) |
| `estacaoponto.ativo_bkp` | não documentado | coluna existe | ⚠️ coluna extra não mapeada no inventário original — **backup de ativo**; registrar |
| `frequentador.vinculoPrincipal_id / oficial_id / temporario_id / diferenciado_id` | não detalhado no inventário | colunas existem, FK→`presenca_regimefrequentador`/`tjpi_vinculo` | ⚠️ **colunas de vínculo de regime** a registrar (relação frequentador↔regime "atual") |

---

## Descobertas novas (relevantes p/ PRD/migração)

1. **Índices de performance em `presenca_calculodiario`:** `idx_data`, `idx_data_frequentador`, `idx_frequentador_data` — o cálculo consulta por dia×frequentador intensivamente.
2. **FKs para módulos externos (não-presenca):** `tjpi_vinculado`, `tjpi_vinculo`, `tjpi_previnculadointervencao`, `aproc_manifestacao`, `global_orgao`, `global_predio`, `sistema_usuario`, `admin_user`. A migração do Frequência não pode trazer essas tabelas — precisa de **ACL/IDs** (ver `03-dominio/02-bounded-contexts.md`).
3. **`presenca_registrofrequencia` é a tabela mais volumosa** (`AUTO_INCREMENT=9190008`), seguida de `presenca_estacaoponto_ping` (`94300258`), `presenca_calculodiario` (`14253258`) e `presenca_historicotarefa` (`2589453`) — **dimensionar migração de dados**.
4. **charset `latin1`** em todas as tabelas — atenção para dados acentuados ao migrar para UTF-8 no PostgreSQL alvo.
5. **`presenca_registromensalfrequencia` tem UNIQUE `(frequentador_id, mes, ano)`** — reforça o agregado AG-4 (1 registro por frequentador×mês).

---

## Pendências restantes (gate de fechamento)

- [ ] **#9 View `presenca_frequentadorestacao` NÃO existe** neste banco local — verificar se existe em produção ou se é criada no deploy; é **view usada pela EstaçãoPonto** (`07-estacao-ponto/02-endpoints-consumidos.md` EP-02). Se não houver, dimensionar migração para um modelo equivalente.
- [ ] Confirmar o **nome exato** e o tipo de `admin_user` vs `sistema_usuario` (duas tabelas de usuário distintas: uma p/ `responsavel_id` (`sistema_usuario`), outra p/ `responsavel_login` (`admin_user.login`)).
- [ ] Validar com o time de dados se o schema capturado (amostra local) é **idêntico ao de produção** (idêntico em estrutura; dados não).

---
**Última atualização:** 2026-08-05
**Fase:** 1 — Inventário (schema físico confirmado)
**Coleta:** conexão direta MySQL `intranet` (MariaDB 10.4.32)
