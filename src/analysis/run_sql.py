import sys
from pathlib import Path

import duckdb

PROJECT_ROOT = Path(__file__).resolve().parents[2]

con = duckdb.connect()  # βάση στη μνήμη, δεν γράφει τίποτα στον δίσκο
try:
    con.execute("INSTALL spatial")
    con.execute("LOAD spatial")
except Exception as exc:
    print(f"[προειδοποίηση] δεν φορτώθηκε το spatial: {exc}")
con.execute("SET memory_limit = '2GB'")
con.execute(f"SET temp_directory = '{(PROJECT_ROOT / 'data' / 'duckdb_tmp').as_posix()}'")

sql_text = Path(sys.argv[1]).read_text(encoding="utf-8")

for statement in sql_text.split(";"):
    meaningful = [
        line for line in statement.splitlines()
        if line.strip() and not line.strip().startswith("--")
    ]
    if not meaningful:
        continue  # κομμάτι που έχει μόνο σχόλια ή κενά
    print("=" * 80)
    print(statement.strip())
    print("-" * 80)
    print(con.execute(statement).df().to_string(index=False))
    print()