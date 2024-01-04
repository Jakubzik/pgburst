CREATE OR REPLACE FUNCTION public.test_archivieren()
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE 
i_aktiver_test integer;
i_antwortcounter integer;
i_bewerbercounter integer;
i_vorab_bewerbercounter integer;

BEGIN

	i_aktiver_test := (SELECT aufnahmetest_id FROM t_aufnahmetest WHERE aufnahmetest_aktiv=true);
	i_antwortcounter := (SELECT COUNT(*) FROM t_antwort WHERE aufnahmetest_id=i_aktiver_test);
	i_bewerbercounter := (SELECT COUNT(*) FROM t_bewerber WHERE datum::DATE IN ((SELECT aufnahmetest_datum FROM t_aufnahmetest WHERE aufnahmetest_id=i_aktiver_test), (SELECT aufnahmetest_datum2 FROM t_aufnahmetest WHERE aufnahmetest_id=i_aktiver_test)));
	i_vorab_bewerbercounter := (SELECT COUNT(DISTINCT bewerbernummer_tmp) FROM t_vorabtest_archiv WHERE bewerbernummer_tmp IS NOT null);

-- Daten von der Bewerber-Tabelle ins Archiv verschieben
-- Bewerbernummer bleibt temporär noch da, um Antworten und Einträge aus t_vorabtest_archiv zuordnen zu können
	
	INSERT INTO t_bewerber_archiv (
			plz, 
			weiblich, 
			bewerbernummer_tmp, 
			abiturnote, 
			abiturnote_gewichtet, 
			login_zeit, 
			testergebnis_raw, 
			testergebnis_skaliert, 
			zugelassen, 
			datum, 
			aufnahmetest_id
		) SELECT 
			b.plz, 
			b.weiblich, 
			b.bewerbernummer, 
			b.abiturnote, 
			b.abiturnote_gewichtet, 
			b.login_zeit, 
			e.testergebnis_raw, 
			e.testergebnis_skaliert, 
			e.zulassung, 
			b.datum::DATE, 
			i_aktiver_test
		FROM t_bewerber b
		LEFT JOIN t_ergebnisse e ON b.bewerbernummer = e.bewerbernummer
		WHERE datum::DATE IN ((SELECT aufnahmetest_datum FROM t_aufnahmetest WHERE aufnahmetest_id=i_aktiver_test), (SELECT aufnahmetest_datum2 FROM t_aufnahmetest WHERE aufnahmetest_id=i_aktiver_test));
		
			RAISE NOTICE '[INFO] Es wurden % Personen ins Bewerber-Archiv verschoben (t_bewerber_archiv).', i_bewerbercounter;
		
		
-- Antwortdaten ins Archiv verschieben
-- Bewerber-ID über t_bewerber_archiv den jeweiligen Antworten zuordnen		
		
		INSERT INTO t_antwort_archiv (
			bewerber_id, 
			aufnahmetest_id, 
			frage_id, 
			option_id, 
			antwort_zeit
		) SELECT 
			ba.bewerber_id, 
			ba.aufnahmetest_id, 
			a.frage_id, 
			a.option_id, 
			a.antwort_zeit
		FROM t_antwort a
		INNER JOIN t_bewerber_archiv ba ON a.bewerbernummer = ba.bewerbernummer_tmp
		WHERE a.aufnahmetest_id = i_aktiver_test;
	
		RAISE NOTICE '[INFO] Es wurden % Antworten ins Antworten-Archiv verschoben (t_antwort_archiv).', i_antwortcounter;
		RAISE NOTICE '[INFO] Im Antworten-Archiv sind jetzt insgesamt % Antworten.', (SELECT COUNT(*) FROM t_antwort_archiv);
		
		DELETE FROM t_antwort WHERE aufnahmetest_id = i_aktiver_test;
		
		RAISE NOTICE '[INFO] t_antwort ist jetzt geleert.';
	
-- Vorabtest-Archiv jetzt auch mit der Bewerber-ID verknüpfen (damit die gleiche Bewerber-ID den Vorabtest-Antworten und Test-Antworten einer Person zugeordnet ist)

		UPDATE t_vorabtest_archiv SET bewerber_id = (SELECT ba.bewerber_id FROM t_bewerber_archiv ba WHERE t_vorabtest_archiv.bewerbernummer_tmp = ba.bewerbernummer_tmp)  WHERE bewerbernummer_tmp IS NOT null;
		
		RAISE NOTICE '[INFO] Es wurden % Bewerber-IDs zu Antworten im Vorabtest-Archiv zugeordnet.', i_vorab_bewerbercounter;

		UPDATE t_vorabtest_archiv SET bewerbernummer_tmp = null WHERE aufnahmetest_id = 90001;
	
		RAISE NOTICE '[INFO] Vorabtest-Archiv anonymisiert (bewerbernummer_tmp geloescht).'; 
		
		
-- Bewerbernummer aus dem Archiv löschen und Bewerberdaten aus t_bewerber löschen

	UPDATE t_bewerber_archiv SET bewerbernummer_tmp = null WHERE aufnahmetest_id=i_aktiver_test; 
	DELETE FROM t_bewerber;
	
		RAISE NOTICE '[INFO] Bewerber-Archiv anonymisiert (bewerbernummer_tmp geloescht).';
		RAISE NOTICE '[INFO] t_bewerber ist jetzt geleert.'; 
		
	DELETE FROM t_ergebnisse; 
		RAISE NOTICE '[INFO] t_ergebnisse ist jetzt geleert.';
		
END;
$function$
