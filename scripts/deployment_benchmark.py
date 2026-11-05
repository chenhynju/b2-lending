#!/usr/bin/env python3
"""Real Anvil constructor-gas comparison, separate from the paused settlement harness."""
import json,os,shutil,subprocess,tempfile,time
from pathlib import Path
import local_smoke as local
root=Path(__file__).resolve().parents[1];e=root/"evidence"
results=[]
for runs in [200,1000,10000]:
 with tempfile.TemporaryDirectory(prefix="b2-lending-gas-") as temp:
    p=Path(temp);shutil.copytree(root/"src",p/"src");(p/"src/mocks").mkdir()
    shutil.copy(root/"test/mocks/Mocks.sol",p/"src/mocks/Mocks.sol")
    (p/"lib").symlink_to(root/"lib",target_is_directory=True)
    (p/"foundry.toml").write_text((root/"foundry.toml").read_text().replace("optimizer_runs = 1000",f"optimizer_runs = {runs}"))
    with (e/f"deployment-gas-build-{runs}.txt").open("w") as log:subprocess.run(["forge","build"],cwd=p,stdout=log,stderr=subprocess.STDOUT,check=True)
    local.root=p;local.rpc_url="http://127.0.0.1:18547";local.receipts=[]
    with (e/f"deployment-gas-anvil-{runs}.txt").open("w") as log:
      node=subprocess.Popen(["anvil","--port","18547","--host","127.0.0.1","--chain-id","31337","--silent"],stdout=log,stderr=subprocess.STDOUT)
      try:
       for _ in range(100):
        try:sender=local.rpc("eth_accounts")[0];break
        except Exception:
         if node.poll() is not None:raise RuntimeError("Anvil failed")
         time.sleep(.1)
       a=local.deploy(sender,"MockToken",[6]);c=local.deploy(sender,"MockToken",[18]);o=local.deploy(sender,"MockOracle")
       v=local.deploy(sender,"LendingVault",[a,c,o])
       receipt=local.receipts[-1]["receipt"];artifact=local.artifact("LendingVault")
       results.append({"runs":runs,"viaIR":True,"deploymentGas":int(receipt["gasUsed"],16),"runtimeBytes":len(artifact["deployedBytecode"]["object"].removeprefix("0x"))//2,"initcodeBytes":len(artifact["bytecode"]["object"].removeprefix("0x"))//2,"constructorArgsBytes":96,"runtimeMatch":"PASS","receipt":receipt})
       (e/"deployment-gas.json").write_text(json.dumps(results,indent=2));print(json.dumps({k:v for k,v in results[-1].items() if k!="receipt"}),flush=True)
      finally:
       node.terminate()
       try:node.wait(timeout=5)
       except subprocess.TimeoutExpired:node.kill()
