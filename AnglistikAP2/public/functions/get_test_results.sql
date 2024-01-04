CREATE OR REPLACE FUNCTION public.get_test_results(i_cutoff integer, b_from_calc boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE 

i_aktiver_test integer;

BEGIN
	
	i_aktiver_test := (SELECT aufnahmetest_id FROM t_aufnahmetest WHERE aufnahmetest_aktiv=true);

	-- tabelle bauen:

	DROP TABLE IF EXISTS t_ergebnisse;

	CREATE TABLE t_ergebnisse (bewerbernummer text PRIMARY KEY, abiturnote_gewichtet text, testergebnis_raw integer, testergebnis_skaliert integer, punkte_gesamt integer, zulassung BOOLEAN); 


	-- Für jede Bewerbernummer, die Fragen im Test beantwortet hat, einen Eintrag in der Ergebnis-Tabelle anlegen:

	INSERT INTO t_ergebnisse(bewerbernummer)
	SELECT DISTINCT bewerbernummer FROM t_antwort WHERE aufnahmetest_id=i_aktiver_test;


	UPDATE t_ergebnisse
	SET 

	-- ZÄHLT die richtigen gegebenen antworten:

	testergebnis_raw =
	(SELECT COUNT(bewerbernummer) FROM (SELECT t_antwort.bewerbernummer, t_antwort.frage_id, t_antwort.option_id, t_antwortoption.option_correct FROM t_antwort INNER JOIN t_antwortoption USING (frage_id, option_id) WHERE option_correct=true AND t_antwort.aufnahmetest_id=i_aktiver_test AND bewerbernummer=t_ergebnisse.bewerbernummer) AS antwortzahl);


	UPDATE t_ergebnisse
	SET 

	-- skaliertes testergebnis: 

	testergebnis_skaliert =
	CASE 
		WHEN testergebnis_raw < 10 THEN 0
		WHEN testergebnis_raw < i_cutoff THEN 5
		WHEN testergebnis_raw < 41 THEN 35
		WHEN testergebnis_raw < 50 THEN 40
		WHEN testergebnis_raw > 49 THEN 45
		ELSE null
	END,


	-- gewichtete abinote eintragen:

	abiturnote_gewichtet = 
	(SELECT t_bewerber.abiturnote_gewichtet FROM t_bewerber WHERE t_bewerber.bewerbernummer = t_ergebnisse.bewerbernummer);


	UPDATE t_ergebnisse
	SET

	-- punkte gesamt:

	punkte_gesamt =
	 (SELECT CAST(REPLACE(abiturnote_gewichtet, ',', '.') AS DECIMAL) + testergebnis_skaliert * 3);
	-- WS 20/21: Die Abiturnote war ohne Multiplikator, aber bereits mit 1,5-facher Gewichtung im Import.
	-- sonst zum beispiel: 
	-- (SELECT CAST(REPLACE(abiturnote_gewichtet, '.', '') AS INTEGER) / 100000 + testergebnis_skaliert * 3);


	UPDATE t_ergebnisse
	SET

	-- Entscheidung Zulassung y/n basierend auf Punktzahl (nach der Zulassungssatzung):

	zulassung = 
	CASE
		WHEN punkte_gesamt > 109 THEN true
		ELSE false
	END;
	-- die folgende NOTICE soll nur angezeigt werden, wenn die Funktion einzeln aufgerufen wird, nicht wenn sie aus dem LOOP der calc_admissions-Funktion kommt.
	IF b_from_calc = false THEN
		RAISE NOTICE '[INFO] Die Ergebnisse sind unter t_ergebnisse abgelegt. Jetzt können auch alle anderen Auswertungsfunktionen, zum Beispiel export_results() und mini_stats(), aufgerufen werden.';
	END IF;
END;
$function$
