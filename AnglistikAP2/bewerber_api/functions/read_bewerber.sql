CREATE OR REPLACE FUNCTION bewerber_api.read_bewerber()
 RETURNS void
 LANGUAGE plpgsql
AS $function$

DECLARE
r_B RECORD;
BEGIN

FOR r_B IN SELECT * FROM t_bewerber_import LOOP

   perform * FROM t_bewerber WHERE bewerbernummer = r_B.bewerbernummer;
   IF NOT FOUND THEN
      INSERT INTO t_bewerber( weiblich, vorname, nachname, bewerbernummer, email, abiturnote, abiturnote_gewichtet, passwort, datum ) VALUES 
    (r_B.weiblich, r_B.vorname, r_B.nachname, r_B.bewerbernummer, r_B.email, r_B.abiturnote, r_B.abiturnote_gewichtet, bewerber_api.get_random_password(6), 
--    case when r_B.bewerbernummer::int % 2 = 0 then '17.8.2022' else '18.8.2022' End);
    '23.2.2023');
   ELSE
      RAISE NOTICE 'Bewerber mit Nr. % kannten wir schon sehr lange (% %)', r_B.bewerbernummer, r_B.vorname, r_B.nachname;
   END IF;
END LOOP;

END;
$function$
