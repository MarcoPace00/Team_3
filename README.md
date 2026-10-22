# OnTheMovie – Team 3

Pipeline dati di OnTheMovie: dai csv originali alle tabelle MySQL del database **`onthemovie_2`** fino alla dashboard Power BI.

`onthemovie_2` è un database separato. Il vecchio `OnTheMovie` non viene toccato.

## Struttura delle cartelle

| Cartella                 | Contenuto                                                                                                                                                 |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `01_dati_originali/`     | Dati grezzi ricevuti:`Elenco Movies definitivo.csv` / `.xlsx`, `users_edit.csv`, `ratings_edit.csv`                                                       |
| `02_preprocessing/`      | Notebook di pulizia:`normalizzazione_film_generi.ipynb`, `normalizzazione_user_rating.ipynb`                                                              |
| `03_dati_preprocessati/` | Csv puliti, uno per tabella:`film.csv`, `genres.csv`, `generi_film.csv`, `users_checked.csv`, `ratings_checked.csv`                                       |
| `04_sql/`                | `crea_tabelle_onthemovie_2.sql`: crea il database e le 5 tabelle vuote (solo DDL)<br>`crea_views_onthemovie_2.sql`: crea le 3 viste usate dalla dashboard |
| `05_caricamento_python/` | `carica_dati.py` (caricamento con `mysql.connector`), `config.py` (connessione)                                                                           |
| `06_visual/`             | `OnTheMovie_visual_v2.pbix` (dashboard) e `province_italia.topo.json` (mappa delle province)                                                              |
| `requirements.txt`       | Librerie Python del progetto, da installare nel `.venv` nella cartella `Team_3`                                                                           |

## Flusso

```
01_dati_originali ──(notebook 02)──> 03_dati_preprocessati ──(carica_dati.py)──> MySQL onthemovie_2 ──> Power BI (06)
                                                                     ▲
                                              tabelle e viste create da 04_sql
```

## Viste

| Vista                  | Contenuto                                                        | Richiesta del cliente                |
| ---------------------- | ---------------------------------------------------------------- | ------------------------------------ |
| `v_film_da_eliminare`  | Film con almeno 250 recensori e voto medio < 3                   | Film da eliminare                    |
| `v_top10_eta_sesso`    | Top 10 film per fascia d'età e sesso (almeno 30 voti nel gruppo) | Top 10 per età e sesso               |
| `v_iscritti_provincia` | Iscritti per provincia, ricavata dal CAP con un`CASE`            | Distribuzione iscritti per provincia |

Le viste non contengono dati propri: vengono ricalcolate dalle tabelle a ogni lettura. Quando si aggiungono dati con `carica_dati.py` si aggiornano da sole, senza rieseguire lo script.

Un utente con un CAP che non è nel `CASE` di `v_iscritti_provincia` finisce in `'Non mappato'`. In quel caso aggiungi il CAP alla riga della sua provincia in `crea_views_onthemovie_2.sql` e riesegui lo script.

## Modello dati

| Tabella       | Colonne                                   | Chiave primaria      | Foreign key    | Csv                   |
| ------------- | ----------------------------------------- | -------------------- | -------------- | --------------------- |
| `film`        | MovieID, Title, Year                      | MovieID              | –              | `film.csv`            |
| `genres`      | generi_id, Genres                         | generi_id            | –              | `genres.csv`          |
| `generi_film` | MovieID, generi_id                        | (MovieID, generi_id) | → film, genres | `generi_film.csv`     |
| `users`       | UsersID, Gender, Age, CAP, Work, AgeGroup | UsersID              | –              | `users_checked.csv`   |
| `ratings`     | UsersID, MovieID, Rating, Timestamp       | (UsersID, MovieID)   | → users, film  | `ratings_checked.csv` |

---

## Avvio della pipeline (prima volta)

### 0. Prerequisiti

- MySQL 8 in esecuzione (servizio `MySQL80`) e MySQL Workbench
- Python 3 con un ambiente virtuale `.venv` nella cartella del progetto. Da un terminale aperto nella cartella `Team_3`:

```
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

Se PowerShell blocca `Activate.ps1` ("l'esecuzione di script è disabilitata"), esegui una sola volta `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` e riprova.

Il `.venv` va creato una volta sola. Nelle sessioni successive basta attivarlo con `.\.venv\Scripts\Activate.ps1`: il prompt mostra `(.venv)` all'inizio. Tutti i comandi `python` di questo README vanno lanciati con il `.venv` attivo.

In VS Code seleziona l'interprete del `.venv` (**Python: Select Interpreter** → `.venv\Scripts\python.exe`) e, nei notebook, il kernel `.venv`.

### 1. Preprocessing (facoltativo)

I csv in `03_dati_preprocessati/` sono già pronti. Rilancia i notebook solo se cambiano i dati originali.

Apri i notebook dalla cartella `02_preprocessing/`, perché usano percorsi relativi (`..\01_dati_originali`, `..\03_dati_preprocessati`). Poi esegui **Run All**:

1. `normalizzazione_film_generi.ipynb` → `film.csv`, `genres.csv`, `generi_film.csv`
2. `normalizzazione_user_rating.ipynb` → `users_checked.csv`, `ratings_checked.csv`

### 2. Creazione delle tabelle

In MySQL Workbench apri `04_sql/crea_tabelle_onthemovie_2.sql` ed eseguilo (⚡). Alla fine `SHOW TABLES` deve mostrare 5 tabelle.

Puoi rieseguire lo script senza perdere dati, perché usa `IF NOT EXISTS`. Per ripartire da zero, decommenta la riga `DROP DATABASE IF EXISTS onthemovie_2;`.

### 3. Caricamento dei dati

Dalla cartella `Team_3`, con il `.venv` attivo:

```
cd 05_caricamento_python
python carica_dati.py
```

La password MySQL viene chiesta a terminale. Host, porta, utente (`root`) e database (`onthemovie_2`) sono in `config.py`. In alternativa puoi impostarli con le variabili d'ambiente `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PASSWORD` e `MYSQL_DATABASE`.

Lo script carica le tabelle in quest'ordine, rispettando le foreign key: `film` → `genres` → `generi_film` → `users` → `ratings`. Per ogni tabella stampa quante righe ha inserito. `ratings` ha circa 1 milione di righe, quindi ci vuole qualche minuto.

Righe attese a fine caricamento:

| film  | genres | generi_film | users | ratings   |
| ----- | ------ | ----------- | ----- | --------- |
| 3.883 | 18     | 6.402       | 6.040 | 1.000.209 |

### 4. Creazione delle viste

In MySQL Workbench apri `04_sql/crea_views_onthemovie_2.sql` ed eseguilo (⚡). Alla fine devono comparire 3 viste.

Lo script funziona anche a tabelle vuote, ma conviene eseguirlo dopo il caricamento per controllare subito che le viste restituiscano righe. Puoi rieseguirlo quando vuoi, perché usa `CREATE OR REPLACE VIEW`.

### 5. Dashboard

Apri `06_visual/OnTheMovie_visual_v2.pbix`. Se il file è ancora collegato al database `OnTheMovie`, va ricollegato a `onthemovie_2` (con il trattino basso).

**Impostazioni origine dati → Cambia origine** da sola non basta. Il nome del database compare due volte in ogni query: nel passaggio `Origine` e nello `Schema` del passaggio `Navigazione`, e Cambia origine aggiorna solo il primo. Per cambiarlo in un punto solo usa un parametro:

1. **Trasforma dati → Gestisci parametri → Nuovo**: nome `Database`, tipo **Testo**, valore corrente `onthemovie_2`.
2. Per ognuna delle 8 query apri **Editor avanzato** e sostituisci il nome del database tra virgolette con `Database`, senza virgolette, in entrambe le righe:

```
Origine = MySQL.Database("localhost", Database),
film = Origine{[Schema=Database, Item="film"]}[Data]
```

3. **Chiudi e applica**. Alla richiesta delle credenziali scegli **Database** e inserisci utente `root` e la password MySQL.

Da qui in poi, per cambiare database basta modificare il valore del parametro `Database`. Le tabelle e le viste hanno gli stessi nomi del database originale, quindi i visual non vanno modificati.

---

## Aggiungere dati a una singola tabella

Dalla cartella `Team_3`, con il `.venv` attivo:

```
cd 05_caricamento_python
python carica_dati.py --tabella <nome_tabella> --file <percorso_csv>
```

Valori ammessi per `--tabella`: `film`, `genres`, `generi_film`, `users`, `ratings`. Senza `--file` lo script usa il csv di default in `03_dati_preprocessati/`.

### Come funziona

Il caricamento è un **upsert** (`INSERT ... ON DUPLICATE KEY UPDATE`):

- se la chiave primaria è nuova, la riga viene **inserita**;
- se la chiave esiste già, la riga viene **aggiornata** con i valori del csv;
- se ricarichi lo stesso file, i duplicati non vengono creati.

Prima di scrivere, lo script controlla le foreign key. Se un `MovieID` o uno `UsersID` non esiste nella tabella padre, si ferma e mostra i valori mancanti. Se c'è un errore durante il caricamento, fa il rollback e non salva nessuna riga di quel file.

### Formato del csv

Il csv deve avere un'intestazione con questi nomi di colonna. L'ordine non conta. Una colonna iniziale vuota di indice pandas (`Unnamed: 0`) viene ignorata.

| Tabella       | Colonne richieste                                     | Note                                                                                                            |
| ------------- | ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `film`        | `MovieID,Title,Year`                                  | Titolo senza anno; anno in colonna a parte                                                                      |
| `genres`      | `generi_id,Genres`                                    | Il nome del genere deve essere univoco                                                                          |
| `generi_film` | `MovieID,generi_id`                                   | Un genere per riga, con l'id preso da`genres`                                                                   |
| `users`       | `UserID` (o `UsersID`)`,Gender,Age,CAP,Work,AgeGroup` | Gender`M`/`F`; AgeGroup tra `U18`, `18-24`, `25-34`, `35-44`, `45-54`, `55+`; il CAP viene completato a 5 cifre |
| `ratings`     | `UserID` (o `UsersID`)`,MovieID,Rating,Timestamp`     | Rating da 1 a 5; Timestamp`AAAA-MM-GG hh:mm:ss`, non Unix time                                                  |

Il modo più semplice per ottenere un csv corretto è far passare i nuovi dati grezzi dagli stessi notebook di `02_preprocessing/`. Basta cambiare i percorsi di input e di output.

### Ordine da rispettare

Le tabelle padre vanno caricate prima delle associative:

- **nuovo film con i suoi generi**: prima `film`, poi (se il genere è nuovo) `genres`, infine `generi_film`;
- **nuovi voti di un utente nuovo**: prima `users`, poi `ratings`;
- **nuovi voti di utenti e film già presenti**: basta `ratings`.

### Esempi

```
# nuovi utenti
python carica_dati.py --tabella users --file C:\percorso\nuovi_utenti.csv

# nuovi voti
python carica_dati.py --tabella ratings --file C:\percorso\nuovi_voti.csv

# ricaricare solo film dal csv di default
python carica_dati.py --tabella film
```

### Verifica in Workbench

```sql
USE onthemovie_2;
SELECT 'film' AS tabella, COUNT(*) AS righe FROM film
UNION ALL SELECT 'genres',      COUNT(*) FROM genres
UNION ALL SELECT 'generi_film', COUNT(*) FROM generi_film
UNION ALL SELECT 'users',       COUNT(*) FROM users
UNION ALL SELECT 'ratings',     COUNT(*) FROM ratings;

-- le viste riflettono subito i nuovi dati
SELECT * FROM v_iscritti_provincia ORDER BY n_iscritti DESC LIMIT 20;
SELECT * FROM v_film_da_eliminare;
```

Dopo aver aggiunto dati, in Power BI basta premere **Aggiorna** per vederli nella dashboard.
