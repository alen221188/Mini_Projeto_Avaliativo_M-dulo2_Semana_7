-- =====================================================================================
--  ARQUIVO 5: AS CINCO PERGUNTAS DE NEGOCIO
--  Case: Pata Amiga | PostgreSQL
-- =====================================================================================
--  Rode depois de: 04-fato.sql
--
--  Essas sao as unicas consultas do projeto que podem usar subconsulta (as
--  dimensoes e a fato nao usam, so as respostas de negocio).
-- =====================================================================================

\c dw_pata_amiga

-- ===========================================================================
-- P1: Onde esta o gargalo da entrega?
-- Tempo medio (em dias) de cada intervalo do processo, e do total, por porte
-- de loja. O intervalo com a maior media e o gargalo.
-- ===========================================================================
SELECT
    l.porte,
    ROUND(AVG(f.dias_integracao_separacao), 2) AS media_integracao_separacao,
    ROUND(AVG(f.dias_separacao_nota), 2)       AS media_separacao_nota,
    ROUND(AVG(f.dias_nota_despacho), 2)        AS media_nota_despacho,
    ROUND(AVG(f.dias_despacho_entrega), 2)     AS media_despacho_entrega,
    ROUND(AVG(f.dias_total_ate_entrega), 2)    AS media_total_ate_entrega
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
GROUP BY l.porte
ORDER BY l.porte;

-- ===========================================================================
-- P2: Qual categoria concentra o faturamento?
-- Faturamento por categoria PADRONIZADA (nunca pela grafia crua), com o
-- percentual do total da rede, e por porte de loja.
-- ===========================================================================
SELECT
    l.porte,
    c.nome_categoria,
    ROUND(SUM(f.vl_liquido), 2) AS faturamento,
    ROUND(100.0 * SUM(f.vl_liquido) / (SELECT SUM(vl_liquido) FROM fato_pedido), 2) AS pct_do_total_rede
FROM fato_pedido f
JOIN dim_categoria c ON c.sk_categoria = f.sk_categoria
JOIN dim_loja l ON l.sk_loja = f.sk_loja
GROUP BY l.porte, c.nome_categoria
ORDER BY l.porte, faturamento DESC;

-- ===========================================================================
-- P3: O desconto funciona igual em todo canal?
-- Ticket medio COM e SEM desconto, dentro de cada canal, e quanto cada canal
-- representa do faturamento total da rede.
-- ===========================================================================
SELECT
    canal_pedido,
    houve_desconto,
    ROUND(AVG(vl_liquido), 2) AS ticket_medio,
    COUNT(*) AS pedidos,
    ROUND(100.0 * SUM(vl_liquido) / (SELECT SUM(vl_liquido) FROM fato_pedido), 2) AS pct_faturamento_canal
FROM fato_pedido
GROUP BY canal_pedido, houve_desconto
ORDER BY canal_pedido, houve_desconto;

-- ===========================================================================
-- P4: Qual praca de atendimento concentra o faturamento?
-- Uma loja pode entregar em mais de uma praca, entao o faturamento de cada
-- loja e RATEADO pelo fator_publico antes de somar por praca. Sem o rateio,
-- o faturamento de quem atende duas pracas seria contado duas vezes.
-- ===========================================================================
SELECT
    p.nome_praca,
    p.domicilios_com_pet,
    ROUND(SUM(f.vl_liquido * b.fator_publico), 2) AS faturamento_rateado
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
JOIN bridge_loja_praca b ON b.cod_loja = l.cod_loja
JOIN dim_praca p ON p.sk_praca = b.sk_praca
WHERE f.sk_loja <> -1
GROUP BY p.nome_praca, p.domicilios_com_pet
ORDER BY faturamento_rateado DESC;

-- Conferencia da P4: a soma rateada por praca, mais os pedidos sem loja
-- (que nao entram em nenhuma praca), tem que fechar com o faturamento total
-- da rede. Arredondo a diferenca UMA vez so, para nao sobrar 1 ou 2 reais de
-- arredondamento que na verdade fecham exato.
SELECT
    (SELECT ROUND(SUM(vl_liquido)) FROM fato_pedido) AS total_da_rede,
    (SELECT ROUND(SUM(f.vl_liquido * b.fator_publico))
       FROM fato_pedido f
       JOIN dim_loja l ON l.sk_loja = f.sk_loja
       JOIN bridge_loja_praca b ON b.cod_loja = l.cod_loja) AS soma_rateada,
    (SELECT ROUND(SUM(vl_liquido)) FROM fato_pedido WHERE sk_loja = -1) AS sem_loja,
    ROUND(
        (SELECT SUM(vl_liquido) FROM fato_pedido)
        - (SELECT SUM(f.vl_liquido * b.fator_publico)
             FROM fato_pedido f JOIN dim_loja l ON l.sk_loja = f.sk_loja
             JOIN bridge_loja_praca b ON b.cod_loja = l.cod_loja)
        - (SELECT SUM(vl_liquido) FROM fato_pedido WHERE sk_loja = -1)
    ) AS diferenca_tem_que_ser_zero;

-- ===========================================================================
-- P5a: Ranking de lojas por ITENS VENDIDOS POR MIL HABITANTES (nao em valor
-- absoluto), cruzado com o tempo medio de entrega de cada loja.
-- ===========================================================================
SELECT
    l.nome_loja,
    l.populacao_cidade,
    SUM(f.qt_itens) AS itens_vendidos,
    ROUND(1000.0 * SUM(f.qt_itens) / l.populacao_cidade, 3) AS itens_por_mil_habitantes,
    ROUND(AVG(f.dias_total_ate_entrega), 2) AS media_dias_entrega
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
WHERE l.sk_loja <> -1
GROUP BY l.nome_loja, l.populacao_cidade
ORDER BY itens_por_mil_habitantes DESC;

-- ===========================================================================
-- P5b: Faturamento por faixa de franquia ATUAL.
-- Atencao: dim_loja.faixa_franquia e a foto de HOJE (o cadastro sobrescreve o
-- passado). Isso NAO responde "quanto veio de lojas que ja eram Ouro na data
-- do pedido" — so mostra a faixa de hoje aplicada a todo o historico.
-- ===========================================================================
SELECT
    l.faixa_franquia,
    ROUND(SUM(f.vl_liquido), 2) AS faturamento
FROM fato_pedido f
JOIN dim_loja l ON l.sk_loja = f.sk_loja
GROUP BY l.faixa_franquia
ORDER BY faturamento DESC;

-- ===========================================================================
-- P5c: O que os dados NAO permitem afirmar — o que ficou de fora.
-- ===========================================================================
SELECT 'pedidos sem loja identificada' AS o_que_ficou_de_fora, COUNT(*) AS quantidade
FROM fato_pedido WHERE sk_loja = -1
UNION ALL
SELECT 'entregas ainda nao concluidas', COUNT(*) FROM fato_pedido WHERE sk_tempo_entrega = -1
UNION ALL
SELECT 'pedidos com qt_itens em branco', COUNT(*) FROM fato_pedido WHERE qt_itens IS NULL
UNION ALL
SELECT 'pedidos com vl_liquido em branco', COUNT(*) FROM fato_pedido WHERE vl_liquido IS NULL;
