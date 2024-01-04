create or replace view "public"."t_k_k_a_f_ap" AS  WITH fragetags AS (
         SELECT json_agg(t.*) AS fragetags
           FROM ( SELECT t_fragetag.fragetag_id AS tagid,
                    t_fragetag.fragetag_text AS tagname
                   FROM t_fragetag) t
        ), tagreferenz AS (
         SELECT json_agg(tx.*) AS tagreferenz
           FROM ( SELECT t_frage_x_tag.fragetag_id AS tagid,
                    t_frage_x_tag.frage_id
                   FROM t_frage_x_tag) tx
        ), kategorien AS (
         SELECT json_agg(u.*) AS kategorien
           FROM ( SELECT t_fragekategorie.fragekategorie_id AS kategorieid,
                    t_fragekategorie.fragekategorie_text AS kategoriename
                   FROM t_fragekategorie) u
        ), kontexte AS (
         SELECT json_agg(v.*) AS kontexte
           FROM ( SELECT t_fragekontext.fragekontext_id,
                    t_fragekontext.fragekontext_text,
                    t_fragekontext.fragekontext_quelle,
                    t_fragekontext.fragekontexttyp_id
                   FROM t_fragekontext) v
        ), antwortoptionen AS (
         SELECT json_agg(w.*) AS antwortoptionen
           FROM ( SELECT t_antwortoption.frage_id,
                    t_antwortoption.option_id,
                    t_antwortoption.option_text,
                    t_antwortoption.option_correct
                   FROM t_antwortoption) w
        ), fragen AS (
         SELECT json_agg(x.*) AS fragen
           FROM ( SELECT t_frage.frage_id,
                    t_frage.fragekategorie_id,
                    t_frage.fragekontext_id,
                    t_frage.frage_text
                   FROM t_frage) x
        ), aufnahmetests AS (
         SELECT json_agg(y.*) AS aufnahmetests
           FROM ( SELECT t_aufnahmetest.aufnahmetest_id AS apid,
                    t_aufnahmetest.aufnahmetest_semester AS apname
                   FROM t_aufnahmetest) y
        )
 SELECT json_build_object('fragetags', fragetags.fragetags, 'tagreferenz', tagreferenz.tagreferenz, 'fragekategorie', kategorien.kategorien, 'fragekontext', kontexte.kontexte, 'antwortoptionen', antwortoptionen.antwortoptionen, 'fragen', fragen.fragen, 'ap', aufnahmetests.aufnahmetests) AS tkkaf
   FROM fragetags,
    tagreferenz,
    kategorien,
    kontexte,
    antwortoptionen,
    fragen,
    aufnahmetests;