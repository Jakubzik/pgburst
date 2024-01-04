CREATE OR REPLACE FUNCTION public.vorabtest_archivieren()
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE 
i_vorabtestid integer;
i_antwortcounter integer;
i_bewerbercounter integer;

BEGIN


	-- Falls wir die Vorabtest-ID parametrisieren möchten, ist das so schonmal vorbereitet

	i_vorabtestid := 90001;
	i_antwortcounter := (SELECT COUNT(*) FROM t_antwort WHERE aufnahmetest_id=i_vorabtestid);
	i_bewerbercounter := (SELECT COUNT(*) FROM t_bewerber WHERE login_zeit IS NOT null);


	-- Vorabtest-Antworten archivieren
	-- (statische aufnahmetest_id, weil der Vorabtest zumindest momentan immer 90001 ist.) 

	INSERT INTO t_vorabtest_archiv (bewerbernummer_tmp, aufnahmetest_id, frage_id, option_id, antwort_zeit) 
	SELECT bewerbernummer, aufnahmetest_id, frage_id, option_id, antwort_zeit
	FROM t_antwort WHERE aufnahmetest_id=i_vorabtestid;
	
	RAISE NOTICE '[INFO] Es wurden % Antworten ins Vorabtest-Archiv verschoben (von % Bewerber_innen).', i_antwortcounter, i_bewerbercounter;

	-- nach der Archivierung der Vorabtest-Antworten in t_vorabtest_archiv 
	-- sollen die Antworten aus t_antwort gelöscht werden
	-- um Platz für die eigentliche Testdurchführung zu machen.

	DELETE FROM t_antwort WHERE aufnahmetest_id=i_vorabtestid;
	RAISE NOTICE '[INFO] Vorabtest-Antworten sind aus t_antwort geloescht.';

	-- die login_zeit in der aktiven t_bewerber-Tabelle muss zurückgesetzt werden, 
	-- damit Bewerber_innen, die am Vorabtest teilgenommen haben, sich 
	-- zum richtigen Test wieder einloggen können. 

	UPDATE t_bewerber SET login_zeit=null; 
	RAISE NOTICE '[INFO] Login-Zeit wurde fuer alle Bewerber_innen zurueckgesetzt.'; 
	RAISE NOTICE '[INFO] Bewerber- und Antworten-Tabelle sind ready fuer den richtigen Testtermin.';


END;
$function$
