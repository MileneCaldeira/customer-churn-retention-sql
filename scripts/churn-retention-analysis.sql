-- ============================================================
-- ANÁLISE: Churn e Retenção de Clientes B2B
-- Autor: Milene Caldeira
-- ============================================================
-- Definições operacionais adotadas:
--   Ativo     → pedido nos últimos 60 dias
--   Em Risco  → sem pedido entre 61 e 120 dias
--   Churned   → sem pedido há mais de 120 dias
--
-- Receita em risco = receita histórica de clientes Em Risco
-- ============================================================


-- ============================================================
-- BLOCO 1: PANORAMA GERAL DA BASE
-- ============================================================

-- Distribuição da base por status — ponto de partida de qualquer análise de retenção
SELECT
    status_cliente,
    COUNT(*)                                    AS clientes,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_base,
    ROUND(SUM(receita_total), 2)                AS receita_historica,
    ROUND(AVG(ticket_medio), 2)                 AS ticket_medio
FROM clientes
GROUP BY status_cliente
ORDER BY
    CASE status_cliente
        WHEN 'Ativo'    THEN 1
        WHEN 'Em Risco' THEN 2
        WHEN 'Churned'  THEN 3
    END;


-- Receita em risco imediato — quanto pode ser perdido se clientes "Em Risco" churnem
SELECT
    COUNT(*)                        AS clientes_em_risco,
    ROUND(SUM(receita_total), 2)    AS receita_historica_em_risco,
    ROUND(AVG(ticket_medio), 2)     AS ticket_medio,
    ROUND(AVG(meses_ativo), 1)      AS tempo_medio_relacionamento_meses
FROM clientes
WHERE status_cliente = 'Em Risco';


-- ============================================================
-- BLOCO 2: PERFIL DOS CLIENTES QUE CHURNARAM
-- Entender quem saiu é o primeiro passo para evitar que outros saiam
-- ============================================================

-- Churn por plano — qual produto tem maior perda?
SELECT
    plano,
    COUNT(*)                                              AS total_clientes,
    SUM(CASE WHEN status_cliente = 'Churned' THEN 1 ELSE 0 END)   AS churned,
    ROUND(
        SUM(CASE WHEN status_cliente = 'Churned' THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100, 1
    )                                                     AS taxa_churn_pct
FROM clientes
GROUP BY plano
ORDER BY taxa_churn_pct DESC;


-- Churn por canal de aquisição — de onde vêm os clientes que ficam vs os que saem?
SELECT
    canal_aquisicao,
    COUNT(*)                                                       AS total,
    SUM(CASE WHEN status_cliente = 'Churned' THEN 1 ELSE 0 END)   AS churned,
    SUM(CASE WHEN status_cliente = 'Ativo'   THEN 1 ELSE 0 END)   AS ativos,
    ROUND(
        SUM(CASE WHEN status_cliente = 'Churned' THEN 1.0 ELSE 0 END)
        / COUNT(*) * 100, 1
    )                                                              AS taxa_churn_pct
FROM clientes
GROUP BY canal_aquisicao
ORDER BY taxa_churn_pct DESC;


-- Comparativo de comportamento: Churned vs Ativo
-- Quais métricas diferenciam quem fica de quem sai?
SELECT
    status_cliente,
    ROUND(AVG(total_pedidos), 1)    AS media_pedidos,
    ROUND(AVG(receita_total), 2)    AS receita_media,
    ROUND(AVG(ticket_medio), 2)     AS ticket_medio,
    ROUND(AVG(meses_ativo), 1)      AS tempo_medio_meses
FROM clientes
WHERE status_cliente IN ('Ativo', 'Churned')
GROUP BY status_cliente;


-- ============================================================
-- BLOCO 3: CLIENTES EM RISCO — PRIORIZAÇÃO PARA AÇÃO
-- Subconsulta para classificar por urgência e valor
-- ============================================================

-- Lista priorizada de clientes em risco com score de urgência
-- Critério: quanto maior a receita histórica e mais tempo sem comprar, maior prioridade
SELECT
    nome,
    plano,
    estado,
    canal_aquisicao,
    DATEDIFF(DAY, data_ultimo_pedido, GETDATE())    AS dias_sem_compra,
    total_pedidos,
    receita_total,
    ticket_medio,
    -- Score de prioridade: combina valor do cliente com urgência temporal
    ROUND(
        (receita_total / (SELECT AVG(receita_total) FROM clientes WHERE status_cliente = 'Em Risco'))
        * (DATEDIFF(DAY, data_ultimo_pedido, GETDATE()) / 30.0)
    , 2)                                            AS score_prioridade
FROM clientes
WHERE status_cliente = 'Em Risco'
ORDER BY score_prioridade DESC;


-- Clientes em risco com receita acima da média da base ativa
-- Identifica os de maior impacto financeiro caso churnem
SELECT
    c.nome,
    c.plano,
    c.receita_total,
    c.ticket_medio,
    DATEDIFF(DAY, c.data_ultimo_pedido, GETDATE()) AS dias_sem_compra
FROM clientes c
WHERE c.status_cliente = 'Em Risco'
  AND c.receita_total > (
      SELECT AVG(receita_total)
      FROM clientes
      WHERE status_cliente = 'Ativo'
  )
ORDER BY c.receita_total DESC;


-- ============================================================
-- BLOCO 4: SINAIS DE DETERIORAÇÃO — ANÁLISE DE ATIVIDADE MENSAL
-- Clientes que reduziram atividade nos últimos 3 meses
-- ============================================================

-- Evolução mês a mês por cliente — detecta queda de engajamento
SELECT
    a.id_cliente,
    c.nome,
    c.status_cliente,
    c.plano,
    MAX(CASE WHEN a.ano_mes = '2024-01' THEN a.receita_mes ELSE 0 END) AS receita_jan,
    MAX(CASE WHEN a.ano_mes = '2024-02' THEN a.receita_mes ELSE 0 END) AS receita_fev,
    MAX(CASE WHEN a.ano_mes = '2024-03' THEN a.receita_mes ELSE 0 END) AS receita_mar,
    -- Variação entre primeiro e último mês do trimestre
    ROUND(
        MAX(CASE WHEN a.ano_mes = '2024-03' THEN a.receita_mes ELSE 0 END)
        - MAX(CASE WHEN a.ano_mes = '2024-01' THEN a.receita_mes ELSE 0 END)
    , 2)                                                                AS variacao_receita_trimestre
FROM atividade_mensal a
INNER JOIN clientes c ON a.id_cliente = c.id_cliente
GROUP BY a.id_cliente, c.nome, c.status_cliente, c.plano
ORDER BY variacao_receita_trimestre ASC;


-- Clientes que zeraram atividade em março (candidatos a churn iminente)
-- Usa subconsulta para filtrar quem estava ativo em janeiro mas sumiu em março
SELECT
    c.nome,
    c.plano,
    c.segmento,
    c.receita_total,
    DATEDIFF(DAY, c.data_ultimo_pedido, GETDATE()) AS dias_sem_compra
FROM clientes c
WHERE c.id_cliente IN (
    -- Tinham atividade em janeiro
    SELECT id_cliente FROM atividade_mensal
    WHERE ano_mes = '2024-01' AND pedidos_mes > 0
)
AND c.id_cliente NOT IN (
    -- Mas não tiveram atividade em março
    SELECT id_cliente FROM atividade_mensal
    WHERE ano_mes = '2024-03' AND pedidos_mes > 0
)
ORDER BY c.receita_total DESC;


-- ============================================================
-- BLOCO 5: NPS COMO PREDITOR DE CHURN
-- Clientes com NPS baixo têm maior propensão a churnar
-- ============================================================

-- NPS médio por status — confirma correlação entre satisfação e retenção
SELECT
    c.status_cliente,
    ROUND(AVG(a.nps_score * 1.0), 1)   AS nps_medio,
    COUNT(DISTINCT c.id_cliente)        AS clientes
FROM clientes c
INNER JOIN atividade_mensal a ON c.id_cliente = a.id_cliente
WHERE a.nps_score IS NOT NULL
GROUP BY c.status_cliente
ORDER BY nps_medio DESC;


-- Clientes ativos com NPS baixo (≤ 6) — risco de churn não sinalizado pelo status
-- São os mais perigosos: ainda compram, mas a satisfação já caiu
SELECT
    c.nome,
    c.plano,
    c.segmento,
    c.receita_total,
    ROUND(AVG(a.nps_score * 1.0), 1)                AS nps_medio_trimestre,
    DATEDIFF(DAY, c.data_ultimo_pedido, GETDATE())   AS dias_desde_ultima_compra
FROM clientes c
INNER JOIN atividade_mensal a ON c.id_cliente = a.id_cliente
WHERE c.status_cliente = 'Ativo'
GROUP BY c.nome, c.plano, c.segmento, c.receita_total, c.data_ultimo_pedido
HAVING AVG(a.nps_score * 1.0) <= 6
ORDER BY c.receita_total DESC;


-- ============================================================
-- BLOCO 6: IMPACTO FINANCEIRO DO CHURN
-- ============================================================

-- Receita perdida com churned vs receita em risco vs receita segura
SELECT
    'Receita Segura (Ativos)'       AS categoria,
    ROUND(SUM(receita_total), 2)    AS valor
FROM clientes WHERE status_cliente = 'Ativo'
UNION ALL
SELECT
    'Receita em Risco (Em Risco)',
    ROUND(SUM(receita_total), 2)
FROM clientes WHERE status_cliente = 'Em Risco'
UNION ALL
SELECT
    'Receita Perdida (Churned)',
    ROUND(SUM(receita_total), 2)
FROM clientes WHERE status_cliente = 'Churned';


-- Tempo médio até o churn por plano — em quantos meses um cliente tende a sair?
SELECT
    plano,
    ROUND(AVG(meses_ativo * 1.0), 1)   AS tempo_medio_ate_churn_meses,
    COUNT(*)                            AS clientes_churned,
    ROUND(AVG(receita_total), 2)        AS receita_media_perdida
FROM clientes
WHERE status_cliente = 'Churned'
GROUP BY plano
ORDER BY tempo_medio_ate_churn_meses;
