CREATE OR REPLACE FUNCTION public.sign(payload json, secret text, algorithm text DEFAULT 'HS256'::text)
 RETURNS text
 LANGUAGE sql
AS $function$
WITH
  header AS (
    SELECT public.url_encode(convert_to('{"alg":"' || algorithm || '","typ":"JWT"}', 'utf8')) AS data
    ),
  payload AS (
    SELECT public.url_encode(convert_to(payload::text, 'utf8')) AS data
    ),
  signables AS (
    SELECT header.data || '.' || payload.data AS data FROM header, payload
    )
SELECT
    signables.data || '.' ||
    public.algorithm_sign(signables.data, secret, algorithm) FROM signables;
$function$
