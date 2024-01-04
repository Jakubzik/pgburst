create or replace view "public"."t_k_k" AS  WITH fragetags AS (
         SELECT json_agg(t.*) AS fragetags
           FROM ( SELECT t_fragetag.fragetag_id AS tagid,
                    t_fragetag.fragetag_text AS tagname
                   FROM t_fragetag) t
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
        ), aufgabenstellungen AS (
         SELECT json_agg(w.*) AS aufgabenstellungen
           FROM ( SELECT t_aufgabenstellung.aufgabenstellung_id,
                    t_aufgabenstellung.aufgabenstellung_text,
                    t_aufgabenstellung.aufgabenstellung_kurzbezeichnung,
                    t_aufgabenstellung.aufgabenstellung_beispiel
                   FROM t_aufgabenstellung) w
        )
 SELECT json_build_object('fragetags', fragetags.fragetags, 'fragekategorie', kategorien.kategorien, 'fragekontext', kontexte.kontexte, 'aufgabenstellung', aufgabenstellungen.aufgabenstellungen) AS t_k_k
   FROM fragetags,
    kategorien,
    kontexte,
    aufgabenstellungen;