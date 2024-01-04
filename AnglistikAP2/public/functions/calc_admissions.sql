CREATE OR REPLACE FUNCTION public.calc_admissions(i_wunschzahl integer DEFAULT '-1'::integer, b_export boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE 
i_cutoff integer;
i_personenzahl integer;
b_toomany boolean;
i_cutoff_alt integer;
i_personen_alt integer;

BEGIN

	i_cutoff := 1;
	i_cutoff_alt := 65;
	i_personen_alt := 0;
	b_toomany := false;
	i_personenzahl := 0;
	
	IF i_wunschzahl >= 0 THEN
-- der LOOP (also die eigentliche Funktion) startet nur, wenn die Funktion mit einer Wunschzahl als Parameter aufgerufen wurde.
		LOOP

		PERFORM * FROM get_test_results(i_cutoff, true);

		i_personenzahl = (SELECT COUNT(bewerbernummer) FROM t_ergebnisse WHERE zulassung=true);

		IF i_wunschzahl = i_personenzahl THEN
			RAISE NOTICE '[INFO] Wenn % Personen zugelassen werden sollen, werden mindestens % Punkte zum Bestehen des Tests benötigt.', i_wunschzahl, i_cutoff;
			EXIT;
		ELSE 
			IF i_wunschzahl < i_personenzahl THEN
				b_toomany = true;
				i_cutoff_alt = i_cutoff;
				i_personen_alt = i_personenzahl;
				i_cutoff = i_cutoff + 1;
			ELSE 
				IF i_wunschzahl > i_personenzahl THEN
					RAISE NOTICE '[INFO] Bei einer Mindestpunktzahl von % Punkten werden % Personen zugelassen.', i_cutoff, i_personenzahl;
					IF b_toomany = true THEN
						RAISE NOTICE '	Die nächste Stufe wären % Punkte (% Zulassungen).', i_cutoff_alt, i_personen_alt;
					ELSE 
						RAISE NOTICE '	Vielleicht gibt es nicht genügend Bewerbungen?';
					END IF;
					EXIT;
				ELSE RAISE NOTICE 'something went wrong';
				END IF;
			END IF;
		END IF;
		END LOOP;

		RAISE NOTICE '[INFO] Die Ergebnisse sind in t_ergebnisse eingetragen.
		
		Rudimentäre Statistiken: 
			SELECT * FROM mini_stats()
			';

		IF b_export = true THEN 
			PERFORM * FROM export_results(i_personenzahl);
		ELSE
			RAISE NOTICE '[INFO] Um CSV und HTML-Dateien mit dem aktuellen Ergebnis zu erzeugen, entweder diese Funktion nochmal mit (i_wunschzahl, true) aufrufen, oder direkt export_results() aufrufen.
			';
		END IF;
	ELSE 
		RAISE EXCEPTION 'Fehlender Parameter (Wunschzahl).'
		USING HINT = 'Die Funktion calc_admissions() muss mit der gewünschten Anzahl zuzulassender Personen als Parameter aufgerufen werden. 
	Optional kann auch direkt der Export ausgelöst werden (by default deaktiviert).';
	END IF;

END;
$function$
