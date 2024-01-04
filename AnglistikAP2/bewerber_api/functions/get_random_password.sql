CREATE OR REPLACE FUNCTION bewerber_api.get_random_password(length integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
BEGIN

RETURN (SELECT array_to_string(ARRAY(SELECT substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz',((random()*(62-1)+1)::INTEGER),1) FROM generate_series(1,length)),''));

END;
$function$
