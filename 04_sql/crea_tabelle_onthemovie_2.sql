/*
	Creazione del database onthemovie_2 e delle sue 5 tabelle (SOLO DDL).
	Il database originale "OnTheMovie" non viene toccato.

	Il caricamento dei dati NON avviene qui: si fa con gli script Python
	della cartella 05_caricamento_python (mysql.connector).
	Le viste per la dashboard sono in crea_views_onthemovie_2.sql (stessa cartella).

	Tabelle (in ordine di creazione: prima le "padre", poi le associative):
		- film         (MovieID, Title, Year)
		- genres       (generi_id, Genres)
		- generi_film  (MovieID, generi_id)                         associativa film <-> genres
		- users        (UsersID, Gender, Age, CAP, Work, AgeGroup)
		- ratings      (UsersID, MovieID, Rating, Timestamp)        associativa users <-> film

	Lo script è rieseguibile: IF NOT EXISTS non cancella nulla.
	Per ripartire da zero, decommentare la riga DROP DATABASE qui sotto.
*/

-- DROP DATABASE IF EXISTS onthemovie_2;

CREATE DATABASE IF NOT EXISTS onthemovie_2
	CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE onthemovie_2;

CREATE TABLE IF NOT EXISTS film (
	MovieID INT PRIMARY KEY,
    Title   VARCHAR(255),          -- nullable: il film 3936 non ha titolo
    Year    SMALLINT
);

CREATE TABLE IF NOT EXISTS genres (
	generi_id INT PRIMARY KEY,
    Genres    VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS generi_film (
	MovieID   INT NOT NULL,
    generi_id INT NOT NULL,
    PRIMARY KEY (MovieID, generi_id),
    FOREIGN KEY (MovieID)   REFERENCES film(MovieID),
    FOREIGN KEY (generi_id) REFERENCES genres(generi_id)
);

-- utenti: requisiti da mail del PM "Requisiti DB OnTheMovie"
CREATE TABLE IF NOT EXISTS users (
	UsersID INT AUTO_INCREMENT PRIMARY KEY,                      -- ID univoco dell'utente
    Gender  CHAR(1) CHECK (Gender IN ('M', 'F')),                -- sesso
    Age     TINYINT UNSIGNED CHECK (Age BETWEEN 0 AND 120),      -- età
    CAP     VARCHAR(10),                                         -- provenienza; testo per non perdere gli zeri iniziali (es. 00184)
    Work    VARCHAR(100),                                        -- lavoro
    AgeGroup VARCHAR(5)                                          -- fascia d'età, calcolata da Age in normalizzazione_user_rating.ipynb
		CHECK (AgeGroup IN ('U18', '18-24', '25-34', '35-44', '45-54', '55+'))
);

-- valutazioni: tabella associativa users <-> film (un voto per utente per film)
CREATE TABLE IF NOT EXISTS ratings (
	UsersID   INT NOT NULL,
    MovieID   INT NOT NULL,
    Rating    TINYINT NOT NULL CHECK (Rating BETWEEN 1 AND 5),
    Timestamp DATETIME NOT NULL,                                 -- UTC, convertito da Unix time nel notebook
    PRIMARY KEY (UsersID, MovieID),
    FOREIGN KEY (UsersID) REFERENCES users(UsersID),
    FOREIGN KEY (MovieID) REFERENCES film(MovieID)
);

-- verifica: devono comparire le 5 tabelle
SHOW TABLES;
