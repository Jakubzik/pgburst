CREATE OR REPLACE FUNCTION bewerber_api.handle_answer(par_bewerbernummer text, par_antwortoption character varying, par_frage_id integer)
 RETURNS TABLE(frage_text text, frage_id bigint, antwortoptionen json, aufgabenstellung text, fragekontext json, frage_lfdnr bigint)
 LANGUAGE plpgsql
AS $function$

-- 
-- Zweck
-- =================
-- Speichert die gewählte Antwort und liefert die 
-- nächste Frage.
--
-- Voraussetzungen
-- =================
-- Voraussetzung für den Aufruf ist das Setzen von 
-- request.pg_api_muscle.token, das die bewerbernummer
-- enthält.
-- 
-- Rückgabewert
-- =================
-- Tabelle mit der nächsten Frage, den Antwortoptionen, der 
-- Aufgabenstellung und dem -Kontext.
--
-- Die Antwortoptionen haben jeweils die Eigenschaft 
-- 'gewaehlt' (boolean), die anzeigen, ob diese Antwortoption
-- vom Bewerber bereits markiert wurde oder nicht.
--
-- Die Rückgabe kommt direkt von get_question
--
-- Parameter
-- =================
-- Selbsterklärend 
-- 
-- Fehler (100 <= x <=200)
-- =======================
-- #AAP2_ERR_100: Bewerbernummer passt nicht zum Token.
--
-- @version 1.0.0 -- Dec 19, 2021.
--          1.0.2 -- Jan 17, 2022 h: frage_sequence geändert zu frage_lfdnr
--          1.0.3 -- Feb 13, 2023 h: Bewerbernummer ist jetzt text

DECLARE

g_MAX_MINUTEN_BEARBEITUNGSZEIT INTEGER;
l_next_frage_id integer;
g_aufnahmetest_id integer;

BEGIN

-- ============================================================
-- ist das Token gültig und passend zur Bewerbernummer?
-- (wird zwar auch in get_question geprüft; hier allerdings 
--  auch, damit nicht vorher noch eine Antwort gespeichert 
--  werden kann).
if (select bewerber_api.get_decrypted_token())->'payload'->>'bewerbernummer' != par_bewerbernummer THEN
 	Raise Exception '#AAP2_ERR_100 Antwort: Bewerbernummer >%< passt nicht zum übergebenen Token demnach: %', par_bewerbernummer,(select bewerber_api.get_decrypted_token())->'payload'->>'bewerbernummer' ;
END IF;
-- 
g_aufnahmetest_id = (select bewerber_api.get_decrypted_token()->'payload'->>'aufnahmetest_id');

-- ============================================================
-- ist die Bearbeitungszeit auch nicht abgelaufen?
--
-- Wird bei get_question überprüft.

-- ============================================================
-- Wurde die Frage schon zuvor von dieser Benutzerin beantwortet?
perform FROM t_antwort WHERE 
	bewerbernummer = par_bewerbernummer
	AND aufnahmetest_id = g_aufnahmetest_id
	AND t_antwort.frage_id = par_frage_id;

IF NOT FOUND THEN
	-- a) Nein, wurde noch nicht beantwortet, neue Antwort wird gespeichert
	INSERT INTO t_antwort( aufnahmetest_id, bewerbernummer, frage_id, option_id, antwort_ip, antwort_zeit ) VALUES 
    ( g_aufnahmetest_id, par_bewerbernummer, par_frage_id, par_antwortoption, '', now());
ELSE
	-- b) Ja, die alte Antwort wird ersetzt.
	UPDATE t_antwort SET 
		option_id = par_antwortoption, 
		antwort_zeit = now() 
	WHERE bewerbernummer = par_bewerbernummer
	  AND aufnahmetest_id = g_aufnahmetest_id 
		AND t_antwort.frage_id = par_frage_id;
END IF;

-- ============================================================
-- Nächste Frage ermitteln
return query select * from bewerber_api.get_question( par_bewerbernummer, par_frage_id, true );

END;

$function$
