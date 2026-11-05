#!/usr/bin/env python3
"""Isolated checks never clean or mutate campaign build products."""
import argparse,hashlib,json,os,shutil,subprocess,tempfile
from pathlib import Path
root=Path(__file__).resolve().parents[1];e=root/"evidence"
def workspace(tests=True):
    td=tempfile.TemporaryDirectory(prefix="b2-lending-check-");p=Path(td.name)
    for name in ["src"]+(["test"] if tests else []):shutil.copytree(root/name,p/name)
    (p/"lib").symlink_to(root/"lib",target_is_directory=True)
    shutil.copy(root/"foundry.toml",p/"foundry.toml")
    return td,p
def run(cmd,p,log):
    with (e/log).open("w") as f:return subprocess.run(cmd,cwd=p,stdout=f,stderr=subprocess.STDOUT).returncode
def static():
    td,p=workspace(False)
    results={}
    for tool,cmd in {
        "slither":["slither",".","--filter-paths","lib/","--json",str(e/"slither-final.json")],
        "aderyn":["aderyn",".","-o",str(e/"aderyn-final.json")]
    }.items():results[tool]={"exitCode":run(cmd,p,tool+"-final.log"),"reportExists":(e/(tool+"-final.json")).exists()}
    (e/"static-execution.json").write_text(json.dumps(results,indent=2))
    print(json.dumps(results));td.cleanup()
def coverage():
    td,p=workspace()
    if (root/"audit-tests").exists():shutil.copytree(root/"audit-tests",p/"test",dirs_exist_ok=True)
    cmd=["forge","coverage","--ir-minimum","--no-match-contract","LendingInvariant|MainnetForkTest","--fuzz-runs","256","--report","summary","--report","lcov"]
    result=run(cmd,p,"coverage.txt")
    if (p/"lcov.info").exists():shutil.copy(p/"lcov.info",e/"lcov.info")
    metrics={}
    if (e/"lcov.info").exists():
        for rec in (e/"lcov.info").read_text().split("end_of_record"):
            fields={}
            for line in rec.splitlines():
                k,_,v=line.partition(":")
                if k in ["SF","LF","LH","BRF","BRH","FNF","FNH"]:fields[k]=v
            if fields.get("SF","").startswith("src/"):metrics[fields["SF"]]=fields
    status="PASS" if result==0 and all(int(v.get("BRF",0))==0 or int(v["BRH"])/int(v["BRF"])>=.9 for v in metrics.values()) and metrics else "FAIL"
    (e/"coverage.json").write_text(json.dumps({"status":status,"command":cmd,"exitCode":result,"files":metrics},indent=2))
    print(json.dumps({"coverage":status,"metrics":metrics}));td.cleanup()
def matrix():
    report=[]
    for ir in [True,False]:
        for runs in [200,1000,10000]:
            td,p=workspace()
            config=(p/"foundry.toml").read_text().replace("optimizer_runs = 1000",f"optimizer_runs = {runs}").replace("via_ir = true",f"via_ir = {str(ir).lower()}")
            (p/"foundry.toml").write_text(config)
            cmd=["forge","test","--no-match-contract","LendingInvariant|MainnetForkTest","--fuzz-runs","32","--gas-report"]
            name=f"optimizer-{runs}-ir-{str(ir).lower()}.txt"
            code=run(cmd,p,name);row={"runs":runs,"viaIR":ir,"exitCode":code,"log":name,"command":cmd}
            artifact=p/"out/LendingVault.sol/LendingVault.json"
            if artifact.exists():
                a=json.loads(artifact.read_text());row.update(runtimeBytes=len(a["deployedBytecode"]["object"].removeprefix("0x"))//2,initcodeBytes=len(a["bytecode"]["object"].removeprefix("0x"))//2)
            report.append(row);(e/"optimizer-matrix.json").write_text(json.dumps(report,indent=2))
            print(json.dumps(row),flush=True);td.cleanup()
def mutation():
    original=(root/"src/LendingVault.sol").read_text()
    cases=[
      ("last-share","LendingVault.sol","if (shares == totalSupply() && assets != cash + _debtAt(borrowIndex)) revert InvalidAmount();","","testRegression_LastShareCannotOrphanReceivables"),
      ("repay-rounding","LendingVault.sol","assets = Math.mulDiv(shares, borrowIndex, RAY, Math.Rounding.Ceil);","assets = Math.mulDiv(shares, borrowIndex, RAY, Math.Rounding.Floor);","testPartialRepaymentRoundsUp"),
      ("borrow-rounding","LendingVault.sol","shares = Math.mulDiv(assets, RAY, borrowIndex, Math.Rounding.Ceil);","shares = Math.mulDiv(assets, RAY, borrowIndex, Math.Rounding.Floor);","testFuzz_BorrowRepayRounding"),
      ("stale-price","FeedOracle.sol","|| block.timestamp - updated > maxAge","|| false","testStaleFeedAndExactBoundary")
    ]
    report=[]
    for label,file,old,new,test in cases:
        td,p=workspace();source=p/"src"/file;s=source.read_text()
        assert old in s,label;source.write_text(s.replace(old,new,1))
        code=run(["forge","test","--match-test",test,"--fuzz-seed","0x20261105","-vv"],p,"mutation-"+label+".txt")
        log=(e/("mutation-"+label+".txt")).read_text()
        killed=code!=0 and "[FAIL" in log and "Compiler run successful" in log
        report.append({"mutation":label,"test":test,"status":"KILLED" if killed else "SURVIVED_OR_ERROR","exitCode":code})
        print(json.dumps(report[-1]),flush=True);td.cleanup()
    (e/"mutation.json").write_text(json.dumps(report,indent=2))
def reproducible():
    outputs=[]
    for i in range(2):
        td,p=workspace(False)
        code=run(["forge","build","--force"],p,f"reproducible-{i}.txt")
        assert code==0
        hashes={}
        for f in ["LendingVault","FeedOracle","InterestRateModel"]:
            a=json.loads((p/f"out/{f}.sol/{f}.json").read_text())
            hashes[f]={k:hashlib.sha256(a[k]["object"].encode()).hexdigest() for k in ["bytecode","deployedBytecode"]}
        outputs.append(hashes);td.cleanup()
    assert outputs[0]==outputs[1]
    (e/"reproducible.json").write_text(json.dumps({"status":"PASS","builds":outputs,"note":"SHA256 of creation/runtime hex objects including zeroed immutable placeholders; constructor arguments are separate."},indent=2))
if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("kind",choices=["static","coverage","matrix","mutation","reproducible"]);a=p.parse_args()
    globals()[a.kind]()
