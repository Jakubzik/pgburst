CREATE OR REPLACE FUNCTION public.verify(token text, secret text, algorithm text DEFAULT 'HS256'::text)
 RETURNS TABLE(header json, payload json, valid boolean)
 LANGUAGE sql
AS $function$
  SELECT
    convert_from(public.url_decode(r[1]), 'utf8')::json AS header,
    convert_from(public.url_decode(r[2]), 'utf8')::json AS payload,
    r[3] = public.algorithm_sign(r[1] || '.' || r[2], secret, algorithm) AS valid
  FROM regexp_split_to_array(token, '\.') r;
$function$
