/*
	Creazione delle viste usate dalla dashboard OnTheMovie_visual_v2.pbix
	nel database onthemovie_2.

	Prerequisiti: tabelle create (crea_tabelle_onthemovie_2.sql) e dati caricati
	(05_caricamento_python/carica_dati.py). Le viste si possono creare anche a
	tabelle vuote: si aggiornano da sole quando arrivano nuovi dati.

	Viste:
		- v_film_da_eliminare   film con almeno 250 recensori e voto medio < 3
		- v_top10_eta_sesso     top 10 film per fascia d'età e sesso (min 30 voti)
		- v_iscritti_provincia  iscritti per provincia (decodifica CAP -> provincia)

	Lo script è rieseguibile: CREATE OR REPLACE sovrascrive le viste esistenti.
*/

USE onthemovie_2;

CREATE OR REPLACE VIEW v_film_da_eliminare AS
SELECT f.MovieID, f.Title, f.Year,
       COUNT(DISTINCT r.UsersID) AS n_recensori,
       ROUND(AVG(r.Rating), 2)   AS voto_medio
FROM ratings r
JOIN film f ON f.MovieID = r.MovieID
GROUP BY f.MovieID, f.Title, f.Year
HAVING COUNT(DISTINCT r.UsersID) >= 250
   AND AVG(r.Rating) < 3;
   
CREATE OR REPLACE VIEW v_top10_eta_sesso AS
WITH stats AS (
    SELECT u.AgeGroup, u.Gender, r.MovieID,
           COUNT(*) AS n_voti, AVG(r.Rating) AS voto_medio
    FROM ratings r
    JOIN users u ON u.UsersID = r.UsersID
    GROUP BY u.AgeGroup, u.Gender, r.MovieID
    HAVING COUNT(*) >= 30
)
SELECT * FROM (
    SELECT s.AgeGroup, s.Gender, f.Title, s.n_voti,
           ROUND(s.voto_medio, 2) AS voto_medio,
           ROW_NUMBER() OVER (PARTITION BY s.AgeGroup, s.Gender
                              ORDER BY s.voto_medio DESC, s.n_voti DESC) AS posizione
    FROM stats s
    JOIN film f ON f.MovieID = s.MovieID
) t
WHERE posizione <= 10;

-- users ha solo il CAP: decodifica CAP -> provincia nel CASE (78 CAP distinti, fonte comuni-json)
CREATE OR REPLACE VIEW v_iscritti_provincia AS
SELECT Provincia, COUNT(*) AS n_iscritti
FROM (
    SELECT CASE
        WHEN u.CAP IN ('15063', '15067', '15077') THEN 'Alessandria'
        WHEN u.CAP IN ('63100') THEN 'Ascoli Piceno'
        WHEN u.CAP IN ('14025', '14100') THEN 'Asti'
        WHEN u.CAP IN ('83030') THEN 'Avellino'
        WHEN u.CAP IN ('70026', '70037') THEN 'Bari'
        WHEN u.CAP IN ('76012') THEN 'Barletta-Andria-Trani'
        WHEN u.CAP IN ('32030') THEN 'Belluno'
        WHEN u.CAP IN ('24020') THEN 'Bergamo'
        WHEN u.CAP IN ('40061', '40138') THEN 'Bologna'
        WHEN u.CAP IN ('25043', '25123') THEN 'Brescia'
        WHEN u.CAP IN ('72022') THEN 'Brindisi'
        WHEN u.CAP IN ('86020') THEN 'Campobasso'
        WHEN u.CAP IN ('95127') THEN 'Catania'
        WHEN u.CAP IN ('22072', '22076') THEN 'Como'
        WHEN u.CAP IN ('87060') THEN 'Cosenza'
        WHEN u.CAP IN ('26010', '26100') THEN 'Cremona'
        WHEN u.CAP IN ('12032') THEN 'Cuneo'
        WHEN u.CAP IN ('44020', '44121') THEN 'Ferrara'
        WHEN u.CAP IN ('50055') THEN 'Firenze'
        WHEN u.CAP IN ('71032') THEN 'Foggia'
        WHEN u.CAP IN ('47030') THEN 'Forlì-Cesena'
        WHEN u.CAP IN ('03100') THEN 'Frosinone'
        WHEN u.CAP IN ('67069') THEN 'L''Aquila'
        WHEN u.CAP IN ('19020') THEN 'La Spezia'
        WHEN u.CAP IN ('73020') THEN 'Lecce'
        WHEN u.CAP IN ('20020', '20023', '20131', '20139') THEN 'Milano'
        WHEN u.CAP IN ('41058') THEN 'Modena'
        WHEN u.CAP IN ('80038') THEN 'Napoli'
        WHEN u.CAP IN ('09078', '09099') THEN 'Oristano'
        WHEN u.CAP IN ('35010', '35031', '35124') THEN 'Padova'
        WHEN u.CAP IN ('90143') THEN 'Palermo'
        WHEN u.CAP IN ('27024') THEN 'Pavia'
        WHEN u.CAP IN ('61029') THEN 'Pesaro e Urbino'
        WHEN u.CAP IN ('65017', '65027') THEN 'Pescara'
        WHEN u.CAP IN ('56022') THEN 'Pisa'
        WHEN u.CAP IN ('85024') THEN 'Potenza'
        WHEN u.CAP IN ('47924') THEN 'Rimini'
        WHEN u.CAP IN ('00018', '00061', '00125', '00153') THEN 'Roma'
        WHEN u.CAP IN ('45030', '45100') THEN 'Rovigo'
        WHEN u.CAP IN ('84066', '84070') THEN 'Salerno'
        WHEN u.CAP IN ('17021') THEN 'Savona'
        WHEN u.CAP IN ('09010') THEN 'Sud Sardegna'
        WHEN u.CAP IN ('64023') THEN 'Teramo'
        WHEN u.CAP IN ('10086', '10126') THEN 'Torino'
        WHEN u.CAP IN ('34149') THEN 'Trieste'
        WHEN u.CAP IN ('33013', '33030', '33048', '33050') THEN 'Udine'
        WHEN u.CAP IN ('21014', '21030') THEN 'Varese'
        WHEN u.CAP IN ('30020') THEN 'Venezia'
        WHEN u.CAP IN ('28887') THEN 'Verbano-Cusio-Ossola'
        WHEN u.CAP IN ('36012', '36100') THEN 'Vicenza'
        WHEN u.CAP IN ('01010') THEN 'Viterbo'
        ELSE 'Non mappato'
    END AS Provincia
    FROM users u
) p
GROUP BY Provincia;


-- verifica: devono comparire le 3 viste
SHOW FULL TABLES WHERE Table_type = 'VIEW';
