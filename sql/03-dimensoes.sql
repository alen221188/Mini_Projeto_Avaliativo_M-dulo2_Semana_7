-- =====================================================================================
--  ARQUIVO 3: DIMENSOES QUE EU CONSTRUO (dim_categoria, dim_praca, bridge_loja_praca)
--  Case: Pata Amiga | PostgreSQL
-- =====================================================================================
--  Rode depois de: 02-dimensoes-prontas.sql
--
--  Regra geral do projeto: nao mexo nas tabelas stg_ (sao a origem). Toda a limpeza
--  acontece aqui, nos INSERT.
-- =====================================================================================

\c dw_pata_amiga

-- ---------------------------------------------------------------------------
-- DIM_CATEGORIA
-- Grao: uma linha para cada grafia diferente que aparece em CategoriaProduto.
--
-- A ORDEM DO CASE IMPORTA MUITO AQUI: "Ração Medicamentosa" contém as letras
-- "RA" dentro dela. Se eu testar RA antes de MED, esse produto seria
-- classificado errado como Racao, quando na verdade e um Medicamento.
-- Por isso testo MED primeiro, RA so depois.
--
-- Comparo tudo em UPPER + TRANSLATE (tira acento) para nao depender de acento
-- ou de maiuscula/minuscula: no PostgreSQL 'Ração' e 'RACAO' sao textos
-- diferentes se eu nao normalizar os dois lados.
--
-- Guardo a grafia ORIGINAL (categoria_origem): e por ela que a fato vai
-- encontrar a linha certa depois, com um JOIN simples.
-- ---------------------------------------------------------------------------

-- Linha -1: toda dimensao que eu construo precisa dela, para nenhuma FK ficar nula.
INSERT INTO dim_categoria (sk_categoria, categoria_origem, nome_categoria, grupo_categoria)
VALUES (-1, 'Nao Informado', 'Nao Informado', 'Nao Informado');

INSERT INTO dim_categoria (categoria_origem, nome_categoria, grupo_categoria)
SELECT DISTINCT
    "CategoriaProduto",
    CASE
        WHEN UPPER(TRANSLATE("CategoriaProduto",'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc')) LIKE '%MED%'    THEN 'Medicamento'
        WHEN UPPER(TRANSLATE("CategoriaProduto",'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc')) LIKE '%PETISC%' THEN 'Petisco'
        WHEN UPPER(TRANSLATE("CategoriaProduto",'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc')) LIKE '%RA%'     THEN 'Racao'
        WHEN UPPER(TRANSLATE("CategoriaProduto",'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc')) LIKE '%HIG%'    THEN 'Higiene'
        WHEN UPPER(TRANSLATE("CategoriaProduto",'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc')) LIKE '%BRINQ%'  THEN 'Brinquedo'
        WHEN UPPER(TRANSLATE("CategoriaProduto",'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc')) LIKE '%ACESS%'  THEN 'Acessorio'
        WHEN UPPER(TRANSLATE("CategoriaProduto",'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc')) LIKE '%SERV%'   THEN 'Servico'
        ELSE 'Nao Informado'
    END AS nome_categoria,
    CASE
        WHEN UPPER(TRANSLATE("CategoriaProduto",'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc')) LIKE '%MED%'    THEN 'Saude e Higiene'
        WHEN UPPER(TRANSLATE("CategoriaProduto",'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc')) LIKE '%PETISC%' THEN 'Alimentacao'
        WHEN UPPER(TRANSLATE("CategoriaProduto",'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc')) LIKE '%RA%'     THEN 'Alimentacao'
        WHEN UPPER(TRANSLATE("CategoriaProduto",'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc')) LIKE '%HIG%'    THEN 'Saude e Higiene'
        WHEN UPPER(TRANSLATE("CategoriaProduto",'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc')) LIKE '%BRINQ%'  THEN 'Bem-estar'
        WHEN UPPER(TRANSLATE("CategoriaProduto",'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc')) LIKE '%ACESS%'  THEN 'Bem-estar'
        WHEN UPPER(TRANSLATE("CategoriaProduto",'ÁÀÂÃÉÊÍÓÔÕÚÇáàâãéêíóôõúç','AAAAEEIOOOUCaaaaeeiooouc')) LIKE '%SERV%'   THEN 'Bem-estar'
        ELSE 'Nao Informado'
    END AS grupo_categoria
FROM stg_pedido;

-- ---------------------------------------------------------------------------
-- DIM_PRACA
-- Grao: uma linha para cada praca de atendimento.
--
-- domicilios_com_pet vem como texto '148.000'. Aqui o ponto e separador de
-- milhar, nao e casa decimal. Por isso eu tiro o ponto antes de converter
-- para numero inteiro (se nao tirasse, '148.000' viraria 148 errado).
-- ---------------------------------------------------------------------------

INSERT INTO dim_praca (sk_praca, cod_praca, nome_praca, regional, domicilios_com_pet)
VALUES (-1, 'N/I', 'Nao Informado', 'Nao Informado', NULL);

INSERT INTO dim_praca (cod_praca, nome_praca, regional, domicilios_com_pet)
SELECT DISTINCT
    "CodPraca",
    "NomePraca",
    "Regional",
    CAST(REPLACE("DomiciliosComPet", '.', '') AS INTEGER)
FROM stg_loja_praca;

-- ---------------------------------------------------------------------------
-- BRIDGE_LOJA_PRACA
-- Grao: uma linha para cada combinacao loja x praca.
--
-- Essa e a tabela ponte: uma loja pode entregar em mais de uma praca, entao
-- uma FK sozinha nao dava conta (so guarda um valor). Aqui eu guardo o
-- fator_publico, que e o % do publico daquela loja que mora em cada praca.
-- Repare que a ligacao usa o COD da loja (chave natural), e nao a sk_loja.
-- ---------------------------------------------------------------------------

INSERT INTO bridge_loja_praca (cod_loja, sk_praca, fator_publico)
SELECT
    slp."CodLoja",
    dp.sk_praca,
    CAST(slp."PercentualPublico" AS DECIMAL(6,4))
FROM stg_loja_praca slp
JOIN dim_praca dp ON dp.cod_praca = slp."CodPraca";

-- ---------------------------------------------------------------------------
-- CONFERENCIA — comparar com os numeros do enunciado
-- ---------------------------------------------------------------------------
SELECT 'dim_categoria' AS tabela, COUNT(*) AS linhas FROM dim_categoria
UNION ALL SELECT 'dim_praca', COUNT(*) FROM dim_praca
UNION ALL SELECT 'bridge_loja_praca', COUNT(*) FROM bridge_loja_praca;

-- Esperado: 8 (as 7 categorias padronizadas + a linha -1)
SELECT COUNT(DISTINCT nome_categoria) AS categorias_padronizadas FROM dim_categoria;

-- Teste da ordem do CASE: "Ração Medicamentosa" tem que virar Medicamento, nunca Racao
SELECT categoria_origem, nome_categoria FROM dim_categoria
WHERE UPPER(categoria_origem) LIKE '%MEDICAMENTOSA%';

-- O fator de cada loja tem que somar exatamente 1,00. Esta consulta tem que voltar vazia.
SELECT cod_loja, ROUND(SUM(fator_publico), 4) AS soma_do_fator
FROM bridge_loja_praca GROUP BY cod_loja
HAVING ROUND(SUM(fator_publico), 4) <> 1;
