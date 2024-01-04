CREATE OR REPLACE FUNCTION public.auswertung_start()
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE 
i_teilnehmer integer;
i_alle_bewerber integer;
i_aktiver_test integer;

BEGIN

	i_alle_bewerber := (SELECT COUNT(bewerbernummer) FROM (SELECT DISTINCT bewerbernummer FROM t_bewerber) AS allebewerber);
	
	i_aktiver_test := (SELECT aufnahmetest_id FROM t_aufnahmetest WHERE aufnahmetest_aktiv=true);

	i_teilnehmer := (SELECT COUNT(bewerbernummer) FROM (SELECT DISTINCT bewerbernummer FROM t_antwort WHERE aufnahmetest_id=i_aktiver_test) AS teilgenommene);


	RAISE NOTICE '[INFO] Am Aufnahmetest haben % Personen teilgenommen (von insgesamt % Bewerber_innen).', i_teilnehmer, i_alle_bewerber;

	RAISE NOTICE '[INFO] Um die Auswertung zu starten: 
			SELECT * FROM calc_admissions(i) 
			mit i = gewünschte Anzahl zuzulassender Personen. 
		Wenn auch direkt ein CSV-Export und eine HTML-Datei mit Bewerbernummern erzeugt werden sollen: 
			SELECT * FROM calc_admissions(i, true).
		';

END;
$function$
