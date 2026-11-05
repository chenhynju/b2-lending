#!/usr/bin/env python3
"""Fresh offline clone, content-lock verification, compilation/tests and fixed-seed gas gate."""
import hashlib,json,os,subprocess,tempfile
from pathlib import Path
r=Path(__file__).resolve().parents[1];e=r/"evidence"
bundleDir=tempfile.TemporaryDirectory(prefix="b2-lending-review-bundle-");bundle=Path(bundleDir.name)/"review.bundle"
os.environ["PATH"]=str(Path.home()/".foundry/bin")+":"+os.environ["PATH"]
commit=subprocess.check_output(["git","rev-parse","HEAD"],cwd=r,text=True).strip()
subprocess.run(["git","bundle","create",str(bundle),"--all"],cwd=r,check=True)
report={"testedCommit":commit,"bundle":bundle.name,"commands":[],"sourceCommit":(e/"audited-source.sha").read_text().strip()}
with tempfile.TemporaryDirectory(prefix="b2-lending-fresh-clone-") as temp:
    p=Path(temp)/"checkout"
    subprocess.run(["git","clone","--quiet","-c","core.autocrlf=false",str(bundle),str(p)],check=True)
    commands=[["python3","scripts/dependencies.py"],["python3","scripts/reference_model.py"],["forge","test","--fuzz-seed","0x20261105","-vv"],["forge","snapshot","--match-contract","LendingVaultTest","--fuzz-seed","0x20261105","--check"]]
    with (e/"fresh-clone.txt").open("w") as log:
        for command in commands:
            log.write("$ "+" ".join(command)+"\n");log.flush()
            result=subprocess.run(command,cwd=p,stdout=log,stderr=subprocess.STDOUT)
            report["commands"].append({"command":command,"exitCode":result.returncode})
            if result.returncode:break
    expected=json.loads((r/"evidence/reviewed-file-hashes.json").read_text())
    report["reviewedFilesMatch"]=all(hashlib.sha256((p/file).read_bytes()).hexdigest()==digest for file,digest in expected.items())
    report["sourceManifest"]=json.loads((r/"scripts/static-review.lock.json").read_text())
    report["status"]="PASS" if len(report["commands"])==len(commands) and all(x["exitCode"]==0 for x in report["commands"]) and report["reviewedFilesMatch"] else "FAIL"
(e/"fresh-clone.json").write_text(json.dumps(report,indent=2));print(json.dumps(report),flush=True)
raise SystemExit(0 if report["status"]=="PASS" else 1)
