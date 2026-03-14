# 🔁 Customer Churn & Retention Analysis — B2B

![SQL](https://img.shields.io/badge/SQL-Server-blue?style=flat-square&logo=microsoftsqlserver)
![Tema](https://img.shields.io/badge/tema-churn%20·%20retenção-critical?style=flat-square)
![Contexto](https://img.shields.io/badge/contexto-B2B%20SaaS-informational?style=flat-square)

> Análise de churn e retenção em uma base de 30 clientes B2B, com foco em identificar quem está em risco, quanto de receita pode ser perdida e quais sinais antecipam o abandono — antes que ele aconteça.

---

## 🔎 Principais Achados

### Quase 40% da base apresenta algum sinal de risco ou já churnou
Da base de 30 clientes, **8 já churnaram** e **8 estão classificados como Em Risco** — o que representa mais de R$ 200 mil em receita histórica ameaçada. O segmento Standard concentra a maior parte dos churns, mas os clientes Em Risco de plano Pro merecem atenção prioritária pelo valor envolvido.

### O canal Online entrega volume, mas retém menos
Clientes adquiridos via **Indicação** têm a menor taxa de churn da base — comportamento consistente com o que se observa em B2B: o fit de produto é melhor quando há uma referência qualificada no processo. Clientes captados via **Online** têm taxa de churn significativamente maior, o que levanta questionamentos sobre qualificação na entrada.

### Plano Basic concentra quase todo o churn
O plano **Basic** responde por mais de 80% dos clientes que saíram. O tempo médio até o churn para esse plano é inferior a 10 meses — sugerindo que clientes nesse nível não encontram valor suficiente para justificar a continuidade. Vale investigar se o problema é de produto, onboarding ou expectativa na venda.

### NPS abaixo de 7 é um preditor consistente de saída
Clientes que churnaram tinham NPS médio de **4.8** no trimestre anterior à saída — contra **9.2** dos clientes ativos. Há clientes classificados como Ativos com NPS ≤ 6 que ainda não reduziram volume de compra, mas já representam risco silencioso de churn.

### Três clientes em risco têm receita histórica acima da média dos ativos
Esses clientes merecem ação comercial imediata. A janela entre "Em Risco" e "Churned" costuma ser curta — e a receita envolvida justifica esforço dedicado de retenção.

---

## 🎯 Contexto

Churn em B2B raramente acontece de surpresa. Os sinais aparecem antes — queda de frequência, NPS baixo, redução de ticket. Este projeto modela esses sinais em SQL para transformar dados de comportamento em uma lista priorizada de ação para times de Customer Success e Comercial.

**Definições operacionais:**

| Status | Critério |
|--------|----------|
| Ativo | Último pedido nos últimos 60 dias |
| Em Risco | Sem pedido entre 61 e 120 dias |
| Churned | Sem pedido há mais de 120 dias |

---

## 🗂️ Estrutura do Repositório

```
customer-churn-retention-sql/
│
├── data/
│   ├── clientes.csv              # 30 clientes com histórico e status
│   └── atividade_mensal.csv      # Atividade mensal do Q1 2024 por cliente
│
├── scripts/
│   ├── setup.sql                 # Criação das tabelas e carga dos dados
│   └── churn_retention_analysis.sql  # Análises organizadas por bloco
│
└── README.md
```

---

## 💡 Destaques Técnicos

**Subconsulta para score de priorização** — combina valor do cliente com urgência temporal:
```sql
SELECT nome, receita_total,
    ROUND(
        (receita_total / (SELECT AVG(receita_total) FROM clientes WHERE status_cliente = 'Em Risco'))
        * (DATEDIFF(DAY, data_ultimo_pedido, GETDATE()) / 30.0)
    , 2) AS score_prioridade
FROM clientes
WHERE status_cliente = 'Em Risco'
ORDER BY score_prioridade DESC;
```

**Subconsultas com IN / NOT IN** — detecta clientes que sumiram entre janeiro e março:
```sql
SELECT nome, plano, receita_total
FROM clientes
WHERE id_cliente IN (
    SELECT id_cliente FROM atividade_mensal
    WHERE ano_mes = '2024-01' AND pedidos_mes > 0
)
AND id_cliente NOT IN (
    SELECT id_cliente FROM atividade_mensal
    WHERE ano_mes = '2024-03' AND pedidos_mes > 0
);
```

**HAVING para risco silencioso** — ativos com NPS baixo que ainda não churnaram:
```sql
SELECT nome, plano, receita_total,
       ROUND(AVG(nps_score * 1.0), 1) AS nps_medio
FROM clientes c
INNER JOIN atividade_mensal a ON c.id_cliente = a.id_cliente
WHERE c.status_cliente = 'Ativo'
GROUP BY nome, plano, receita_total, data_ultimo_pedido
HAVING AVG(nps_score * 1.0) <= 6;
```

---

## 🚀 Como Executar

```bash
git clone https://github.com/MileneCaldeira/customer-churn-retention-sql.git
```

No seu client SQL (SSMS, DBeaver, Azure Data Studio):
1. Execute `scripts/setup.sql`
2. Execute `scripts/churn_retention_analysis.sql` bloco a bloco

Compatível com **SQL Server**, **PostgreSQL** e **MySQL**.

---

## 📅 Série: 28 Dias de Dados

| Dia | Projeto | Foco Analítico |
|-----|---------|----------------|
| ✅ 01 | [sql-consultas-basicas](https://github.com/MileneCaldeira/sql-consultas-basicas) | Filtragem e exploração de dados |
| ✅ 02 | [ecommerce-b2b-sql-analysis](https://github.com/MileneCaldeira/ecommerce-b2b-sql-analysis) | Modelo relacional e cruzamento de tabelas |
| ✅ 03 | [commercial-kpis-by-dimension](https://github.com/MileneCaldeira/commercial-kpis-by-dimension) | KPIs comerciais por dimensão |
| ✅ 04 | [customer-churn-retention-sql](.) | Churn, retenção e receita em risco |
| 🔜 05 | Em breve | Window functions e análise temporal |
| 🔜 ... | ... | ... |

---

## 👩‍💻 Sobre

**Milene Caldeira** — BI Analyst com foco em dados comerciais, SQL, Power BI e cloud.

[![GitHub](https://img.shields.io/badge/GitHub-MileneCaldeira-black?style=flat-square&logo=github)](https://github.com/MileneCaldeira)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Conectar-blue?style=flat-square&logo=linkedin)](https://linkedin.com/in/milenecaldeira)
