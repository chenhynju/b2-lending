#!/usr/bin/env python3
"""Query OSV for the exact Solidity-library and browser-test package versions."""
import argparse,json,urllib.request
from pathlib import Path
r=Path(__file__).resolve().parents[1];e=r/"evidence"
p=argparse.ArgumentParser();p.add_argument("--from-file");a=p.parse_args()
if a.from_file:
    d=json.loads(Path(a.from_file).read_text(encoding="utf-8-sig"))
else:
    lock=json.loads((r/"package-lock.json").read_text())
    oz=json.loads((r/"dependencies.lock.json").read_text())["openzeppelin-contracts"]["version"]
    queries=[{"package":{"name":"@openzeppelin/contracts","ecosystem":"npm"},"version":oz}]
    for name in ["@playwright/test","playwright","playwright-core","fsevents"]:
        entry=lock["packages"].get("node_modules/"+name)
        if entry:queries.append({"package":{"name":name,"ecosystem":"npm"},"version":entry["version"]})
    req=urllib.request.Request("https://api.osv.dev/v1/querybatch",json.dumps({"queries":queries}).encode(),{"Content-Type":"application/json","User-Agent":"B2-Lending-Review"})
    with urllib.request.urlopen(req,timeout=40) as response:result=json.load(response)
    d={"queries":queries,"response":result,"endpoint":"https://api.osv.dev/v1/querybatch"}
assert len(d["queries"])==len(d["response"]["results"])
d["status"]="FAIL" if any(x.get("vulns") for x in d["response"]["results"]) else "PASS"
d["limitations"]="Registry advisory snapshot, not a proof of no vulnerabilities or a Solidity audit."
e.mkdir(exist_ok=True);(e/"dependency-audit.json").write_text(json.dumps(d,indent=2))
print(json.dumps({"status":d["status"],"packages":len(d["queries"])}))
raise SystemExit(0 if d["status"]=="PASS" else 1)
