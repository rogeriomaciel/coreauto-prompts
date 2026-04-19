drop table if exists config;
drop table if exists usuariossocial;
drop table if exists os_eventos;
drop table if exists ordens_servico;
drop table if exists veiculos;
drop table if exists usuarios;
drop table if exists pessoas;
drop table if exists knowledge_base;
drop table if exists lojas;
drop table if exists prompts;
drop type if exists tipo_pessoa;
drop type if exists tipo_evento_os;
drop type if exists origem_evento;


-- Tabela de Configuração Global 
CREATE TABLE
  config (
    config_id integer NOT NULL,
    configname character varying(50) NULL,
    configdata json NULL,
    updateat timestamp without time zone NULL
  );

ALTER TABLE
  config
ADD
  CONSTRAINT config_pkey PRIMARY KEY (config_id);


-- Tabela para controle de login com o google
CREATE TABLE
  usuariossocial (
    id serial NOT NULL,
    google_id character varying(255) NULL,
    email character varying(255) NULL,
    name character varying(255) NULL,
    picture varchar(255) null,
    phone_number character varying(20) NULL
  );

ALTER TABLE
  usuariossocial
ADD
  CONSTRAINT usuariossocial_pkey PRIMARY KEY (id);

-- Habilita a extensão para geração de UUIDs v4 (Padrão PostgreSQL)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================
-- 1. ENTIDADES DE ESTRUTURA E CONTROLE (SaaS/Multitenancy)
-- ==========================================

-- O "Prompt" que executa a CORA
CREATE TABLE prompts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    categoria VARCHAR(50),
    conteudo TEXT NOT NULL, 
    file_name VARCHAR(255), -- Link/Nome do arquivo original para auditoria    
    autorizado_em TIMESTAMPTZ, -- Preenchido quando o dono valida no sistema
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Tabela principal que isola os dados de cada cliente 
CREATE TABLE lojas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), 
    prompt_id UUID REFERENCES prompts(id) ,
    nome VARCHAR(255) NOT NULL, 
    whatsapp_loja VARCHAR(20) UNIQUE NOT NULL, -- Chave de contexto para a CORA
    config_json JSONB NOT NULL DEFAULT '{"assistente": {"nome":"Cora", "pronomes": "Ela/Dela"}, "evolutionapi":{"apikey":"valorKeyAPI","instanceName":"nomeInstance","EVOLUTIONAPI_URL_BASE":"https://urlevolution.com.br"}}', -- Regras de negócio, termos e horários
    
    -- Configurações de UI/UX do Dashboard
    dashboard_settings JSONB NOT NULL DEFAULT '{
        "theme": "light",
        "primary_color": "#007bff",
        "visible_charts": ["faturamento", "os_status", "produtividade"],
        "refresh_interval": 300
    }',
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- O "Cérebro" de apoio da CORA: Armazena a verdade factual 
CREATE TABLE knowledge_base (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loja_id UUID NOT NULL REFERENCES lojas(id) ON DELETE CASCADE,
    categoria VARCHAR(50), -- Ex: 'preços', 'FAQ', 'procedimentos'
    conteudo TEXT NOT NULL, -- O dado textual processado
    
    -- Se nulo, a CORA não utiliza a informação
    autorizado_em TIMESTAMPTZ, -- Preenchido quando o dono valida no sistema
    
    fonte_arquivo VARCHAR(255), -- Link/Nome do arquivo original para auditoria
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);



-- ==========================================
-- 2. GESTÃO DE ACESSO E PERSONAGENS
-- ==========================================

CREATE TYPE tipo_pessoa AS ENUM ('cliente', 'consultor', 'mecanico');

CREATE TABLE pessoas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loja_id UUID NOT NULL REFERENCES lojas(id) ON DELETE CASCADE,
    nome VARCHAR(255) NOT NULL,
    whatsapp VARCHAR(20) UNIQUE NOT NULL,
    picture_url TEXT,

    tipo tipo_pessoa DEFAULT 'cliente',
    
    -- A "Mente Dupla": Resumo histórico e conversas recentes
    contexto_memoria JSONB NOT NULL DEFAULT '{"resumo_historico": "", "conversas_recentes": []}',
    status VARCHAR(20) DEFAULT 'ativo',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    fila_mensagens JSONB NOT NULL DEFAULT '{}',
    last_message_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    start_process_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    processando_message BOOLEAN DEFAULT FALSE

);

-- Tabela para acesso ao Dashboard (Login Email/Senha ou Google)
CREATE TABLE usuarios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loja_id UUID NOT NULL REFERENCES lojas(id) ON DELETE CASCADE,
    pessoa_id UUID UNIQUE REFERENCES pessoas(id) ON DELETE SET NULL, -- Vincula o login ao perfil operacional
    nome VARCHAR(255) NOT NULL,
    whatsapp varchar(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT, -- Nulo se usar apenas login social
    google_id VARCHAR(255) UNIQUE, -- ID para Login com Google
    avatar_url TEXT,
    ultimo_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- 3. ATIVOS E OPERAÇÃO
-- ==========================================

CREATE TABLE veiculos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cliente_id UUID NOT NULL REFERENCES pessoas(id) ON DELETE CASCADE,
    placa VARCHAR(20) UNIQUE NOT NULL,
    marca VARCHAR(100),
    modelo VARCHAR(100),
    ano VARCHAR(4),
    cor VARCHAR(50),
    km_atual INTEGER,
    metadata JSONB DEFAULT '{}', -- Observações extras (ex: detalhes pintura)
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ordens_servico (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loja_id UUID NOT NULL REFERENCES lojas(id) ON DELETE CASCADE,
    veiculo_id UUID NOT NULL REFERENCES veiculos(id),
    cliente_id UUID NOT NULL REFERENCES pessoas(id),
    consultor_id UUID REFERENCES pessoas(id),
    mecanico_id UUID REFERENCES pessoas(id),
    status VARCHAR(50) NOT NULL DEFAULT 'triagem',
    descricao_problema TEXT,
    orcamento_json JSONB DEFAULT '[]',
    valor_total DECIMAL(12, 2) DEFAULT 0.00,
    agendado_para TIMESTAMPTZ,                   -- Data e hora confirmadas pelo consultor para recebimento do veículo
    data_diagnostico TIMESTAMPTZ,
    data_entrada TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    data_conclusao TIMESTAMPTZ
);

CREATE TYPE tipo_evento_os AS ENUM ('atribuicao', 'checklist_progresso', 'validacao', 'finalizacao', 'comunicacao');
CREATE TYPE origem_evento AS ENUM ('whatsapp', 'sistema');

-- Linha do tempo factual: Preserva a voz original e as ações
CREATE TABLE os_eventos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    os_id UUID NOT NULL REFERENCES ordens_servico(id) ON DELETE CASCADE,
    pessoa_id UUID NOT NULL REFERENCES pessoas(id),
    tipo_evento tipo_evento_os NOT NULL,
    descricao TEXT,
    audio_base64 TEXT, -- Prova de verdade absoluta (voz original)
    origem origem_evento DEFAULT 'whatsapp',
    contexto_json JSONB DEFAULT '{}',
    data_registro TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- ÍNDICES DE PERFORMANCE
-- ==========================================

CREATE INDEX idx_pessoas_whatsapp ON pessoas(whatsapp);
CREATE INDEX idx_kb_loja_categoria ON knowledge_base(loja_id, categoria);
CREATE INDEX idx_os_eventos_ordem ON os_eventos(os_id, data_registro DESC);
CREATE INDEX idx_os_loja_status ON ordens_servico(loja_id, status);
CREATE INDEX idx_os_agendado_para ON ordens_servico(loja_id, agendado_para) WHERE agendado_para IS NOT NULL;
-- Garante que só pode existir uma OS ativa por veículo nos status de entrada.
CREATE UNIQUE INDEX idx_unique_pre_os_por_veiculo ON ordens_servico (veiculo_id) WHERE status IN ('pre_os', 'aguardando_agenda');


insert into prompts ("categoria", "conteudo", "id", "file_name") values ('Oficina', 'default', 'cdcfa329-c519-4ff7-be7b-ff021b2692c7', 'prompt_mestre_oficina.md');
insert into lojas ("id", "config_json", "created_at", "nome", "whatsapp_loja", "prompt_id") values ('adcfa329-c519-4ff7-be7b-ff021b2692c7', '{"assistente": {"nome": "Kadu", "pronomes": "Ela/Dela", "nome_completo": "Kamila Eduarda", "estado_civil": "solteira", "data_nascimento": "04-02-2005"}, "evolutionapi":{"apikey":"CxSFXk2tGLFW2WwqVR59jR","instanceName":"coreauto","EVOLUTIONAPI_URL_BASE":"https://evolution.rogeriomaciel.com.br"}}', '2026-02-28 19:27:47.653468+00', 'Kadosh', '556296425277', 'cdcfa329-c519-4ff7-be7b-ff021b2692c7');
insert into usuarios ("loja_id", "nome", "whatsapp", "email", "password_hash") values ('adcfa329-c519-4ff7-be7b-ff021b2692c7', 'Rogerio Maciel', '556296232227', 'rogerio@rogeriomaciel.com.br', '$2a$10$2s.vUdpT2.623.RuTeEsfOADamtwJoOOw39G6Of00JwLkwcYge/R.');
insert into config ("config_id", "configdata", "configname", "updateat") values (1, '{"INTERNAL_SECRET":"MEUSEGREDOMAISSECRETO"}', 'CONTROLPANEL', NULL);