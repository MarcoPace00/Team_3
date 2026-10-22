/*
	Aggiornamento delle fasce d'età (AgeGroup) su un database onthemovie_2 già creato e caricato.
	Su un database nuovo non serve: crea_tabelle_onthemovie_2.sql crea già la colonna così.

	Nuove fasce: <10, 10-13, 14-17, poi ogni 5 anni da 18-22 fino a 88-90, oltre >90.

	AgeGroup diventa una colonna calcolata da MySQL a partire da Age:
		- non serve ricaricare i dati, le fasce si ricalcolano subito su tutti gli utenti;
		- gli utenti caricati in futuro con carica_dati.py ricevono la fascia in automatico;
		- le viste (v_top10_eta_sesso) e Power BI usano già AgeGroup, non vanno modificati.

	Lo script è rieseguibile: per cambiare di nuovo le fasce basta modificare il CASE e rilanciarlo.
*/

USE onthemovie_2;

-- 1. tolgo il vecchio CHECK sulle fasce ('U18', '18-24', ...), se c'è ancora
SET @chk = NULL;
SELECT CONSTRAINT_NAME INTO @chk
FROM information_schema.CHECK_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'onthemovie_2'
  AND CHECK_CLAUSE LIKE '%AgeGroup%'
LIMIT 1;

SET @sql = IF(@chk IS NULL, 'DO 0', CONCAT('ALTER TABLE users DROP CHECK `', @chk, '`'));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 2. ricreo AgeGroup come colonna calcolata da Age (stessa definizione di crea_tabelle_onthemovie_2.sql)
ALTER TABLE users DROP COLUMN AgeGroup;

ALTER TABLE users ADD COLUMN AgeGroup VARCHAR(5) GENERATED ALWAYS AS (CASE
	WHEN Age IS NULL THEN NULL
	WHEN Age < 10    THEN '<10'
	WHEN Age <= 13   THEN '10-13'
	WHEN Age <= 17   THEN '14-17'
	WHEN Age <= 90   THEN CONCAT(18 + 5 * FLOOR((Age - 18) / 5), '-',
	                             LEAST(22 + 5 * FLOOR((Age - 18) / 5), 90))
	ELSE '>90'
END) STORED;

-- verifica: una riga per fascia, con età minima e massima
SELECT AgeGroup, MIN(Age) AS eta_min, MAX(Age) AS eta_max, COUNT(*) AS n_utenti
FROM users
GROUP BY AgeGroup
ORDER BY MIN(Age);
