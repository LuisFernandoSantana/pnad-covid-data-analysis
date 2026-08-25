-- PNAD COVID-19
-- Anexo de consultas SQL utilizadas nas análises
-- Período: setembro a novembro de 2020

-- ============================================================================
-- 1. Validação da carga no banco
-- Variável no notebook: sql_validacao_final
-- ============================================================================
SELECT
        COUNT(*) AS quantidade_registros,
        MIN(id_registro) AS primeiro_id,
        MAX(id_registro) AS ultimo_id,
        SUM(infectado) AS infectados,
        ROUND(
            100.0 * SUM(infectado) / COUNT(*),
            2
        ) AS percentual_infectados
    FROM public.pnad_covid;

-- ============================================================================
-- 2. Evolução mensal dos testes positivos
-- Variável no notebook: sql_evolucao_infectados
-- ============================================================================
SELECT
        mes_referencia,

        COUNT(*) AS total_entrevistados,

        SUM(infectado) AS infectados_amostra,

        ROUND(
            (
                100.0 * SUM(infectado)
                / COUNT(*)
            )::NUMERIC,
            2
        ) AS percentual_amostra,

        ROUND(
            SUM(peso_amostral)::NUMERIC,
            0
        ) AS populacao_estimada,

        ROUND(
            SUM(
                CASE
                    WHEN infectado = 1
                    THEN peso_amostral
                    ELSE 0
                END
            )::NUMERIC,
            0
        ) AS infectados_estimados,

        ROUND(
            (
                100.0
                * SUM(
                    CASE
                        WHEN infectado = 1
                        THEN peso_amostral
                        ELSE 0
                    END
                )
                / SUM(peso_amostral)
            )::NUMERIC,
            2
        ) AS percentual_ponderado

    FROM public.pnad_covid

    GROUP BY
        mes_referencia

    ORDER BY
        mes_referencia;

-- ============================================================================
-- 3. Principais sintomas
-- Variável no notebook: sql_principais_sintomas
-- ============================================================================
WITH infectados AS (
        SELECT
            peso_amostral,
            sintoma_febre,
            sintoma_tosse,
            sintoma_dor_garganta,
            sintoma_dificuldade_respirar,
            sintoma_dor_cabeca,
            sintoma_dor_peito,
            sintoma_nausea,
            sintoma_nariz_entupido,
            sintoma_fadiga,
            sintoma_dor_olhos,
            sintoma_perda_olfato_paladar,
            sintoma_dor_muscular,
            sintoma_diarreia
        FROM public.pnad_covid
        WHERE infectado = 1
    ),

    sintomas_unificados AS (
        SELECT
            peso_amostral,
            sintomas.nome_sintoma,
            sintomas.codigo_resposta

        FROM infectados

        CROSS JOIN LATERAL (
            VALUES
                ('Febre', sintoma_febre),
                ('Tosse', sintoma_tosse),
                ('Dor de garganta', sintoma_dor_garganta),
                ('Dificuldade para respirar', sintoma_dificuldade_respirar),
                ('Dor de cabeça', sintoma_dor_cabeca),
                ('Dor no peito', sintoma_dor_peito),
                ('Náusea', sintoma_nausea),
                ('Nariz entupido ou escorrendo', sintoma_nariz_entupido),
                ('Fadiga', sintoma_fadiga),
                ('Dor nos olhos', sintoma_dor_olhos),
                ('Perda de olfato ou paladar', sintoma_perda_olfato_paladar),
                ('Dor muscular', sintoma_dor_muscular),
                ('Diarreia', sintoma_diarreia)
        ) AS sintomas (
            nome_sintoma,
            codigo_resposta
        )
    )

    SELECT
        nome_sintoma,

        COUNT(*) FILTER (
            WHERE codigo_resposta = '1'
        ) AS entrevistados_com_sintoma,

        ROUND(
            SUM(
                CASE
                    WHEN codigo_resposta = '1'
                    THEN peso_amostral
                    ELSE 0
                END
            )::NUMERIC,
            0
        ) AS pessoas_estimadas,

        ROUND(
            (
                100.0
                * SUM(
                    CASE
                        WHEN codigo_resposta = '1'
                        THEN peso_amostral
                        ELSE 0
                    END
                )
                / SUM(peso_amostral)
            )::NUMERIC,
            2
        ) AS percentual_ponderado

    FROM sintomas_unificados

    GROUP BY
        nome_sintoma

    ORDER BY
        percentual_ponderado DESC;

-- ============================================================================
-- 4. Perfil por idade e sexo
-- Variável no notebook: sql_perfil_idade_sexo
-- ============================================================================
WITH perfil AS (
        SELECT
            CASE
                WHEN idade BETWEEN 0 AND 11
                    THEN '0 a 11 anos'
                WHEN idade BETWEEN 12 AND 17
                    THEN '12 a 17 anos'
                WHEN idade BETWEEN 18 AND 29
                    THEN '18 a 29 anos'
                WHEN idade BETWEEN 30 AND 39
                    THEN '30 a 39 anos'
                WHEN idade BETWEEN 40 AND 49
                    THEN '40 a 49 anos'
                WHEN idade BETWEEN 50 AND 59
                    THEN '50 a 59 anos'
                WHEN idade BETWEEN 60 AND 69
                    THEN '60 a 69 anos'
                WHEN idade BETWEEN 70 AND 79
                    THEN '70 a 79 anos'
                WHEN idade >= 80
                    THEN '80 anos ou mais'
            END AS faixa_etaria,

            CASE
                WHEN sexo = '1' THEN 'Homem'
                WHEN sexo = '2' THEN 'Mulher'
                ELSE 'Não informado'
            END AS sexo,

            peso_amostral,
            infectado

        FROM public.pnad_covid
    )

    SELECT
        faixa_etaria,
        sexo,

        COUNT(*) AS total_entrevistados,

        SUM(infectado) AS infectados_amostra,

        ROUND(
            SUM(peso_amostral)::NUMERIC,
            0
        ) AS populacao_estimada,

        ROUND(
            SUM(
                CASE
                    WHEN infectado = 1
                    THEN peso_amostral
                    ELSE 0
                END
            )::NUMERIC,
            0
        ) AS infectados_estimados,

        ROUND(
            (
                100.0
                * SUM(
                    CASE
                        WHEN infectado = 1
                        THEN peso_amostral
                        ELSE 0
                    END
                )
                / SUM(peso_amostral)
            )::NUMERIC,
            2
        ) AS percentual_positivo_grupo

    FROM perfil

    WHERE faixa_etaria IS NOT NULL

    GROUP BY
        faixa_etaria,
        sexo

    ORDER BY
        faixa_etaria,
        sexo;

-- ============================================================================
-- 5. Trabalho presencial e remoto
-- Variável no notebook: sql_impacto_trabalho_presencial
-- ============================================================================
WITH trabalhadores AS (
        SELECT
            peso_amostral,
            infectado,

            CASE
                WHEN trabalhou_na_semana = '1'
                     AND trabalhou_local_habitual = '2'
                     AND trabalho_remoto = '1'
                    THEN 'Remoto'

                WHEN trabalhou_na_semana = '1'
                     AND (
                         trabalhou_local_habitual = '1'
                         OR (
                             trabalhou_local_habitual = '2'
                             AND trabalho_remoto = '2'
                         )
                     )
                    THEN 'Presencial'

                WHEN trabalhou_na_semana = '1'
                    THEN 'Indeterminado'

                ELSE 'Fora da análise'
            END AS modalidade_trabalho

        FROM public.pnad_covid
    )

    SELECT
        modalidade_trabalho,

        COUNT(*) AS entrevistados,

        SUM(infectado) AS infectados_amostra,

        ROUND(
            (
                100.0 * SUM(infectado)
                / COUNT(*)
            )::NUMERIC,
            2
        ) AS percentual_amostra,

        ROUND(
            SUM(peso_amostral)::NUMERIC,
            0
        ) AS populacao_estimada,

        ROUND(
            SUM(
                CASE
                    WHEN infectado = 1
                    THEN peso_amostral
                    ELSE 0
                END
            )::NUMERIC,
            0
        ) AS infectados_estimados,

        ROUND(
            (
                100.0
                * SUM(
                    CASE
                        WHEN infectado = 1
                        THEN peso_amostral
                        ELSE 0
                    END
                )
                / NULLIF(SUM(peso_amostral), 0)
            )::NUMERIC,
            2
        ) AS percentual_positivo_ponderado

    FROM trabalhadores

    WHERE modalidade_trabalho IN (
        'Presencial',
        'Remoto'
    )

    GROUP BY
        modalidade_trabalho

    ORDER BY
        percentual_positivo_ponderado DESC;

-- ============================================================================
-- 6. Restrição de contato
-- Variável no notebook: sql_comportamento_restricao
-- ============================================================================
WITH comportamento AS (
        SELECT
            CASE
                WHEN nivel_restricao_contato = '1'
                    THEN 'Não fez restrição'

                WHEN nivel_restricao_contato = '2'
                    THEN 'Reduziu o contato, mas continuou saindo'

                WHEN nivel_restricao_contato = '3'
                    THEN 'Ficou em casa e saiu por necessidade'

                WHEN nivel_restricao_contato = '4'
                    THEN 'Ficou rigorosamente isolado'

                ELSE NULL
            END AS comportamento,

            peso_amostral

        FROM public.pnad_covid
    )

    SELECT
        comportamento,

        COUNT(*) AS entrevistados,

        ROUND(
            (
                100.0 * COUNT(*)
                / SUM(COUNT(*)) OVER ()
            )::NUMERIC,
            2
        ) AS percentual_amostra,

        ROUND(
            SUM(peso_amostral)::NUMERIC,
            0
        ) AS estimativa_ponderada,

        ROUND(
            (
                100.0 * SUM(peso_amostral)
                / SUM(SUM(peso_amostral)) OVER ()
            )::NUMERIC,
            2
        ) AS percentual_ponderado

    FROM comportamento

    WHERE comportamento IS NOT NULL

    GROUP BY
        comportamento

    ORDER BY
        percentual_ponderado DESC;

-- ============================================================================
-- 7. Itens preventivos no domicílio
-- Variável no notebook: sql_itens_prevencao
-- ============================================================================
WITH itens_unificados AS (
        SELECT
            peso_amostral,
            item.nome_item,
            item.codigo_resposta

        FROM public.pnad_covid

        CROSS JOIN LATERAL (
            VALUES
                (
                    'Sabão ou detergente',
                    domicilio_possui_sabao
                ),
                (
                    'Álcool 70%',
                    domicilio_possui_alcool_70
                ),
                (
                    'Máscaras',
                    domicilio_possui_mascaras
                ),
                (
                    'Luvas descartáveis',
                    domicilio_possui_luvas
                ),
                (
                    'Desinfetante',
                    domicilio_possui_desinfetante
                )
        ) AS item (
            nome_item,
            codigo_resposta
        )
    )

    SELECT
        nome_item,

        COUNT(*) FILTER (
            WHERE codigo_resposta = '1'
        ) AS entrevistados_com_item,

        COUNT(*) FILTER (
            WHERE codigo_resposta IN ('1', '2')
        ) AS respostas_validas,

        ROUND(
            SUM(
                CASE
                    WHEN codigo_resposta = '1'
                    THEN peso_amostral
                    ELSE 0
                END
            )::NUMERIC,
            0
        ) AS pessoas_estimadas_com_item,

        ROUND(
            (
                100.0
                * SUM(
                    CASE
                        WHEN codigo_resposta = '1'
                        THEN peso_amostral
                        ELSE 0
                    END
                )
                / NULLIF(
                    SUM(
                        CASE
                            WHEN codigo_resposta IN ('1', '2')
                            THEN peso_amostral
                            ELSE 0
                        END
                    ),
                    0
                )
            )::NUMERIC,
            2
        ) AS percentual_ponderado

    FROM itens_unificados

    GROUP BY
        nome_item

    ORDER BY
        percentual_ponderado DESC;

-- ============================================================================
-- 8. Base utilizada na clusterização
-- Variável no notebook: sql_base_clusterizacao
-- ============================================================================
SELECT
        id_registro,
        mes_referencia,
        peso_amostral,

        idade,
        sexo,
        cor_raca,
        escolaridade,
        uf,
        situacao_domicilio,

        sintoma_febre,
        sintoma_tosse,
        sintoma_dor_garganta,
        sintoma_dificuldade_respirar,
        sintoma_dor_cabeca,
        sintoma_dor_peito,
        sintoma_nausea,
        sintoma_nariz_entupido,
        sintoma_fadiga,
        sintoma_dor_olhos,
        sintoma_perda_olfato_paladar,
        sintoma_dor_muscular,
        sintoma_diarreia,

        possui_diabetes,
        possui_hipertensao,
        possui_doenca_respiratoria,
        possui_doenca_coracao,
        possui_depressao,
        possui_cancer,

        nivel_restricao_contato,

        trabalhou_na_semana,
        afastado_do_trabalho,
        trabalhou_local_habitual,
        trabalho_remoto,

        domicilio_possui_sabao,
        domicilio_possui_alcool_70,
        domicilio_possui_mascaras,
        domicilio_possui_luvas,
        domicilio_possui_desinfetante

    FROM public.pnad_covid

    WHERE infectado = 1

    ORDER BY id_registro;
