CREATE OR REPLACE FUNCTION public.get_fragen_stats()
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE 

i_aktiver_test integer;

BEGIN
	
	i_aktiver_test := (SELECT aufnahmetest_id FROM t_aufnahmetest WHERE aufnahmetest_aktiv=true);

-- zählt, wie viele Teilnehmer_innen jede Frage richtig beantwortet haben und zeigt die durchschnittliche (gewichtete) Abinote und das durchschnittliche Testergebnis der entsprechenden Personen an:

drop table if exists t_fragen_stats;

create table t_fragen_stats (aufgabenstellung_id int, frage_id int, summe_richtige int, avg_abinote int, avg_testergebnis int);

INSERT INTO t_fragen_stats (frage_id, summe_richtige)

SELECT DISTINCT frage_id, COUNT(*) FROM (SELECT t_antwort.frage_id, t_antwort.option_id FROM t_antwort INNER JOIN t_antwortoption ON t_antwort.frage_id = t_antwortoption.frage_id WHERE t_antwort.frage_id = t_antwortoption.frage_id AND t_antwort.option_id = t_antwortoption.option_id AND t_antwortoption.option_correct = true AND t_antwort.aufnahmetest_id=i_aktiver_test ORDER BY frage_id) AS bla GROUP BY frage_id ORDER BY frage_id;

UPDATE t_fragen_stats

SET aufgabenstellung_id = 

(SELECT aufgabenstellung_id FROM t_frage WHERE t_frage.frage_id = t_fragen_stats.frage_id),

avg_abinote =

-- erst wird die antworten-tabelle mit der antwortoptionen-tabelle zusammengeführt um zu schauen, welche antworten in t_antwort richtig sind. dann wird von den richtigen antworten aus t_antwort die bewerbernummer genommen und das mit t_bewerber zusammengeführt, um die zugehörige abinote zu finden.

(SELECT ROUND(AVG(CAST(REPLACE(abiturnote_gewichtet, ',', '.') AS DECIMAL))) FROM t_bewerber INNER JOIN (SELECT t_antwort.frage_id, t_antwort.option_id, t_antwort.bewerbernummer FROM t_antwort INNER JOIN t_antwortoption ON t_antwort.frage_id = t_antwortoption.frage_id WHERE t_antwort.frage_id = t_antwortoption.frage_id AND t_antwort.option_id = t_antwortoption.option_id AND t_antwortoption.option_correct = true AND t_antwort.aufnahmetest_id=i_aktiver_test) AS gegebene_antworten ON t_bewerber.bewerbernummer = gegebene_antworten.bewerbernummer WHERE gegebene_antworten.frage_id = t_fragen_stats.frage_id GROUP BY frage_id),

-- andere Abiturnotengewichtung (mit 100.000 skaliert):
-- (SELECT ROUND(AVG(CAST(REPLACE(abiturnote_gewichtet, '.', '') AS integer)/100000)) FROM t_bewerber INNER JOIN (SELECT t_antwort.frage_id, t_antwort.option_id, t_antwort.bewerbernummer FROM t_antwort WHERE aufnahmetest_id=i_aktiver_test INNER JOIN t_antwortoption ON t_antwort.frage_id = t_antwortoption.frage_id WHERE t_antwort.frage_id = t_antwortoption.frage_id AND t_antwort.option_id = t_antwortoption.option_id AND t_antwortoption.option_correct = true) AS gegebene_antworten ON t_bewerber.bewerbernummer = gegebene_antworten.bewerbernummer WHERE gegebene_antworten.frage_id = t_fragen_stats.frage_id GROUP BY frage_id),

avg_testergebnis =

(SELECT ROUND(AVG(testergebnis_raw)) FROM t_ergebnisse INNER JOIN (SELECT t_antwort.frage_id, t_antwort.option_id, t_antwort.bewerbernummer FROM t_antwort INNER JOIN t_antwortoption ON t_antwort.frage_id = t_antwortoption.frage_id WHERE t_antwort.frage_id = t_antwortoption.frage_id AND t_antwort.aufnahmetest_id=i_aktiver_test AND t_antwort.option_id = t_antwortoption.option_id AND t_antwortoption.option_correct = true) AS gegebene_antworten ON t_ergebnisse.bewerbernummer = gegebene_antworten.bewerbernummer WHERE gegebene_antworten.frage_id = t_fragen_stats.frage_id GROUP BY frage_id);


-- wenn man das Gegenstück dazu haben will (falsch beantwortete), einfach drei mal "true" durch "false" ersetzen.

END;
$function$
