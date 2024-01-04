CREATE OR REPLACE FUNCTION public.url_encode(data bytea)
 RETURNS text
 LANGUAGE sql
AS $function$
    SELECT translate(encode(data, 'base64'), E'+/=\n', '-_');
$function$
