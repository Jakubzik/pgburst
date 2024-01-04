create or replace view "public"."fragen_und_kontexte" AS  WITH fragen AS (
         SELECT json_agg(u.*) AS fragen
           FROM ( SELECT t_frage.frage_id,
                    t_frage.fragekategorie_id,
                    t_frage.fragekontext_id,
                    t_frage.frage_text
                   FROM t_frage) u
        ), kontexte AS (
         SELECT json_agg(v.*) AS kontexte
           FROM ( SELECT t_fragekontext.fragekontext_id,
                    t_fragekontext.fragekontexttyp_id,
                    t_fragekontext.fragekontext_text,
                    t_fragekontext.fragekontext_quelle
                   FROM t_fragekontext) v
        )
 SELECT json_build_object('fragen', fragen.fragen, 'kontexte', kontexte.kontexte) AS f_u_k,
    1 AS id
   FROM fragen,
    kontexte;