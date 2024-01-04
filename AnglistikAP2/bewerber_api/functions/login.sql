CREATE OR REPLACE FUNCTION bewerber_api.login(par_passwort character varying, par_bewerbernummer text)
 RETURNS TABLE(token bewerber_api.jwt_token, bewerber_name text, login_zeit_server text, bewerber_weiblich boolean, endfrage_id integer, anzahl_fragen integer, startfrage json, deadline text)
 LANGUAGE plpgsql
AS $function$

-- Zweck
-- =================
-- Prüft Bewerbernummer und Passwort beim ersten Login und
-- erzeugt im Erfolgsfall ein Java-Web-Token.
--
-- Weitere Funktionen für Bewerber (also: .handle_answer) sind
-- nur mit einem gültigen Token zugänglich.
--
-- Das Java-Web-Token (JWT) enthält (entschlüsselt) folgende Info:
-- nachname, login_zeit, bewerbernummer, weiblich, aufnahmetest_id, bearbeitungszeit
-- (jeweils erreichbar per:
-- select bewerber_api.get_decrypted_token())->'payload'->>'bewerbernummer' [et al.]
--
-- Das JWT sollte in HTTP[s] Anfragen im Header als Authentication: Bearer <TOKEN>
-- übergeben werden. Es wird dann in request.pg_api_muscle.token abgelegt,
-- vgl. bewerber_api.get_decrypted_token.
--
-- Voraussetzungen
-- =================
-- keine
--
-- Rückgabewert
-- =================
-- Tabelle mit token, Name d. Bewerbers/in, Login-Zeit des Servers.
--
-- Parameter
-- =================
-- Selbsterklärend
--
-- Fehler (x < 10)
-- =======================
-- #AAP2_ERR_1: Es gibt derzeit keinen "aktiven" Aufnahetest (vgl. t_aufnahmetest)
--
-- #AAP2_ERR_2: Passwort und Bewerbernummer finden sich nicht in t_bewerber.

-- #AAP2_ERR_3: Bearbeitungszeit ist abgelaufen.
--
-- @version 1.1.0, Feb 26, 2023: Token wird nur LOCAL übergeben, damit es nicht über die Anfrage hinaus in der Datenbank herumgeistert.
-- @version 1.0.1, Feb 13, 2023: Bewerbernummer muss nicht numerisch sein
-- @version 1.0.0, Dec 19, 2021
-- @todo Verschlüsselung, Passworte stehen noch im Klatext in der Datenbank

DECLARE
question json;
login_zt TIMESTAMP WITH TIME ZONE;
deadline INTEGER;
s_deadline TEXT;
bewerber_info NAME;
login_result bewerber_api.jwt_token;
anrede TEXT;
r RECORD;
g_MAX_MINUTEN_BEARBEITUNGSZEIT INTEGER;
g_aufnahmetest_id INTEGER;
text_var TEXT;
endfrage_id INTEGER;
anzahl_fragen INTEGER;

BEGIN

-- ================================================================================
-- Gibt es einen jetzt aktive Aufnahetest?
-- Falls ja, merke mir die Bearbeitungszeit (für das Token)
-- ================================================================================
g_MAX_MINUTEN_BEARBEITUNGSZEIT:=(SELECT aufnahmetest_dauer_min FROM t_aufnahmetest WHERE aufnahmetest_aktiv=TRUE AND (aufnahmetest_datum=CURRENT_DATE OR aufnahmetest_datum2=CURRENT_DATE) AND now()::TIME BETWEEN aufnahmetest_start AND aufnahmetest_stop);

text_var = '';

IF g_MAX_MINUTEN_BEARBEITUNGSZEIT IS NULL THEN
	RAISE EXCEPTION '#AAP2_ERR_1 Login: derzeit ist keine Aufnahmeprüfung fürs Login geöffnet';
END IF;

-- (@TODO: Dopplung der Abfrage von oben. Oder egal?)
g_aufnahmetest_id :=(SELECT aufnahmetest_id FROM t_aufnahmetest WHERE aufnahmetest_aktiv=TRUE AND (aufnahmetest_datum=CURRENT_DATE OR aufnahmetest_datum2=CURRENT_DATE) AND now()::TIME BETWEEN aufnahmetest_start AND aufnahmetest_stop);


-- ================================================================================
-- Stimmen Benutzernummer und Passwort?
-- ================================================================================
SELECT login_zeit, nachname, weiblich, bewerbernummer FROM t_bewerber WHERE bewerbernummer = par_bewerbernummer AND passwort = par_passwort INTO r;
-- deadline := (SELECT EXTRACT(epoch FROM now())::INTEGER + g_MAX_MINUTEN_BEARBEITUNGSZEIT*60);
-- s_deadline := EXTRACT('hour' FROM to_timestamp(deadline))::INTEGER || '.' || EXTRACT('minute' FROM to_timestamp(deadline));

IF NOT FOUND THEN
	-- Kein Eintrag -> Login falsch
	RAISE EXCEPTION '#AAP2_ERR_2 Login: Passwort oder Benutzernummer (oder beides) inkorrekt.';
ELSE
	login_zt = r.login_zeit;
	-- Login ist okay,
	-- ist es das *erste* Login?
	IF login_zt IS NULL THEN
		login_zt = now();
		UPDATE t_bewerber SET login_zeit=login_zt WHERE bewerbernummer = par_bewerbernummer AND passwort = par_passwort;
	ELSE
		IF EXTRACT(EPOCH FROM (now() - login_zt ))/60 > g_MAX_MINUTEN_BEARBEITUNGSZEIT THEN
			RAISE EXCEPTION '#AAP2_ERR_3 Login: Bearbeitungszeit ist abgelaufen, im Moment kein neues Login möglich.';
		END IF;
	END IF;

	IF r.weiblich THEN anrede = 'Frau ' || r.nachname;
	ELSE anrede = 'Herr ' || r.nachname;
	END IF;
  deadline := (SELECT EXTRACT(epoch from login_zt)::INTEGER + g_MAX_MINUTEN_BEARBEITUNGSZEIT*60);
  s_deadline := EXTRACT('hour' FROM to_timestamp(deadline)) || '.' || lpad(EXTRACT('minute' FROM to_timestamp(deadline))::text, 2, '0');

-- ================================================================================
-- Stelle Token zusammen, das
-- (1) das gültige Login signalisiert,
-- (2) Info zum Aufnahmetest, der Bearbeitungsdauer, Bewerbernummer etc. enthält
-- ================================================================================
  SELECT sign(
      row_to_json(res), 'ahz4vohB2Kee6uT4osheij2IeNoh8xoSoorohdeerah6OoYee7weamei2weingoo9we5eishetiwohveez9ucha7iegheil3aitah1iquauR4ahquo9chai8ieDohvaht5ohwahTh0Eereizae4ooyoFeaGodauc7tie6shoocieghai4tei5Aes6aCh7cao7Oshio3phaagaefeeg8Aa2eimohsaeNguLaesae8veikaereCheizoot0QuaiSh7aeB8bie5iipha6eiru0geKimo7isheiquaisie0Aiquezieke9zae3moh4eeph8eeteiboo8oodeixa5ahf4ieghowiuphithohcoo0ahf6Yieth7ohsae8Hierohmi8Shae5EquoovuaYeish6eiYago0caipoozimophahdoof3theev8apa1Aeph0emee2sualooph1Ie4shasho9saengov9ohngoongieghae3ahKee1Laewoh1Ooxahqui'
    ) AS token
    FROM (
      SELECT r.nachname, r.login_zeit, r.bewerbernummer, r.weiblich, g_aufnahmetest_id AS aufnahmetest_id, g_MAX_MINUTEN_BEARBEITUNGSZEIT AS bearbeitungszeit,
         deadline AS exp
    ) res
    INTO login_result;
END IF;

-- ========================================
-- Bestimme Anzahl der Testfragen
anzahl_fragen := (SELECT count(*) FROM t_aufnahmetest_x_frage WHERE aufnahmetest_id = g_aufnahmetest_id);

-- ========================================
-- Bestimme ID der *letzten* Testfrage
endfrage_id := (SELECT frage_id FROM t_aufnahmetest_x_frage WHERE aufnahmetest_id=1 ORDER BY aufnahmetest_frage_sequence DESC LIMIT 1);

-- Für den Abruf der ersten Fragen muss das Token gesetzt sein:
perform set_config('request.pg_api_muscle.token'::TEXT, login_result.token, TRUE); --26.2.23
question = row_to_json( bewerber_api.get_question( r.bewerbernummer, -1, TRUE, TRUE ));
perform set_config('request.pg_api_muscle.token'::TEXT, '', TRUE); -- 26.2.23

RETURN QUERY SELECT login_result, r.nachname, now()::TEXT, r.weiblich, endfrage_id, anzahl_fragen, question, s_deadline;

END;

$function$
