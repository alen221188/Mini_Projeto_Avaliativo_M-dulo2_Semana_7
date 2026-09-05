-- =====================================================================================
--  ARQUIVO 4: CARGA DA FATO (fato_pedido)
--  Case: Pata Amiga | PostgreSQL
-- =====================================================================================
--  Rode depois de: 03-dimensoes.sql
--
--  Grao da fato: 1 linha = 1 pedido (4.044 linhas no final).
--  Tudo isso e feito com UM UNICO INSERT ... SELECT, sem nenhuma subconsulta:
--  so uso SELECT, JOIN, LEFT JOIN e CASE WHEN.
--
--  Regra principal: a limpeza pesada (de-para de categoria, nome da loja) ja
--  foi feita nas dimensoes (arquivo 03) e ja vem pronta (arquivo 02). Aqui eu
--  so preciso limpar o nome da loja do MESMO jeito que a dim_loja guarda ele,
--  para o JOIN encontrar a linha certa.
-- =====================================================================================

\c dw_pata_amiga

INSERT INTO fato_pedido (
    numero_pedido, sk_tempo_pedido, sk_tempo_entrega, sk_loja, sk_categoria,
    houve_desconto, canal_pedido, dt_pedido, qt_itens, vl_liquido,
    dias_integracao_separacao, dias_separacao_nota, dias_nota_despacho,
    dias_despacho_entrega, dias_total_ate_entrega
)
SELECT
    sp."NumeroPedido",

    -- Chave da dim_tempo do PEDIDO: a data em formato AAAAMMDD, calculada direto
    -- (sem precisar de JOIN, porque a chave da dim_tempo e a propria data).
    TO_CHAR(TO_TIMESTAMP(sp."DtHoraPedido", 'MM/DD/YYYY HH12:MI AM'), 'YYYYMMDD')::int,

    -- Chave da dim_tempo da ENTREGA. Se ainda nao foi entregue (campo vazio),
    -- aponta para a linha -1 em vez de ficar nula.
    CASE WHEN sp."DtEntregaCliente" = '' THEN -1
         ELSE TO_CHAR(sp."DtEntregaCliente"::date, 'YYYYMMDD')::int END,

    -- sk_loja: ver o JOIN la embaixo. COALESCE garante -1 se nao achar a loja.
    COALESCE(dl.sk_loja, -1),

    -- sk_categoria: procurado pela grafia crua (ver JOIN). COALESCE por seguranca.
    COALESCE(dc.sk_categoria, -1),

    -- Desconto chega de 17 formas diferentes. Aqui eu junto tudo em so 3 valores.
    -- Uso TRANSLATE porque um dos valores reais e "Não" (com acento).
    CASE WHEN UPPER(TRANSLATE(TRIM(sp."HouveDesconto"),'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc')) IN ('S','SIM','1','X','TRUE','V') THEN 'Sim'
         WHEN UPPER(TRANSLATE(TRIM(sp."HouveDesconto"),'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc')) IN ('N','NAO','0','FALSE','F') THEN 'Nao'
         ELSE 'Nao Informado' END,

    -- Canal do pedido: a ordem aqui importa, porque "WHATSAPP" contem "APP"
    -- dentro dela. Se eu testasse APP primeiro, todo pedido de WhatsApp cairia
    -- errado dentro de App.
    CASE WHEN UPPER(TRIM(sp."CanalPedido")) LIKE '%WHATS%' THEN 'WhatsApp'
         WHEN UPPER(TRIM(sp."CanalPedido")) LIKE '%APP%'   THEN 'App'
         WHEN UPPER(TRIM(sp."CanalPedido")) LIKE '%SITE%'  THEN 'Site'
         WHEN UPPER(TRIM(sp."CanalPedido")) LIKE '%LOJA%'  THEN 'Loja Fisica'
         WHEN UPPER(TRIM(sp."CanalPedido")) LIKE '%TEL%'   THEN 'Telefone'
         ELSE 'Nao Informado' END,

    -- Data e hora do pedido, ja convertida de texto para timestamp de verdade.
    TO_TIMESTAMP(sp."DtHoraPedido", 'MM/DD/YYYY HH12:MI AM'),

    -- Quantidade de itens. Vazio ou '-' vira NULL, nunca 0 (regra dos numeros).
    CASE WHEN TRIM(sp."QTD.Itens") IN ('', '-') THEN NULL
         ELSE CAST(TRIM(sp."QTD.Itens") AS INTEGER) END,

    -- Valor liquido do pedido. Essa coluna mistura "R$ 1.850,00", "1850.00",
    -- "1.200" e vazio na mesma coluna. Formula dada no enunciado do projeto.
    CASE WHEN TRIM(REPLACE(sp."ValorLiquidoPedido(R$)",'R$','')) IN ('','-') THEN NULL
         WHEN sp."ValorLiquidoPedido(R$)" LIKE '%,%'
              THEN CAST(REPLACE(REPLACE(REPLACE(REPLACE(sp."ValorLiquidoPedido(R$)",'R$',''),' ',''),'.',''),',','.') AS DECIMAL(15,2))
         ELSE CAST(REPLACE(REPLACE(sp."ValorLiquidoPedido(R$)",'R$',''),' ','') AS DECIMAL(15,2)) END,

    -- As 5 colunas de dias, calculadas aqui uma unica vez. Se o marco de FIM
    -- estiver em branco, o resultado e NULL (etapa ainda nao aconteceu),
    -- nunca 0 — senao a media da P1 pareceria mais rapida do que e de verdade.

    -- dias entre o pedido entrar no ERP e a separacao no estoque
    CASE WHEN sp."Dt Separacao Estoque" = '' THEN NULL
         ELSE sp."Dt Separacao Estoque"::date - TO_TIMESTAMP(sp."DtHoraIntegracaoERP", 'MM/DD/YYYY HH12:MI AM')::date END,

    -- dias entre a separacao e a nota fiscal
    CASE WHEN sp."Dt Separacao Estoque" = '' OR sp."DtNotaFiscal" = '' THEN NULL
         ELSE sp."DtNotaFiscal"::date - sp."Dt Separacao Estoque"::date END,

    -- dias entre a nota fiscal e o despacho
    CASE WHEN sp."DtNotaFiscal" = '' OR sp."Dt_Despacho_Transportadora" = '' THEN NULL
         ELSE sp."Dt_Despacho_Transportadora"::date - sp."DtNotaFiscal"::date END,

    -- dias entre o despacho e a entrega ao cliente
    CASE WHEN sp."Dt_Despacho_Transportadora" = '' OR sp."DtEntregaCliente" = '' THEN NULL
         ELSE sp."DtEntregaCliente"::date - sp."Dt_Despacho_Transportadora"::date END,

    -- dias do processo INTEIRO (ERP ate a entrega) — essa e a que responde a P1
    CASE WHEN sp."DtEntregaCliente" = '' THEN NULL
         ELSE sp."DtEntregaCliente"::date - TO_TIMESTAMP(sp."DtHoraIntegracaoERP", 'MM/DD/YYYY HH12:MI AM')::date END

FROM stg_pedido sp

-- Ligo com a dim_loja pelo NOME padronizado (chave_loja), nao pelo Cod Loja,
-- porque 39% dos pedidos nao tem o codigo preenchido.
--
-- Antes de comparar, limpo o nome da mesma forma que a dim_loja guarda:
--   1) tiro o sufixo "/SC" e espaco duplo (REPLACE)
--   2) deixo maiuscula e sem acento (UPPER + TRANSLATE)
--   3) corrijo a mao as 3 grafias que sobram depois disso: erro de digitacao,
--      apelido e abreviacao (nao dava para resolver so com REPLACE)
LEFT JOIN dim_loja dl
  ON dl.chave_loja =
     CASE
       WHEN UPPER(TRANSLATE(TRIM(REPLACE(REPLACE(sp."Loja-Nome",'/SC',''),'  ',' ')),'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc')) = 'PATA AMIGA BLUMENAL CENTRO' THEN 'PATA AMIGA BLUMENAU CENTRO'
       WHEN UPPER(TRANSLATE(TRIM(REPLACE(REPLACE(sp."Loja-Nome",'/SC',''),'  ',' ')),'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc')) = 'PATA AMIGA FLORIPA NORTE'   THEN 'PATA AMIGA FLORIANOPOLIS NORTE'
       WHEN UPPER(TRANSLATE(TRIM(REPLACE(REPLACE(sp."Loja-Nome",'/SC',''),'  ',' ')),'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc')) = 'PATA AMIGA JGUA DO SUL'     THEN 'PATA AMIGA JARAGUA DO SUL'
       ELSE UPPER(TRANSLATE(TRIM(REPLACE(REPLACE(sp."Loja-Nome",'/SC',''),'  ',' ')),'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc'))
     END

-- Ligo com a dim_categoria pela grafia CRUA (igual veio da origem): a
-- dim_categoria guardou toda grafia distinta em categoria_origem, entao esse
-- JOIN sempre encontra exatamente uma linha.
LEFT JOIN dim_categoria dc
  ON dc.categoria_origem = sp."CategoriaProduto";

-- ---------------------------------------------------------------------------
-- CONFERENCIA — comparar com os numeros do enunciado
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS total_linhas FROM fato_pedido; -- esperado 4044

SELECT COUNT(*) AS fk_nula FROM fato_pedido
WHERE sk_loja IS NULL OR sk_categoria IS NULL OR sk_tempo_pedido IS NULL OR sk_tempo_entrega IS NULL; -- esperado 0

SELECT COUNT(*) AS pedidos_sem_loja FROM fato_pedido WHERE sk_loja = -1; -- esperado 3
SELECT COUNT(*) AS entregas_pendentes FROM fato_pedido WHERE sk_tempo_entrega = -1; -- esperado 1953

-- Se WhatsApp aparecer com 0, a ordem do CASE do canal esta errada
SELECT canal_pedido, COUNT(*) AS pedidos FROM fato_pedido WHERE canal_pedido = 'WhatsApp' GROUP BY canal_pedido; -- esperado 414

SELECT MIN(dt_pedido::date) AS primeiro_pedido, MAX(dt_pedido::date) AS ultimo_pedido FROM fato_pedido; -- esperado 2023-09-01 a 2024-03-31

SELECT COUNT(*) AS dias_negativos FROM fato_pedido
WHERE dias_integracao_separacao < 0 OR dias_separacao_nota < 0
   OR dias_nota_despacho < 0 OR dias_despacho_entrega < 0 OR dias_total_ate_entrega < 0; -- esperado 0
