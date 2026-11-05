#!/usr/bin/env python3
"""Fail on unreviewed detector families or runtime reentrancy reports."""
import json,hashlib
from pathlib import Path
r=Path(__file__).resolve().parents[1];e=r/"evidence"
lock=json.loads((r/"scripts/static-review.lock.json").read_text())
for file,digest in lock.items():assert hashlib.sha256((r/file).read_bytes()).hexdigest()==digest,"Source changed: refresh manual triage"
s=json.loads((e/"slither-final.json").read_text());assert s.get("success"),"Slither did not complete"
assert set(x["check"] for x in s["results"].get("detectors",[])) <= {"incorrect-equality","timestamp","unused-return","reentrancy-balance"},"Unreviewed Slither detector"
a=json.loads((e/"aderyn-final.json").read_text())
allowed={"literal-instead-of-constant","unused-public-function","reentrancy-state-change","eth-send-unchecked-address"}
for section in ["high_issues","low_issues"]:
 for issue in a.get(section,{}).get("issues",[]):
    assert issue["detector_name"] in allowed,"Unreviewed Aderyn detector"
    if issue["detector_name"]=="eth-send-unchecked-address":
     assert all(x["contract_path"]=="src/LendingVault.sol" for x in issue["instances"])
     assert not any(x.get("stateMutability") == "payable" for x in json.loads((r/"out/LendingVault.sol/LendingVault.json").read_text())["abi"])
     assert "functionCallWithValue(target, data, 0)" in (r/"lib/openzeppelin-contracts/contracts/utils/Address.sol").read_text()
    if issue["detector_name"]=="reentrancy-state-change":
     for instance in issue["instances"]:
        lines=(r/instance["contract_path"]).read_text().splitlines()
        line=instance["line_no"]
        before="\n".join(lines[:line])
        assert "constructor(" in before and "function " not in before.split("constructor(",1)[1],"Runtime reentrancy report"
(e/"static-gate.json").write_text(json.dumps({"status":"PASS","classification":"reviewed warning families; raw findings retained; no independent assurance"},indent=2))
print("PASS reviewed static-warning gate")
