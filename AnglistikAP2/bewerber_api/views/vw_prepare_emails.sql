create or replace view "bewerber_api"."vw_prepare_emails" AS  SELECT (((((((((((((('./prepare_email.sh '::text || bewerbernummer) || ' '''::text) || passwort) || ''' '::text) || email) || ' '::text) || datum) || ' '::text) ||
        CASE
            WHEN (datum = '9.7.2023'::text) THEN '16.8.2023 '::text
            ELSE '17.8.2023 '::text
        END) || '''Dear '::text) || vorname) || ' '::text) || nachname) || ''''::text) AS "?column?"
   FROM t_bewerber;