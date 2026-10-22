"""
Parametri di connessione a MySQL.

Si possono cambiare qui oppure tramite variabili d'ambiente
(MYSQL_HOST, MYSQL_PORT, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE).
Se MYSQL_PASSWORD non è impostata, la password viene chiesta a terminale.
"""
import os
from getpass import getpass
from pathlib import Path

DB_CONFIG = {
    "host":     os.getenv("MYSQL_HOST", "localhost"),
    "port":     int(os.getenv("MYSQL_PORT", "3306")),
    "user":     os.getenv("MYSQL_USER", "root"),
    "database": os.getenv("MYSQL_DATABASE", "onthemovie_2"),
}


def get_password():
    return os.getenv("MYSQL_PASSWORD") or getpass(f"Password MySQL per {DB_CONFIG['user']}: ")


# cartella con i csv preprocessati (03_dati_preprocessati)
DATA_DIR = Path(__file__).resolve().parent.parent / "03_dati_preprocessati"

# righe inviate a MySQL per ogni executemany (ratings ha ~1 milione di righe)
BATCH_SIZE = 10_000
