CREATE OR REPLACE FUNCTION public.mini_stats()
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE 
i_unfertige integer;
s_unfertige text;
t_slowest interval;
t_fastest interval;
t_avg interval;
i_points_highest integer;
i_points_lowest integer;
i_points_avg integer;
i_aktiver_test integer;

BEGIN
	
	i_aktiver_test := (SELECT aufnahmetest_id FROM t_aufnahmetest WHERE aufnahmetest_aktiv=true);

RAISE NOTICE '[INFO] Statistiken zu diesem Testdurchlauf:
';


-- Statistiken zur Testdauer: 

WITH p AS (
			SELECT bewerbernummer, login_zeit AS "startzeit"
			FROM t_bewerber 
			GROUP BY bewerbernummer
			),
		q AS (
			SELECT bewerbernummer, MAX(antwort_zeit) AS "schlusszeit"
			FROM t_antwort 
			WHERE aufnahmetest_id=i_aktiver_test
			GROUP BY bewerbernummer
			),
		o AS (
			SELECT p.startzeit, q.schlusszeit, bewerbernummer 
			FROM p INNER JOIN q USING (bewerbernummer)
			)
		SELECT INTO t_fastest, t_slowest, t_avg
			MIN(o.schlusszeit - o.startzeit), MAX(o.schlusszeit - o.startzeit), AVG(o.schlusszeit - o.startzeit)
		FROM o;

RAISE NOTICE '	Schnellster Testdurchlauf: %
		Langsamster Testdurchlauf: %
		Durchschnittliche Zeit: %
	', t_fastest, t_slowest, t_avg;



i_unfertige := (SELECT COUNT (CASE WHEN count < 65 THEN 1 ELSE NULL END) FROM (SELECT DISTINCT bewerbernummer, COUNT(*) FROM (SELECT * FROM t_antwort WHERE aufnahmetest_id=i_aktiver_test) AS alleantworten GROUP BY bewerbernummer) AS unfertige);
s_unfertige := 'Personen sind';

IF i_unfertige = 1 THEN
s_unfertige = 'Person ist';
END IF;

RAISE NOTICE '	% % nicht fertig geworden (nicht alle Fragen beantwortet).
', i_unfertige, s_unfertige;
	
	
	
-- Statistiken zur Punktzahl: 

i_points_highest := (SELECT MAX(testergebnis_raw) FROM t_ergebnisse);
i_points_lowest := (SELECT MIN(testergebnis_raw) FROM t_ergebnisse);
i_points_avg := (SELECT ROUND(AVG(testergebnis_raw)) FROM t_ergebnisse);

RAISE NOTICE '	Höchste Punktzahl: %
		Niedrigste Punktzahl: %
		Durchschnittliche Punktzahl: %
	', i_points_highest, i_points_lowest, i_points_avg;

	
-- optional TODO: Leichteste/schwerste Frage, Korrelation als .? (dann wird's kompliziert...) What else?
	
END;
$function$
