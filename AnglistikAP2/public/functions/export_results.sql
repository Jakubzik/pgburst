CREATE OR REPLACE FUNCTION public.export_results(i_personenzahl integer DEFAULT 1, s_filepath text DEFAULT '/tmp/'::text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE 
s_filename text;
s_csv_file text;
s_html_file text;
s_today text;

-- DECLARES für HTML-Export:
r_B RECORD;
html_table text;
i_alle_viertel decimal;
i_countno integer;

BEGIN

-- AE 2023-08-11: s_filename parametrisiert ist neu, v.a. das SELECT

s_today := (SELECT to_char(now(), 'DD. MonthYYYY'));

s_filename := (COALESCE((SELECT aufnahmetest_kurzsemester FROM t_aufnahmetest WHERE aufnahmetest_aktiv=true), '23wi')) || '-zulassungen';

IF i_personenzahl > 1 THEN
	s_filename = s_filename || '-' || i_personenzahl;
END IF;

s_csv_file := s_filepath || s_filename || '.csv';
s_html_file := s_filepath || s_filename || '.html';

-- 4.1: HTML-Export: 

i_alle_viertel = (SELECT COUNT(bewerbernummer) FROM (SELECT DISTINCT bewerbernummer FROM t_ergebnisse WHERE zulassung=true) AS alle_zuzulassende)/4 + 1;
i_countno := 1;
html_table := '<html><head><meta content="text/html; charset=ISO-8859-15" http-equiv="content-type"><title>Zuzulassende zuk&uuml;nftige AnglistInnen</title><link rel="stylesheet" href="aufnahme.css"></head><body><div id="aufn-content"><h1>Liste der Bewerbernummern</h1><p><strong>von erfolgreichen BewerberInnen um einen Studienplatz Anglistik, die zum' || (COALESCE((SELECT aufnahmetest_semester FROM t_aufnahmetest WHERE aufnahmetest_aktiv=true), 'Wintersemester 2023/24')) || ' in Heidelberg f&uuml;r Anglistik zugelassen werden</strong></p><table><tr valign="top"><td>';
FOR r_B in SELECT
	bewerbernummer,	zulassung
FROM t_ergebnisse WHERE zulassung = true
ORDER BY bewerbernummer
LOOP
IF i_countno >= i_alle_viertel THEN
	html_table = html_table || r_B.bewerbernummer || '<br></td><td>';
	i_countno = 1;
ELSE
	html_table = html_table || r_B.bewerbernummer || '<br>';
	i_countno = i_countno + 1;
END IF;
END LOOP;
html_table = html_table || '</td></tr></table><div id="aufn-footer">' || s_today || ', H. Jakubzik f&uuml;r die Gesch&auml;ftsf&uuml;hrung -- Angaben ohne Gew&auml;hr<br></div></div></body></html>';


EXECUTE format('
   COPY (
       SELECT %L
   )
   TO %L;
', html_table, s_html_file);



-- 4.2: CSV-Export: 

EXECUTE format('
COPY(
SELECT bewerbernummer, vorname, nachname, email, testergebnis_skaliert AS testergebnis, punkte_gesamt, 
CASE 
WHEN zulassung = true THEN ''ja'' 
WHEN zulassung = false THEN ''nein'' 
ELSE ''nicht erschienen''
END AS zuzulassen
FROM t_ergebnisse RIGHT JOIN t_bewerber USING (bewerbernummer)
ORDER BY zuzulassen
) 
TO %L
DELIMITER '';'' 
CSV HEADER;
', s_csv_file);


-- 4.3: Info:

RAISE NOTICE '[INFO] Die Dateien sind mit dem Dateinamen % als CSV und HTML unter % abgelegt.', s_filename, s_filepath; 

RAISE NOTICE '[INFO] Für eine Tabelle mit Name, Mailadresse, Anrede, Testpunktzahl (unskaliert) der erfolgreichen Bewerber_innen auf Basis der aktuellen t_ergebnisse: 
		get_bewerber_stats() aufrufen.';

END;
$function$
