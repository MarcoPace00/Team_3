"""
Carica i csv preprocessati nelle tabelle (già esistenti) del database onthemovie_2.

Uso:
    python carica_dati.py                                    # tutte le tabelle, in ordine di FK
    python carica_dati.py --tabella users                    # una sola tabella, csv di default
    python carica_dati.py --tabella ratings --file nuovi.csv # una tabella da un csv a scelta

Il caricamento è un "upsert" (INSERT ... ON DUPLICATE KEY UPDATE):
    - righe con chiave nuova      -> inserite
    - righe con chiave già presente -> aggiornate con i valori del csv
quindi lo script si può rilanciare senza creare duplicati.
"""
import argparse
import sys
from pathlib import Path

import mysql.connector
import pandas as pd

from config import BATCH_SIZE, DATA_DIR, DB_CONFIG, get_password

# Ordine di caricamento: le tabelle "padre" prima delle associative (vincoli di foreign key).
#   csv:     file di default in 03_dati_preprocessati
#   rinomina: colonne del csv -> colonne della tabella
#   colonne: colonne della tabella, nell'ordine dell'INSERT
#   chiave:  primary key (non viene aggiornata dall'upsert)
#   fk:      colonna -> (tabella padre, colonna padre), controllate prima di caricare
TABELLE = {
    "film": {
        "csv": "film.csv",
        "rinomina": {},
        "colonne": ["MovieID", "Title", "Year"],
        "chiave": ["MovieID"],
        "fk": {},
    },
    "genres": {
        "csv": "genres.csv",
        "rinomina": {},
        "colonne": ["generi_id", "Genres"],
        "chiave": ["generi_id"],
        "fk": {},
    },
    "generi_film": {
        "csv": "generi_film.csv",
        "rinomina": {},
        "colonne": ["MovieID", "generi_id"],
        "chiave": ["MovieID", "generi_id"],
        "fk": {"MovieID": ("film", "MovieID"), "generi_id": ("genres", "generi_id")},
    },
    "users": {
        "csv": "users_checked.csv",
        "rinomina": {"UserID": "UsersID"},
        "colonne": ["UsersID", "Gender", "Age", "CAP", "Work", "AgeGroup"],
        "chiave": ["UsersID"],
        "fk": {},
    },
    "ratings": {
        "csv": "ratings_checked.csv",
        "rinomina": {"UserID": "UsersID"},
        "colonne": ["UsersID", "MovieID", "Rating", "Timestamp"],
        "chiave": ["UsersID", "MovieID"],
        "fk": {"UsersID": ("users", "UsersID"), "MovieID": ("film", "MovieID")},
    },
}


def leggi_csv(tabella, percorso):
    spec = TABELLE[tabella]
    # tutto come testo: così il CAP non perde gli zeri e MySQL converte i numeri da solo
    df = pd.read_csv(percorso, dtype=str)

    # i csv salvati con pandas senza index=False hanno una prima colonna "Unnamed: 0" da scartare
    df = df.loc[:, ~df.columns.str.startswith("Unnamed")]
    df = df.rename(columns=spec["rinomina"])

    mancanti = [c for c in spec["colonne"] if c not in df.columns]
    if mancanti:
        sys.exit(f"[{tabella}] colonne mancanti nel csv {percorso.name}: {mancanti}")
    df = df[spec["colonne"]]

    if tabella == "users":
        # CAP letto da pandas come numero perde gli zeri iniziali (01010 -> 1010)
        df["CAP"] = df["CAP"].str.zfill(5)

    # celle vuote -> NULL
    return df.astype(object).where(df.notna(), None)


def controlla_fk(cursor, tabella, df):
    for colonna, (padre, col_padre) in TABELLE[tabella]["fk"].items():
        cursor.execute(f"SELECT {col_padre} FROM {padre}")
        esistenti = {str(r[0]) for r in cursor.fetchall()}
        orfani = set(df[colonna]) - esistenti
        if orfani:
            esempio = sorted(orfani)[:10]
            sys.exit(
                f"[{tabella}] {len(orfani)} valori di {colonna} non esistono in {padre}.{col_padre} "
                f"(es. {esempio}). Caricare prima {padre}."
            )


def conta(cursor, tabella):
    cursor.execute(f"SELECT COUNT(*) FROM {tabella}")
    return cursor.fetchone()[0]


def carica(conn, tabella, percorso):
    spec = TABELLE[tabella]
    df = leggi_csv(tabella, percorso)
    cursor = conn.cursor()
    controlla_fk(cursor, tabella, df)

    colonne = spec["colonne"]
    da_aggiornare = [c for c in colonne if c not in spec["chiave"]] or spec["chiave"][:1]
    sql = (
        f"INSERT INTO {tabella} ({', '.join(colonne)}) "
        f"VALUES ({', '.join(['%s'] * len(colonne))}) "
        f"ON DUPLICATE KEY UPDATE {', '.join(f'{c} = VALUES({c})' for c in da_aggiornare)}"
    )

    prima = conta(cursor, tabella)
    righe = list(df.itertuples(index=False, name=None))
    try:
        for i in range(0, len(righe), BATCH_SIZE):
            cursor.executemany(sql, righe[i:i + BATCH_SIZE])
            print(f"\r[{tabella}] {min(i + BATCH_SIZE, len(righe)):,}/{len(righe):,} righe inviate", end="")
        conn.commit()
    except mysql.connector.Error as e:
        conn.rollback()
        sys.exit(f"\n[{tabella}] errore, nessuna riga salvata (rollback): {e}")
    dopo = conta(cursor, tabella)
    cursor.close()
    print(f"\n[{tabella}] {percorso.name}: {len(righe):,} righe nel csv, "
          f"{dopo - prima:,} nuove, totale in tabella {dopo:,}")


def main():
    parser = argparse.ArgumentParser(description="Carica i csv preprocessati in onthemovie_2")
    parser.add_argument("--tabella", choices=TABELLE, help="carica solo questa tabella (default: tutte)")
    parser.add_argument("--file", type=Path, help="csv da caricare (solo con --tabella; default: csv in 03_dati_preprocessati)")
    args = parser.parse_args()

    if args.file and not args.tabella:
        parser.error("--file richiede --tabella")

    tabelle = [args.tabella] if args.tabella else list(TABELLE)

    conn = mysql.connector.connect(**DB_CONFIG, password=get_password())
    try:
        for tabella in tabelle:
            percorso = args.file or DATA_DIR / TABELLE[tabella]["csv"]
            if not percorso.exists():
                sys.exit(f"[{tabella}] file non trovato: {percorso}")
            carica(conn, tabella, percorso)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
