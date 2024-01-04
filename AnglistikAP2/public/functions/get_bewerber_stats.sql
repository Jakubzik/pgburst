CREATE OR REPLACE FUNCTION public.get_bewerber_stats()
 RETURNS void
 LANGUAGE plpgsql
AS $function$

BEGIN

-- 5.1: Kleine Tabelle für die Statistik

DROP TABLE IF EXISTS t_stats_bewerber;

CREATE TABLE t_stats_bewerber (abfrage_wann timestamp, bew_gesamt integer, bew_teilgenommen integer, bew_zugelassen integer);

INSERT INTO t_stats_bewerber (abfrage_wann) VALUES (now());

UPDATE t_stats_bewerber

SET

-- alle bewerber:

bew_gesamt =
(SELECT COUNT(bewerbernummer) FROM (SELECT DISTINCT bewerbernummer from t_bewerber) AS allepersonen),

-- bewerber teilgenommen: 

bew_teilgenommen =
(SELECT COUNT(bewerbernummer) FROM (SELECT DISTINCT bewerbernummer from t_ergebnisse) AS teilgenommene),

-- bewerber zugelassen: 

bew_zugelassen =
(SELECT COUNT(bewerbernummer) FROM (SELECT DISTINCT bewerbernummer FROM t_ergebnisse WHERE zulassung=true) AS zugelassene);


RAISE NOTICE '[INFO] Eine knappe Übersicht über Bewerbungen-Teilnahmen-Zulassungen ist unter t_stats_bewerber abgelegt.';



-- 5.2: Tabelle mit allen zuzulassenden Bewerber_innen (für mails etc)

DROP TABLE IF EXISTS t_bewerber_zulassung;

CREATE TABLE t_bewerber_zulassung (bewerbernummer text, vorname text, nachname text, plz character varying(10), weiblich boolean, email text, testpunktzahl integer);

INSERT INTO t_bewerber_zulassung (bewerbernummer, testpunktzahl)
SELECT DISTINCT bewerbernummer, testergebnis_raw FROM t_ergebnisse WHERE zulassung=true;

UPDATE t_bewerber_zulassung
SET

vorname =

(SELECT t_bewerber.vorname FROM t_bewerber WHERE t_bewerber.bewerbernummer = t_bewerber_zulassung.bewerbernummer),

nachname =

(SELECT t_bewerber.nachname FROM t_bewerber WHERE t_bewerber.bewerbernummer = t_bewerber_zulassung.bewerbernummer),

plz =

(SELECT t_bewerber.plz FROM t_bewerber WHERE t_bewerber.bewerbernummer = t_bewerber_zulassung.bewerbernummer),

weiblich = 

(SELECT t_bewerber.weiblich FROM t_bewerber WHERE t_bewerber.bewerbernummer = t_bewerber_zulassung.bewerbernummer),

email =

(SELECT t_bewerber.email FROM t_bewerber WHERE t_bewerber.bewerbernummer = t_bewerber_zulassung.bewerbernummer);

/* eigentlich müsste es besser gehen als das gleiche WHERE in jeden update-schritt hier reinzuschreiben. aber wie? */


RAISE NOTICE '[INFO] Die Tabelle mit Kontaktdaten der erfolgreichen Bewerber_innen ist unter t_bewerber_zulassung abgelegt.';

END;
$function$
