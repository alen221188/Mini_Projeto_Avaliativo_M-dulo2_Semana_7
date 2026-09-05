-- =====================================================================================
--  DIAGNOSTICO.SQL  -  Tarefa 1: Diagnostico da Origem
--  Case: Pata Amiga | PostgreSQL
-- =====================================================================================
--  Este arquivo so faz SELECT: nao muda nada no banco. Ele serve para entender o
--  tamanho da bagunca nas 3 tabelas de origem antes de comecar a limpar.
--  Rode depois de: 01-carga-staging.sql
-- =====================================================================================

\c dw_pata_amiga

-- Quantas linhas cada tabela de origem tem
SELECT 'stg_pedido' AS tabela, COUNT(*) AS linhas FROM stg_pedido
UNION ALL SELECT 'stg_loja', COUNT(*) FROM stg_loja
UNION ALL SELECT 'stg_loja_praca', COUNT(*) FROM stg_loja_praca;

-- Quantas grafias diferentes existem para cada coluna "suja"
SELECT COUNT(DISTINCT "CategoriaProduto") AS grafias_categoria FROM stg_pedido;
SELECT COUNT(DISTINCT "Loja-Nome")        AS grafias_loja      FROM stg_pedido;
SELECT COUNT(DISTINCT "HouveDesconto")    AS grafias_desconto  FROM stg_pedido;
SELECT COUNT(DISTINCT "CanalPedido")      AS grafias_canal     FROM stg_pedido;

-- Quantos pedidos chegaram sem identificar a loja
SELECT SUM(CASE WHEN "Cod Loja" = '' THEN 1 ELSE 0 END)  AS pedidos_sem_cod_loja  FROM stg_pedido;
SELECT SUM(CASE WHEN "Loja-Nome" = '' THEN 1 ELSE 0 END) AS pedidos_sem_nome_loja FROM stg_pedido;

-- Quantos marcos do processo de entrega estao em branco (branco = etapa nao aconteceu ainda)
SELECT
    SUM(CASE WHEN "Dt Separacao Estoque"       = '' THEN 1 ELSE 0 END) AS separacao_em_branco,
    SUM(CASE WHEN "DtNotaFiscal"               = '' THEN 1 ELSE 0 END) AS nota_em_branco,
    SUM(CASE WHEN "Dt_Despacho_Transportadora" = '' THEN 1 ELSE 0 END) AS despacho_em_branco,
    SUM(CASE WHEN "DtEntregaCliente"           = '' THEN 1 ELSE 0 END) AS entrega_em_branco
FROM stg_pedido;
