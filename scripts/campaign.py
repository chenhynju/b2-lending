#!/usr/bin/env python3
"""At least 30 minutes of changing-seed fuzz and stateful invariant verification."""
import hashlib,json,os,subprocess,time
from pathlib import Path
root=Path(__file__).resolve().parents[1]
os.chdir(root)
e=root/"evidence";e.mkdir(exist_ok=True)
def fingerprint():
    paths=sorted(list((root/"src").rglob("*.sol"))+list((root/"test").rglob("*.*"))+[root/"foundry.toml",root/"dependencies.lock.json"])
    return hashlib.sha256(b"".join(str(p.relative_to(root)).encode()+p.read_bytes() for p in paths)).hexdigest()
subprocess.run(["forge","build"],check=True,stdout=(e/"campaign-build.txt").open("w"),stderr=subprocess.STDOUT)
freeze=fingerprint();started=time.monotonic()
report={"status":"RUNNING","secondsRequired":1800,"fingerprint":freeze,"startedUTC":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime()),"rounds":[]}
while time.monotonic()-started<1800:
    if fingerprint()!=freeze:raise SystemExit("Frozen contracts/tests/config changed")
    i=len(report["rounds"]);seed=hex(202611050000+i)
    command=["forge","test","--no-match-contract","MainnetForkTest","--fuzz-seed",seed,"-vv"]
    before=time.monotonic()
    with (e/f"campaign-{i:03}.txt").open("w") as log:
        p=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT)
    report["rounds"].append({"seed":seed,"command":command,"exitCode":p.returncode,"seconds":time.monotonic()-before,"log":f"campaign-{i:03}.txt"})
    report["seconds"]=time.monotonic()-started
    if p.returncode:report["status"]="FAIL"
    (e/"campaign.json").write_text(json.dumps(report,indent=2))
    print(json.dumps({"round":i,"seconds":report["seconds"],"exitCode":p.returncode}),flush=True)
    if p.returncode:raise SystemExit(p.returncode)
report["status"]="PASS";report["seconds"]=time.monotonic()-started
report["endedUTC"]=time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime())
(e/"campaign.json").write_text(json.dumps(report,indent=2))
print("PASS 30-minute campaign",flush=True)
