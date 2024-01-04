CREATE OR REPLACE FUNCTION public.trigger_aufnahmetest_upsert()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$

-- Stellt sicher, dass immer nur 1 
-- Aufnahmeprüfung als "aktiv" markiert ist
-- (Das ist wichtig z.B. fürs Login, aber auch 
-- fürs Abrufen der richtigen Fragen).
BEGIN

IF new.aufnahmetest_aktiv THEN
   UPDATE t_aufnahmetest SET aufnahmetest_aktiv = FALSE WHERE aufnahmetest_id != new.aufnahmetest_id;
END IF;

RETURN NEW;
END;
$function$
