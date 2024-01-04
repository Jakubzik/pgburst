CREATE OR REPLACE FUNCTION public.add_frage(frage text)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$

DECLARE
  frage_neu_id INTEGER;
  r record;
  antwort json;
  tags json;
  frage_in json;

BEGIN

-- select public.add_frage('{
--   "fragekategorie_id": 2,
--   "fragekontext_id": 4,
--   "aufgabenstellung_id": 4,
  -- "frage_text": "ist dies ein fragetext?",
--   "antwortoptionen": [
--     {
--       "option_id": "A",
--       "option_text": "erste antwort",
--       "option_correct": false
--     },
--     {
--       "option_id": "B",
--       "option_text": "zweite antwort",
--       "option_correct": false
--     },
--     {
--       "option_id": "C",
--       "option_text": "dritte antwort, die richtig ist",
--       "option_correct": true
--     },
--     {
--       "option_id": "D",
--       "option_text": "vierte antwort",
--       "option_correct": false
--     }
--   ],
  -- "frage_tags": [
--     1,
--     7
--   ]
-- }'::json);
frage_in := frage::json;
RAISE warning 'Look %', frage_in->>'fragekategorie_id';
RAISE warning 'Look DEBUG aufgabenstellung: %', frage_in->>'aufgabenstellung_id';

-- Hat eigentlich eine Sequence, aber die spinnt im Moment (hat sich vllt. verzählt)
frage_neu_id := (SELECT max(frage_id)+1 FROM t_frage);

-- Wenn fragekontext_id = 'nichts' -> fragekontext_id = null
if frage_in->>'fragekontext_id' = 'nichts' THEN
  INSERT INTO t_frage ( "frage_id", "fragekategorie_id", "fragekontext_id", "frage_text", "frage_custom1", "aufgabenstellung_id") 
  VALUES ( frage_neu_id, (frage_in->>'fragekategorie_id')::INTEGER, null, (frage_in->>'frage_text'), 'Angelegt am ' || CURRENT_DATE, (frage_in->>'aufgabenstellung_id')::INTEGER);
else
  INSERT INTO t_frage ( "frage_id", "fragekategorie_id", "fragekontext_id", "frage_text", "frage_custom1", "aufgabenstellung_id") 
  VALUES ( frage_neu_id, (frage_in->>'fragekategorie_id')::INTEGER, (frage_in->>'fragekontext_id')::INTEGER, (frage_in->>'frage_text'), 'Angelegt am ' || CURRENT_DATE, (frage_in->>'aufgabenstellung_id')::INTEGER);
end if;

BEGIN

    FOR r IN (SELECT jsonb_array_elements(frage_in::jsonb->'antwortoptionen') antwort)
    LOOP
        RAISE NOTICE 'Hier %', r.antwort;
        INSERT INTO "public"."t_antwortoption" ( "frage_id", "option_id", "option_text", "option_correct") 
        VALUES ( frage_neu_id, r.antwort->>'option_id', r.antwort->>'option_text', (r.antwort->>'option_correct')::BOOLEAN );
    END LOOP;
END;

BEGIN
	
	FOR r IN (SELECT jsonb_array_elements(frage_in::jsonb->'frage_tags') tags)
	LOOP
		RAISE NOTICE 'Tag ist %', r.tags;
		INSERT INTO "public"."t_frage_x_tag" ( "frage_id", "fragetag_id")
		VALUES ( frage_neu_id, ((r.tags)#>>'{}')::INTEGER ); 
		-- r.tags ist das jeweilige Element im tags-array. Direkt von jsonb::int funktioniert nicht, also per #>>'{}' erst zu Text, dann ::INT. Die Tabelle erwartet einen Integer. 
	END LOOP;
	
END;

  RETURN frage_neu_id;
END;
$function$
