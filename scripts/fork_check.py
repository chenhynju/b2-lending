#!/usr/bin/env python3
"""Isolate fork pin adaptation from a running frozen local fuzz campaign."""
import json,os,shutil,subprocess,tempfile,urllib.request
from pathlib import Path
root=Path(__file__).resolve().parents[1];e=root/"evidence"
rpc=os.environ["MAINNET_RPC_URL"]
def request(method,params):
    req=urllib.request.Request(rpc,json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params}).encode(),{"Content-Type":"application/json"})
    with urllib.request.urlopen(req,timeout=45) as r:return json.load(r)["result"]
head=int(request("eth_blockNumber",[]),16);pin=head-64
block=request("eth_getBlockByNumber",[hex(pin),False])
with tempfile.TemporaryDirectory(prefix="b2-lending-fork-") as temp:
    p=Path(temp)
    for folder in ["src","test"]:shutil.copytree(root/folder,p/folder)
    (p/"lib").symlink_to(root/"lib",target_is_directory=True);shutil.copy(root/"foundry.toml",p/"foundry.toml")
    path=p/"test/fork/MainnetFork.t.sol";path.write_text(path.read_text().replace("21_000_000",str(pin)))
    os.environ["MAINNET_FORK_BLOCK"]=str(pin)
    with (e/"mainnet-fork-final.txt").open("w") as log:
        result=subprocess.run(["forge","test","--match-contract","MainnetForkTest","-vvvv"],cwd=p,stdout=log,stderr=subprocess.STDOUT)
    report={"status":"PASS" if result.returncode==0 else "FAIL","exitCode":result.returncode,"block":pin,"blockHash":block["hash"],"blockTimestamp":int(block["timestamp"],16),"upstream":"https://ethereum-rpc.publicnode.com","transport":"local read-only Windows bridge; no signed transaction","synthetic":"deal() provisions USDT and WETH balances; mainnet contracts/feed state are real","log":"mainnet-fork-final.txt"}
    (e/"mainnet-fork.json").write_text(json.dumps(report,indent=2));print(json.dumps(report),flush=True)
    raise SystemExit(result.returncode)
