#!/usr/bin/env python3
"""Real unlocked-account Anvil transactions. No private key is read, logged or embedded."""
import argparse,functools,json,os,shutil,subprocess,threading,time,urllib.request
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
root=Path(__file__).resolve().parents[1];e=root/"evidence";rpc_url="http://127.0.0.1:18545"
def rpc(method,params=None):
    body=json.dumps({"jsonrpc":"2.0","id":1,"method":method,"params":params or []}).encode()
    with urllib.request.urlopen(urllib.request.Request(rpc_url,body,{"Content-Type":"application/json"}),timeout=20) as r:d=json.load(r)
    if "error" in d:raise RuntimeError(str(d["error"]))
    return d["result"]
def artifact(name):
    file="Mocks" if name in ["MockToken","MockOracle"] else name
    return json.loads((root/f"out/{file}.sol/{name}.json").read_text())
def words(values):return "".join(f"{int(v,16) if isinstance(v,str) and v.startswith('0x') else int(v):064x}" for v in values)
receipts=[]
def send(sender,to,data,label):
    tx={"from":sender,"data":data,"gas":"0x1c9c380"}
    if to:tx["to"]=to
    h=rpc("eth_sendTransaction",[tx])
    for _ in range(100):
        receipt=rpc("eth_getTransactionReceipt",[h])
        if receipt:break
        time.sleep(.1)
    else:raise RuntimeError("Receipt timeout")
    assert int(receipt["status"],16)==1,label
    receipts.append({"label":label,"receipt":receipt});return receipt
def event_words(receipt,address,signature):
    topic=subprocess.check_output(["cast","keccak",signature],text=True).strip().lower()
    logs=[x for x in receipt["logs"] if x["address"].lower()==address.lower() and x["topics"][0].lower()==topic]
    assert len(logs)==1,signature
    data=logs[0]["data"][2:]
    return [int(data[i:i+64],16) for i in range(0,len(data),64)]
def deploy(sender,name,args=()):
    a=artifact(name);data=a["bytecode"]["object"]
    if not data.startswith("0x"):data="0x"+data
    receipt=send(sender,None,data+words(args),"deploy "+name);address=receipt["contractAddress"]
    actual=rpc("eth_getCode",[address,"latest"])[2:];expected=a["deployedBytecode"]["object"].removeprefix("0x")
    ranges=[x for value in a["deployedBytecode"].get("immutableReferences",{}).values() for x in value]
    for item in ranges:
        start=item["start"]*2;length=item["length"]*2
        actual=actual[:start]+"0"*length+actual[start+length:]
        expected=expected[:start]+"0"*length+expected[start+length:]
    assert actual==expected,name+" runtime mismatch"
    return address
selectors={}
def call(to,signature,args=()):return "0x"+selectors[signature]+words(args)
def read(to,signature,args=()):return int(rpc("eth_call",[{"to":to,"data":call(to,signature,args)},"latest"]),16)
def tx(sender,to,signature,args=()):return send(sender,to,call(to,signature,args),signature)
def main():
    p=argparse.ArgumentParser();p.add_argument("--browser",action="store_true");p.add_argument("--serve",action="store_true");args=p.parse_args()
    os.chdir(root);subprocess.run(["forge","build"],check=True,stdout=(e/"local-build.txt").open("w"),stderr=subprocess.STDOUT)
    log=(e/"anvil-local.txt").open("w")
    node=subprocess.Popen(["anvil","--host","127.0.0.1","--port","18545","--chain-id","31337","--hardfork","cancun","--silent"],stdout=log,stderr=subprocess.STDOUT)
    http=None
    try:
        for _ in range(100):
            try:accounts=rpc("eth_accounts");break
            except Exception:
                if node.poll() is not None:raise RuntimeError("Anvil failed to start; do not reuse an occupied port.")
                time.sleep(.1)
        else:raise RuntimeError("Anvil startup timeout")
        assert rpc("eth_chainId")=="0x7a69"
        for name in ["MockToken","MockOracle","LendingVault","FeedOracle"]:selectors.update(artifact(name)["methodIdentifiers"])
        lender,borrower,liquidator=accounts[:3]
        loan=deploy(lender,"MockToken",[6]);coll=deploy(lender,"MockToken",[18]);oracle=deploy(lender,"MockOracle")
        vault=deploy(lender,"LendingVault",[loan,coll,oracle])
        tx(lender,loan,"mint(address,uint256)",[lender,100000*10**6])
        tx(borrower,coll,"mint(address,uint256)",[borrower,2*10**18])
        tx(lender,loan,"approve(address,uint256)",[vault,2**256-1])
        tx(borrower,coll,"approve(address,uint256)",[vault,2**256-1])
        tx(lender,vault,"deposit(uint256,uint256)",[10000*10**6,0])
        tx(borrower,vault,"addCollateral(uint256)",[10**18]);tx(borrower,vault,"borrow(uint256)",[1000*10**6])
        rpc("evm_increaseTime",[86400]);rpc("evm_mine")
        tx(lender,vault,"accrue()")
        debt=read(vault,"debtOf(address)",[borrower]);assert debt>1000*10**6
        tx(borrower,loan,"mint(address,uint256)",[borrower,debt])
        tx(borrower,loan,"approve(address,uint256)",[vault,2**256-1])
        tx(borrower,vault,"repay(address,uint256,uint256)",[borrower,read(vault,"debtShares(address)",[borrower]),2**256-1])
        tx(borrower,vault,"removeCollateral(uint256)",[10**18])
        tx(lender,vault,"redeem(uint256,uint256)",[read(vault,"balanceOf(address)",[lender]),0])
        assert read(vault,"cash()")==read(vault,"totalSupply()")==read(vault,"totalDebt()")==0
        # Second trace: price gap, funded liquidation and verified socialized loss.
        tx(lender,vault,"deposit(uint256,uint256)",[10000*10**6,0])
        tx(borrower,vault,"addCollateral(uint256)",[10**18]);tx(borrower,vault,"borrow(uint256)",[1000*10**6])
        storedShares=read(vault,"totalDebtShares()");storedIndex=read(vault,"borrowIndex()")
        before=read(vault,"cash()")+(storedShares*storedIndex+10**27-1)//10**27
        tx(lender,oracle,"setPrice(uint256)",[500*10**18])
        tx(liquidator,loan,"mint(address,uint256)",[liquidator,2000*10**6])
        tx(liquidator,loan,"approve(address,uint256)",[vault,2**256-1])
        liquidationReceipt=tx(liquidator,vault,"liquidate(address,uint256,uint256,uint256)",[borrower,2**256-1,2**256-1,0])
        assert read(vault,"debtShares(address)",[borrower])==read(vault,"collateralOf(address)",[borrower])==0
        index,interest=event_words(liquidationReceipt,vault,"Accrue(uint256,uint256)")
        writtenShares,eventLoss=event_words(liquidationReceipt,vault,"BadDebt(address,uint256,uint256)")
        paid,seized=event_words(liquidationReceipt,vault,"Liquidate(address,address,uint256,uint256)")
        ceil=lambda numerator,denominator:(numerator+denominator-1)//denominator
        repaidShares=storedShares-writtenShares
        expectedPaid=ceil(repaidShares*index,10**27)
        debtAfterAccrual=ceil(storedShares*index,10**27)
        debtAfterRepayment=ceil(writtenShares*index,10**27)
        debtReduction=debtAfterAccrual-debtAfterRepayment
        surplus=expectedPaid-debtReduction
        assert paid==expectedPaid and 0<=surplus<=1
        assert interest==debtAfterAccrual-ceil(storedShares*storedIndex,10**27)
        loss=read(vault,"cumulativeBadDebt()")
        assert loss==eventLoss==debtAfterRepayment
        assert seized==10**18
        after=read(vault,"totalAssets()")
        assert before+interest+surplus-after==loss
        accounting={"storedBefore":before,"indexBefore":storedIndex,"indexAfter":index,"debtSharesBefore":storedShares,"repaidShares":repaidShares,"writtenShares":writtenShares,"paid":paid,"interest":interest,"roundingSurplus":surplus,"loss":loss,"assetsAfter":after,"status":"PASS"}
        tx(lender,vault,"redeem(uint256,uint256)",[read(vault,"balanceOf(address)",[lender]),0])
        assert read(vault,"cash()")==0
        # Browser uses unlocked Anvil accounts only; no account secret enters the page.
        tx(lender,oracle,"setPrice(uint256)",[2000*10**18])
        tx(lender,coll,"mint(address,uint256)",[lender,10*10**18])
        tx(lender,loan,"approve(address,uint256)",[vault,0])
        config={"chainId":31337,"vault":vault,"loan":loan,"collateral":coll,"oracle":oracle,"loanDecimals":6,"collateralDecimals":18,"loanSymbol":"mUSD","collateralSymbol":"mETH"}
        web=root/"apps/web";(web/"config.json").write_text(json.dumps(config,indent=2));(web/"selectors.json").write_text(json.dumps(selectors,indent=2))
        report={"status":"PASS","network":"ephemeral Anvil 31337","config":config,"runtimeMatch":"PASS (immutable slots masked)","interestDebt":debt,"realizedBadDebt":loss,"liquidationAccrual":interest,"settlementAccounting":accounting,"transactions":receipts}
        (e/"local-smoke.json").write_text(json.dumps(report,indent=2))
        if args.browser or args.serve:
            handler=functools.partial(SimpleHTTPRequestHandler,directory=str(web))
            http=ThreadingHTTPServer(("127.0.0.1",18080),handler)
            threading.Thread(target=http.serve_forever,daemon=True).start()
        if args.browser:
            env=os.environ.copy();env["ANVIL_ACCOUNT"]=lender;env["BORROWER_ACCOUNT"]=borrower
            subprocess.run(["node","scripts/browser_test.cjs"],env=env,check=True)
        print(json.dumps({"status":"PASS","transactions":len(receipts),"badDebt":loss,"browser":args.browser}),flush=True)
        if args.serve:
            print("Local demo ready: http://127.0.0.1:18080 (Ctrl-C stops)",flush=True)
            while True:time.sleep(1)
    finally:
        if http:http.shutdown()
        node.terminate()
        try:node.wait(timeout=5)
        except subprocess.TimeoutExpired:node.kill()
        log.close()
if __name__=="__main__":main()
