# Mini-Projeto Avaliativo - Modelo Dimensional PostgreSQL (Pata Amiga)

Projeto da disciplina **Análise de Dados com Python [T1] - Módulo 2 - Semana 7**.

## 1. O case

A Pata Amiga é uma rede catarinense de pet shops, com 32 lojas em Santa Catarina.
Os pedidos chegam por vários canais (app, site, telefone, WhatsApp, loja física) e
vêm de três sistemas que não se conversam: a plataforma de e-commerce, o cadastro
de lojas do franchising e a planilha de praças de atendimento.

O objetivo deste projeto é pegar essas três tabelas "sujas" (nomes de coluna
fora de padrão, datas em formatos diferentes, texto onde deveria ser número,
a mesma loja escrita de várias formas) e construir um **modelo dimensional em
estrela** no PostgreSQL, capaz de responder com números confiáveis a cinco
perguntas de negócio:

1. Onde está o gargalo da entrega?
2. Qual categoria concentra o faturamento?
3. O desconto funciona igual em todo canal?
4. Qual praça de atendimento concentra o faturamento?
5. Onde abrir a próxima loja, e o que os dados **não** permitem afirmar?

## 2. Diagnóstico da Origem (Tarefa 1)

Antes de tratar qualquer coisa, rodei o `sql/01-carga-staging.sql` (que cria o banco
`dw_pata_amiga` e carrega as 3 tabelas de origem exatamente como vieram dos
sistemas) e depois `sql/diagnostico.sql`, só para medir o tamanho da bagunça.
Os números batem com os valores de conferência do enunciado:

| O que foi medido | Valor encontrado | O que isso significa |
|---|---|---|
| Linhas em `stg_pedido` / `stg_loja` / `stg_loja_praca` | 4.044 / 32 / 48 | Confirma que a carga da staging veio completa. |
| Grafias distintas de `CategoriaProduto` | 37 | A mesma categoria (ex.: ração) está escrita de até 37 jeitos diferentes. Por isso a `dim_categoria` precisa de um "de-para". |
| Grafias distintas de `Loja-Nome` | 128 | O nome da loja vem com acento, sem acento, maiúscula/minúscula, sufixo "/SC", espaço sobrando e erro de digitação. |
| Grafias distintas de `HouveDesconto` | 17 | "Sim" pode vir como `S`, `SIM`, `1`, `X`, `TRUE`, `V`, etc. |
| Grafias distintas de `CanalPedido` | 20 | O mesmo canal (ex.: WhatsApp) aparece escrito de formas diferentes. |
| Pedidos sem `Cod Loja` preenchido | 1.575 (~39%) | Quase 4 em cada 10 pedidos não têm o código da loja — por isso a ligação com `dim_loja` **não pode** ser feita pelo código, e sim pelo nome padronizado. |
| Pedidos sem `Loja-Nome` preenchido | 3 | Esses 3 pedidos vão para a linha `-1` ("Nao Informado") de `dim_loja`, nunca ficam com FK nula. |
| Marco "Separação" em branco | 1.077 | Processo ainda não chegou nessa etapa. |
| Marco "Nota Fiscal" em branco | 1.338 | Idem. |
| Marco "Despacho" em branco | 1.665 | Idem. |
| Marco "Entrega" em branco | 1.953 | Quase metade dos pedidos ainda não foi entregue dentro da janela de 7 meses — **branco aqui não é erro, é processo em aberto**, e por isso vira `NULL` (nunca `0`) nos cálculos de dias. |

> Reproduza esses números você mesmo: `psql -U postgres -d dw_pata_amiga -f sql/diagnostico.sql`
> (depois de rodar o `sql/01-carga-staging.sql`).

## 3. Modelo construído

_(preencher depois de montar o diagrama)_

## 4. Decisões de tratamento

_(preencher com as decisões de máscara de data, de-para de categoria/canal e
padronização do nome da loja, e o porquê de cada uma)_

## 5. Como reproduzir o banco do zero

Rode os scripts na pasta `sql/`, nesta ordem, usando o `psql`:

```bash
psql -U postgres -d postgres    -f sql/01-carga-staging.sql
psql -U postgres -d dw_pata_amiga -f sql/02-dimensoes-prontas.sql
psql -U postgres -d dw_pata_amiga -f sql/03-dimensoes.sql
psql -U postgres -d dw_pata_amiga -f sql/04-fato.sql
psql -U postgres -d dw_pata_amiga -f sql/05-perguntas.sql
```

## 6. As cinco respostas

_(preencher depois de rodar sql/05-perguntas.sql)_

## 7. Recomendação final

_(preencher depois das cinco respostas)_
