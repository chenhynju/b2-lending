#!/usr/bin/env python3
"""Unsigned demo simulation on a private Anvil using the Base Sepolia chain ID."""
import hashlib,json,os,subprocess,tempfile,time
from pathlib import Path
import local_smoke as rpc

root=Path(__file__).resolve().parents[1]
evidence=root/"evidence"
rpc.rpc_url="http://127.0.0.1:18549"
with tempfile.TemporaryDirectory(prefix="b2-base-demo-dry-run-") as temp:
    log=evidence/"base-sepolia-demo-dry-run.txt"
    with (evidence/"base-sepolia-demo-anvil.txt").open("w") as node_log:
        node=subprocess.Popen(["anvil","--host","127.0.0.1","--port","18549","--chain-id","84532","--silent"],stdout=node_log,stderr=subprocess.STDOUT)
        try:
            for _ in range(100):
                if node.poll() is not None:
                    raise RuntimeError("Private Anvil could not start; do not reuse an occupied port")
                try:
                    sender=rpc.rpc("eth_accounts")[0]
                    break
                except Exception:
                    time.sleep(.1)
            else:
                raise RuntimeError("Private Anvil startup timeout")
            assert int(rpc.rpc("eth_chainId"),16)==84532
            nonce_before=int(rpc.rpc("eth_getTransactionCount",[sender,"latest"]),16)
            env=os.environ.copy()
            env["FOUNDRY_BROADCAST"]=str(Path(temp)/"broadcast")
            cmd=["forge","script","script/DeployBaseSepoliaDemo.s.sol:DeployBaseSepoliaDemo","--sig","run(address)",sender,"--sender",sender,"--rpc-url",rpc.rpc_url]
            with log.open("w") as f:
                subprocess.run(cmd,env=env,cwd=root,stdout=f,stderr=subprocess.STDOUT,check=True)
            assert int(rpc.rpc("eth_getTransactionCount",[sender,"latest"]),16)==nonce_before,"Unexpected broadcast"
            result=Path(temp)/"broadcast/DeployBaseSepoliaDemo.s.sol/84532/dry-run/run-latest.json"
            data=json.loads(result.read_text())
            assert len(data["transactions"])==4 and not data.get("receipts")
            roles=["loan token","collateral token","controlled test quote","lending vault"]
            rows=[]
            for role,item in zip(roles,data["transactions"],strict=True):
                tx=item["transaction"]
                assert item["transactionType"]=="CREATE"
                calldata=tx["input"]
                rows.append({"role":role,"inputBytes":len(calldata.removeprefix("0x"))//2,"inputSha256":hashlib.sha256(bytes.fromhex(calldata.removeprefix("0x"))).hexdigest(),"simulatedGasLimit":int(tx["gas"],16) if tx.get("gas") else None})
            proof={"status":"PASS","scope":"private Anvil with chain ID 84532; no public RPC or public transaction","chainId":84532,"signed":False,"broadcast":False,"transactionCount":4,"transactions":rows,"log":log.name}
            (evidence/"base-sepolia-demo-dry-run.json").write_text(json.dumps(proof,indent=2))
            print(json.dumps(proof))
        finally:
            node.terminate()
            try:
                node.wait(timeout=5)
            except subprocess.TimeoutExpired:
                node.kill()
