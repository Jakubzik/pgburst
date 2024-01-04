CREATE OR REPLACE FUNCTION bewerber_api.get_question(par_bewerbernummer text, par_frage_id integer, forward boolean DEFAULT false, first_question boolean DEFAULT false)
 RETURNS TABLE(frage_text text, frage_id bigint, antwortoptionen json, aufgabenstellung text, fragekontext json, frage_lfdnr bigint)
 LANGUAGE plpgsql
AS $function$

-- Zweck
-- =================
-- Nächste (oder vorherige) Frage im Text mit Optionen, Kontext und 
-- Brimborium zurückgeben, falls ein aktuell gültiges Login vorliegt.
--
-- 
-- Von login aufgerufen kann auch die *erste* Frage der Prüfung
-- ausgegeben werden.

-- Voraussetzungen
-- =================
-- Voraussetzung für den Aufruf ist das Setzen von 
-- request.pg_api_muscle.token, das die bewerbernummer
-- enthält (und die Aufnahmetest-Id)
-- 
-- Rückgabewert
-- =================
-- Tabelle mit der Frage, den Antwortoptionen, der 
-- Aufgabenstellung und dem -Kontext.
--
-- Die Antwortoptionen haben jeweils die Eigenschaft 
-- 'gewaehlt' (boolean), die anzeigen, ob diese Antwortoption
-- vom Bewerber markiert wurde oder nicht.
--
-- Parameter
-- =================
-- Selbsterklärend außer "forward":
-- forward = true liefert die auf 'frage_id' folgende Frage
-- forward = false liefert die vorangehende Frage
--
-- Default ist 
-- forward = false, d.h. die vorangehende Frage.
-- 
-- Fehler (10 <= x <=100)
-- =======================
-- #AAP2_ERR_10: Bewerbernummer passt nicht zum Token.
-- #AAP2_ERR_11: Bearbeitungszeit abgelaufen.
-- #AAP2_ERR_12: Es gibt keine nächste (vorangehende) Frage.

-- 
-- @version 1.0.0 Dec 19, 2021
--          1.0.2 Jan 17, 2022 gebe nicht "sequence" zurück, sondern "frage_lfdnr"
--                             @todo: "letzte Frage" klarer kommunizieren?
--          1.0.3 Feb 13, 2023 Bewerbernummer ist inzwischen text anstatt integer
DECLARE

l_next_frage_id integer;
g_MAX_MINUTEN_BEARBEITUNGSZEIT integer;
g_aufnahmetest_id integer;

BEGIN

-- ============================================================
-- ist das Token gültig und passend zur Bewerbernummer?
if (select bewerber_api.get_decrypted_token())->'payload'->>'bewerbernummer' != par_bewerbernummer::text THEN
	Raise Exception '#AAP2_ERR_10 Frage: Bewerbernummer >%< passt nicht zum übergebenen Token', par_bewerbernummer;
END IF;

-- ============================================================
-- Die Bearbeitungszeit steht in t_aufnahmetest und 
-- wird im Token abgelegt:
g_MAX_MINUTEN_BEARBEITUNGSZEIT = (select bewerber_api.get_decrypted_token()->'payload'->>'bearbeitungszeit');
g_aufnahmetest_id = (select bewerber_api.get_decrypted_token()->'payload'->>'aufnahmetest_id');

-- ============================================================
-- ist die Bearbeitungszeit auch nicht abgelaufen?
perform * FROM t_bewerber 
WHERE t_bewerber.bewerbernummer = par_bewerbernummer::text 
   AND EXTRACT(EPOCH FROM (now() - login_zeit ))/60 < g_MAX_MINUTEN_BEARBEITUNGSZEIT;

IF NOT FOUND THEN
		-- Zeit ist offenbar abgelaufen
		RAISE EXCEPTION '#AAP2_ERR_11 Frage kann nicht abgerufen werden, die Bearbeitungszeit ist abgelaufen.';
END IF;

-- ============================================================
-- Bestimme die ID der nächsten (vorangehenden) Frage
-- (Die Reihenfolge wird in t_aufnahmetest_x_frage fest-
--  gelegt).
l_next_frage_id = case when forward then 
   case when first_question then 
      (select xx.frage_id from t_aufnahmetest_x_frage xx where aufnahmetest_id = g_aufnahmetest_id order by aufnahmetest_frage_sequence asc limit 1)
   else 
      (select xx.frage_id from t_aufnahmetest_x_frage xx where aufnahmetest_id = g_aufnahmetest_id and aufnahmetest_frage_sequence > (select aufnahmetest_frage_sequence from t_aufnahmetest_x_frage x where aufnahmetest_id = g_aufnahmetest_id and x.frage_id = par_frage_id) order by aufnahmetest_frage_sequence asc limit 1)
   end
else 
   (select xx.frage_id from t_aufnahmetest_x_frage xx where aufnahmetest_id = g_aufnahmetest_id and aufnahmetest_frage_sequence < (select aufnahmetest_frage_sequence from t_aufnahmetest_x_frage x where aufnahmetest_id = g_aufnahmetest_id and x.frage_id = par_frage_id) order by aufnahmetest_frage_sequence desc limit 1)
end;

if l_next_frage_id is null then 
	-- @todo sollte ein leeres Resultset zurückgeben?
  -- h 2022-1-17: so ist es ja jetzt -- leeres ResultSet. Wäre aber
  -- vielleicht eine spezifischere Antwort (die sich klarer von 
  -- einem Fehler unterscheidet) besser?
	IF forward then
		RAISE NOTICE '#AAP2_ERR_12 Frage: letzte Frage. Test wird abgeschlossen.';
		-- (AE 2022-01-14)
	ELSE
		raise exception '#AAP2_ERR_12 Frage: keine weitere Frage vorhanden.';
	END IF;
end if;

-- frage_id muss für die *erste* Frage mitgeliefert
-- werden.
return query 
With ao2 as (select o.frage_id, o.option_id, o.option_text, case when a is null then false else true end as gewaehlt from public.t_antwortoption o left join public.t_antwort a on (a.bewerbernummer=par_bewerbernummer::text and a.aufnahmetest_id=g_aufnahmetest_id and a.frage_id=o.frage_id and a.option_id=o.option_id) order by o.option_id)
select f.frage_text,
   f.frage_id,
   json_agg( ao2.* ),
   ta.aufgabenstellung_text,
   json_agg( DISTINCT tk.* ),
   (select count(*) from t_aufnahmetest_x_frage where aufnahmetest_id = g_aufnahmetest_id and aufnahmetest_frage_sequence <= (select aufnahmetest_frage_sequence from t_aufnahmetest_x_frage x2 where aufnahmetest_id = g_aufnahmetest_id and x2.frage_id = l_next_frage_id)) frage_lfdnr
--   axf.aufnahmetest_frage_sequence
 from t_frage f 
        inner join ao2 on (f.frage_id=ao2.frage_id) 
        inner join t_aufgabenstellung ta on (ta.aufgabenstellung_id = f.aufgabenstellung_id)
        left join t_fragekontext tk on (tk.fragekontext_id = f.fragekontext_id)
 where f.frage_id=l_next_frage_id 
 group by f.frage_text, f.frage_id, ta.aufgabenstellung_text, tk.fragekontext_text;

END;
$function$
