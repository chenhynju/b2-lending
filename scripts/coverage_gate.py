#!/usr/bin/env python3
import json
from pathlib import Path
d=json.loads((Path(__file__).resolve().parents[1]/"evidence/coverage.json").read_text())
assert d["status"]=="PASS","Whole-file 90% branch coverage gate FAIL; see raw constructor-revert accounting gap."
print("PASS whole-file branch gate")
