#!/usr/bin/env python3
"""RA-BE-146: which migrations an older release cannot live with.

Usage: migration-breaks-older-code.py <name>=<migration.sql> ...

Prints one line `<name>: <why>` for every migration whose SQL removes or
tightens something an older release's code still reads or writes: a dropped
column, table or type, a rename, a changed column type, a NOT NULL set or
dropped on an existing column, a column added NOT NULL with no default, or a
value added to an enum (older code fails on a row that holds it). Exits 0 when none does, 1
when at least one does. A migration that only adds nullable or defaulted
columns, tables and indexes is not listed.
"""
import re
import sys

CHECKS = [
    (r"\bDROP\s+COLUMN\b", "drops a column an older release still reads"),
    (r"\bDROP\s+TABLE\b", "drops a table an older release still reads"),
    (r"\bDROP\s+TYPE\b", "drops a type an older release still uses"),
    (r"\bRENAME\b", "renames something an older release reads by name"),
    (r"\bALTER\s+COLUMN\b[^;]*\bTYPE\b", "changes a column's type"),
    (r"\bALTER\s+COLUMN\b[^;]*\bSET\s+NOT\s+NULL\b", "sets NOT NULL on a column an older release may leave empty"),
    (r"\bALTER\s+COLUMN\b[^;]*\bDROP\s+NOT\s+NULL\b", "lets a column an older release reads as always set be empty"),
    (r"\bADD\s+VALUE\b", "adds an enum value an older release cannot read"),
]


def statements(sql):
    sql = re.sub(r"--[^\n]*", "", sql)
    sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.S)
    return [part.strip() for part in sql.split(";") if part.strip()]


def reasons(sql):
    found = []
    for statement in statements(sql):
        for pattern, why in CHECKS:
            if re.search(pattern, statement, re.I | re.S) and why not in found:
                found.append(why)
        for column in re.finditer(r"\bADD\s+COLUMN\b([^,;]*)", statement, re.I):
            clause = column.group(1)
            if re.search(r"\bNOT\s+NULL\b", clause, re.I) and not re.search(r"\bDEFAULT\b", clause, re.I):
                why = "adds a NOT NULL column with no default, so an older release cannot insert"
                if why not in found:
                    found.append(why)
    return found


def main(arguments):
    broken = False
    for argument in arguments:
        name, _, path = argument.partition("=")
        with open(path, encoding="utf-8") as handle:
            for why in reasons(handle.read()):
                print(f"{name}: {why}")
                broken = True
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
