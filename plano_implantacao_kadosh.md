# Plano de Implantação — Oficina Kadosh
**Início efetivo:** 02/04/2026  
**Formato:** Visitas diárias de 1h na empresa  
**Assistente IA:** Kadu (Kamila Eduarda)  
**WhatsApp:** 556296425277  
**Loja ID:** adcfa329-c519-4ff7-be7b-ff021b2692c7

---

## Status da Implantação

| Item | Status |
|---|---|
| Infraestrutura (DB, n8n, Evolution API) | ✅ Concluído |
| Workflows importados e ativos no n8n | ✅ Concluído |
| WhatsApp conectado (instância "coreauto") | ✅ Concluído |
| Cadastro de consultores e mecânicos | ⏳ Pendente |
| Testes de fluxo | ⏳ Pendente |
| Knowledge base | ⏳ Pendente |
| Treinamento da equipe | ⏳ Pendente |
| Go-live monitorado | ⏳ Pendente |

---

## Dia 1 — 02/04/2026 | Cadastro de Pessoas

**Objetivo:** Cadastrar todos os funcionários da Kadosh no sistema.

### O que fazer (1h)
1. **Levantar com o dono** (10min):
   - Nome completo e WhatsApp de cada **consultor**
   - Nome completo e WhatsApp de cada **mecânico**
   - Confirmar o formato do número (deve ser igual ao que aparece no WhatsApp: `5562XXXXXXXXX`)

2. **Inserir no DB** (30min):
```sql
-- Consultor (repetir para cada um)
INSERT INTO pessoas (id, nome, whatsapp, tipo_pessoa, loja_id, contexto_memoria)
VALUES (
  gen_random_uuid(),
  'Nome do Consultor',
  '5562XXXXXXXXX',
  'consultor',
  'adcfa329-c519-4ff7-be7b-ff021b2692c7',
  '{}'
);

-- Mecânico (repetir para cada um)
INSERT INTO pessoas (id, nome, whatsapp, tipo_pessoa, loja_id, contexto_memoria)
VALUES (
  gen_random_uuid(),
  'Nome do Mecânico',
  '5562XXXXXXXXX',
  'mecanico',
  'adcfa329-c519-4ff7-be7b-ff021b2692c7',
  '{}'
);
```

3. **Verificar** (10min):
```sql
SELECT nome, whatsapp, tipo_pessoa 
FROM pessoas 
WHERE loja_id = 'adcfa329-c519-4ff7-be7b-ff021b2692c7'
ORDER BY tipo_pessoa, nome;
```

4. **Teste rápido de sanidade** (10min):
   - Enviar "oi" do WhatsApp de um consultor cadastrado para o número da loja
   - Verificar que o n8n recebe, processa e responde (não precisa estar correto ainda, só não pode dar erro 500)

**Entrega do dia:** Todos os funcionários cadastrados; sistema recebendo mensagens sem erro crítico.

---

## Dia 2 — 03/04/2026 | Teste do Fluxo Básico — Consultor

**Objetivo:** Validar que o consultor consegue navegar pelo LOBBY e selecionar uma OS.

### Pré-requisito
Criar 1 OS manualmente no DB para ter algo para selecionar no teste:
```sql
-- Criar cliente fictício de teste
INSERT INTO pessoas (id, nome, whatsapp, tipo_pessoa, loja_id, contexto_memoria)
VALUES (gen_random_uuid(), 'Cliente Teste', '5562000000000', 'cliente', 'adcfa329-c519-4ff7-be7b-ff021b2692c7', '{}')
RETURNING id; -- anote o id

-- Criar veículo de teste
INSERT INTO veiculos (id, placa, modelo, marca, cliente_id, loja_id)
VALUES (gen_random_uuid(), 'ABC1D23', 'HB20', 'Hyundai', '<cliente_id_acima>', 'adcfa329-c519-4ff7-be7b-ff021b2692c7')
RETURNING id; -- anote o id

-- Criar OS de teste
INSERT INTO ordens_servico (id, cliente_id, veiculo_id, loja_id, status, descricao_problema)
VALUES (gen_random_uuid(), '<cliente_id>', '<veiculo_id>', 'adcfa329-c519-4ff7-be7b-ff021b2692c7', 'em_diagnostico', 'Teste de implantação')
RETURNING id;
```

### Script de teste (executar com consultor real)
| Passo | Ação | Resultado esperado |
|---|---|---|
| 1 | Consultor envia "oi" | Kadu responde com LOBBY — lista de OSs abertas |
| 2 | Consultor seleciona a OS de teste | Kadu confirma e entra no módulo do status da OS |
| 3 | Consultor digita "voltar" | Kadu volta para o LOBBY |
| 4 | Verificar DB | `contexto_memoria.actionDataContext.faseCore` deve ser `LOBBY_OPERACIONAL` |

### O que monitorar no n8n
- Abrir painel de execuções do workflow `COREAUTOCRM-RECEPCAO-MENSAGEM`
- Verificar que cada mensagem gera uma execução bem-sucedida (verde)
- Em caso de erro: anotar o nó que falhou e a mensagem de erro

**Entrega do dia:** Consultor entra no LOBBY, seleciona OS, volta ao LOBBY — sem erros.

---

## Dia 3 — 04/04/2026 | Teste do Fluxo de Abertura de OS

**Objetivo:** Validar que o consultor consegue abrir uma nova OS via WhatsApp.

### Script de teste
| Passo | Ação | Resultado esperado |
|---|---|---|
| 1 | Consultor envia "oi" | LOBBY exibido |
| 2 | Consultor diz "quero abrir uma OS nova" | Kadu inicia RECEPCAO_VEICULO |
| 3 | Consultor informa dados do veículo (placa, modelo, problema) | Kadu coleta e confirma |
| 4 | Sistema registra a OS | OS aparece no DB (`ordens_servico`) |
| 5 | Consultor volta ao LOBBY | Nova OS aparece na lista |

### Verificação no DB após o teste
```sql
-- Verificar OS criada
SELECT os.id, os.status, os.descricao_problema, v.placa, p.nome as cliente
FROM ordens_servico os
JOIN veiculos v ON v.id = os.veiculo_id
JOIN pessoas p ON p.id = os.cliente_id
WHERE os.loja_id = 'adcfa329-c519-4ff7-be7b-ff021b2692c7'
ORDER BY os.created_at DESC
LIMIT 5;
```

**Entrega do dia:** Abertura de OS real via WhatsApp funcionando.

---

## Dia 4 — 05/04/2026 | Teste do Fluxo de Diagnóstico e Execução

**Objetivo:** Validar que o consultor consegue atualizar o status da OS durante o trabalho.

### Script de teste
| Passo | Ação | Resultado esperado |
|---|---|---|
| 1 | Consultor entra em uma OS com status `em_diagnostico` | Módulo DIAGNOSTICO carregado |
| 2 | Consultor relata o diagnóstico | Kadu registra e atualiza a OS |
| 3 | Consultor avança para execução | Status muda para `em_execucao` |
| 4 | Consultor informa que terminou o serviço | Status avança para próxima fase |
| 5 | Verificar `os_eventos` | Eventos devem estar registrados em sequência |

### Verificação de eventos
```sql
SELECT tipo_evento, descricao, created_at
FROM os_eventos
WHERE os_id = '<id_da_os>'
ORDER BY created_at;
```

**Entrega do dia:** Fluxo diagnóstico → execução funcionando com eventos registrados.

---

## Dia 5 — 06/04/2026 | Teste do Fluxo de Agendamento

**Objetivo:** Validar o step machine do módulo CONFIRMACAO_AGENDA end-to-end.

### Pré-requisito
Ter uma OS com `status = 'aguardando_agenda'`:
```sql
UPDATE ordens_servico SET status = 'aguardando_agenda'
WHERE id = '<id_de_uma_os>'
  AND loja_id = 'adcfa329-c519-4ff7-be7b-ff021b2692c7';
```

### Script de teste
| Passo | Step da OS | Ação do consultor | Resultado esperado |
|---|---|---|---|
| 1 | null | Consultor entra na OS | Kadu apresenta OS e pede data/hora **(Saída 1)** |
| 2 | `aguardando_data_hora` | Consultor informa "dia 10 às 9h" | Kadu confirma e pede confirmação **(Saída 2)** |
| 3 | `aguardando_confirmacao_consultor` | Consultor diz "sim, confirmar" | Kadu dispara CONFIRMAR_AGENDA_CONSULTOR **(Saída 3)** |
| 4 | — | Verificar DB | OS com data agendada; evento criado; cliente notificado |

### Se alguma saída errar
```sql
-- Resetar o step para testar novamente
UPDATE pessoas 
SET contexto_memoria = jsonb_set(
  contexto_memoria, 
  '{actionDataContext}', 
  '{"faseCore": "LOBBY_OPERACIONAL"}'::jsonb
)
WHERE whatsapp = '5562XXXXXXXXX'
  AND loja_id = 'adcfa329-c519-4ff7-be7b-ff021b2692c7';
```

**Entrega do dia:** Fluxo de agendamento completo (3 passos) funcionando sem travamento.

---

## Dia 6 — 07/04/2026 | Knowledge Base

**Objetivo:** Popular a KB com informações reais da Kadosh para personalizar as respostas da Kadu.

### Informações a coletar com o dono (30min)
- [ ] Horário de funcionamento (dias e horas)
- [ ] Tipos de serviço realizados (mecânica geral, elétrica, funilaria, etc.)
- [ ] Marcas de veículos atendidos
- [ ] Tempo médio por tipo de serviço (ex: "troca de óleo: 30min")
- [ ] Formas de pagamento aceitas
- [ ] Política de garantia dos serviços
- [ ] Informações de endereço e localização

### Inserir no DB (20min)
```sql
INSERT INTO knowledge_base (id, loja_id, categoria, conteudo)
VALUES 
  (gen_random_uuid(), 'adcfa329-c519-4ff7-be7b-ff021b2692c7', 'horario', 'Segunda a sexta das 8h às 18h, sábado das 8h às 12h'),
  (gen_random_uuid(), 'adcfa329-c519-4ff7-be7b-ff021b2692c7', 'servicos', 'Mecânica geral, elétrica automotiva, freios, suspensão, ar condicionado'),
  (gen_random_uuid(), 'adcfa329-c519-4ff7-be7b-ff021b2692c7', 'pagamento', 'Pix, cartão de crédito/débito, dinheiro. Parcelamento em até 3x no cartão'),
  (gen_random_uuid(), 'adcfa329-c519-4ff7-be7b-ff021b2692c7', 'garantia', '90 dias de garantia em peças e serviços');
  -- adicionar mais conforme dados coletados
```

### Teste (10min)
- Perguntar para a Kadu sobre horário de funcionamento
- Kadu deve responder com os dados da KB, não com informações genéricas

**Entrega do dia:** Kadu respondendo perguntas básicas com informações reais da oficina.

---

## Dia 7 — 08/04/2026 | Treinamento da Equipe

**Objetivo:** Capacitar os consultores para usar o sistema de forma independente.

### Agenda da visita (1h)
| Tempo | Atividade |
|---|---|
| 0-15min | Demonstração completa: abrir OS, diagnosticar, agendar, finalizar |
| 15-35min | Consultor usa sozinho (Rogerio só observa) |
| 35-50min | Dúvidas e cenários específicos da Kadosh |
| 50-60min | Combinados: o que fazer quando der problema |

### Pontos obrigatórios de explicar
- [ ] Escrever em português natural — a Kadu entende contexto
- [ ] Não precisa repetir informações que já foram ditas na conversa
- [ ] Se travar: enviar "voltar" ou "menu" para retornar ao LOBBY
- [ ] Reportar problemas: grupo WhatsApp de suporte (criar na visita)
- [ ] Não fechar o app durante uma OS ativa (o contexto é salvo, mas orientar)

### Criar grupo de suporte
- Criar grupo WhatsApp com: Rogerio + todos os consultores da Kadosh
- Nome sugerido: "Suporte Kadu — Kadosh"

**Entrega do dia:** Pelo menos 1 consultor usando o sistema sem ajuda. Grupo de suporte criado.

---

## Dia 8 — 09/04/2026 | Go-Live Monitorado

**Objetivo:** Primeira operação real do dia, com Rogerio presente acompanhando.

### O que fazer durante a visita (1h)
1. **Abertura do dia** (5min): verificar se há execuções com erro desde ontem no n8n
2. **Acompanhar o movimento real** (40min): consultores usam o sistema normalmente; Rogerio monitora n8n
3. **Corrigir na hora** (10min): problemas simples que aparecerem
4. **Resumo do dia** (5min): anotar o que funcionou e o que precisa ajuste

### Métricas de sucesso do go-live
| Métrica | Meta mínima |
|---|---|
| OSs abertas via sistema no dia | ≥ 1 |
| Execuções com erro no n8n | < 10% |
| Consultor precisou de ajuda para operar | ≤ 1 vez |
| Sistema ficou parado/indisponível | 0 minutos |

**Entrega do dia:** Primeira OS real criada e tratada 100% pelo sistema.

---

## Dias 9 em diante — Monitoramento Contínuo

**Objetivo:** Estabilizar o sistema e corrigir problemas reais de uso.

### Roteiro padrão de cada visita (1h)
| Tempo | Atividade |
|---|---|
| 0-10min | Revisar execuções n8n desde a visita anterior (erros, lentidão, gargalos) |
| 10-20min | Revisar DB: OSs em estado incoerente, contextos presos, dados faltando |
| 20-40min | Corrigir os problemas encontrados (prompt, workflow ou DB) |
| 40-50min | Testar a correção ao vivo com um consultor |
| 50-60min | Coletar feedback da equipe + definir foco da próxima visita |

### Problemas comuns e solução rápida
| Problema | Solução |
|---|---|
| Consultor travado, Kadu não responde direito | Reset de contexto (query abaixo) |
| OS não aparece no LOBBY | Verificar `status` da OS — deve ser diferente de `finalizado`/`cancelado` |
| Step machine de agenda não avança | Verificar `actionDataContext.step` no `contexto_memoria` |
| IA respondendo fora de contexto | Verificar qual módulo está ativo no `faseCore` |
| actionData incompleto num controlAction | Revisar o módulo correspondente no `prompt_mestre_oficina.md` |

### Reset de emergência (consultor travado)
```sql
UPDATE pessoas 
SET contexto_memoria = '{"actionDataContext": {"faseCore": "LOBBY_OPERACIONAL"}}'::jsonb
WHERE whatsapp = '5562XXXXXXXXX'
  AND loja_id = 'adcfa329-c519-4ff7-be7b-ff021b2692c7';
```

---

## Indicadores de Sucesso — 30 dias

| Indicador | Meta |
|---|---|
| OSs registradas via sistema | ≥ 20 |
| Consultores usando ativamente todo dia | 100% |
| Agendamentos confirmados via Kadu | ≥ 5 |
| Erros críticos (sistema parado) | 0 |
| Satisfação da equipe (1-5) | ≥ 4 |
| Rogerio precisou corrigir prompt | ≤ 3 vezes |

---

## Referências Rápidas

| Item | Valor |
|---|---|
| Loja ID | adcfa329-c519-4ff7-be7b-ff021b2692c7 |
| WhatsApp da loja | 556296425277 |
| Evolution API | evolution.rogeriomaciel.com.br |
| Instância Evolution | coreauto |
| Credencial n8n | COREAUTOCRM |
| Prompt | prompt_mestre_oficina.md |
