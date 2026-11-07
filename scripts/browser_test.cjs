const {chromium,expect}=require('@playwright/test');
const fs=require('fs');
const confirmations=[];
(async()=>{
 const browser=await chromium.launch({headless:true});
 const context=await browser.newContext({viewport:{width:1280,height:1000}});
 const page=await context.newPage();const errors=[];const walletTransactions=[];
 await page.exposeFunction('captureWalletTx',async hash=>{
   const rpc=async(method,params)=>fetch('http://127.0.0.1:18545',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:1,method,params})}).then(r=>r.json());
   const receipt=(await rpc('eth_getTransactionReceipt',[hash])).result;
   const transaction=(await rpc('eth_getTransactionByHash',[hash])).result;
   const item={hash,receipt,transaction};
   if(receipt&&BigInt(receipt.status)===0n)item.trace=await rpc('debug_traceTransaction',[hash,{tracer:'callTracer'}]);
   walletTransactions.push(item);fs.writeFileSync('evidence/browser-wallet-transactions.json',JSON.stringify(walletTransactions,null,2));
 });
 page.on('pageerror',e=>errors.push(e.message));
 await page.addInitScript(({account})=>{
   window.__transactions=[];window.__listeners={};
   window.ethereum={
     request:async({method,params=[]})=>{
       if(method==='eth_requestAccounts'||method==='eth_accounts')return [account];
       if(method==='eth_chainId'&&window.__chainOverride)return window.__chainOverride;
       const response=await fetch('http://127.0.0.1:18545',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:1,method,params})});
       const value=await response.json();if(value.error)throw Error(value.error.message);
       if(method==='eth_estimateGas'&&window.__switchDuringEstimate){
         window.__switchDuringEstimate=false;
         window.__chainOverride='0x1';
         window.__listeners.chainChanged('0x1');
       }
       if(method==='eth_sendTransaction'){window.__transactions.push(value.result);await window.captureWalletTx(value.result);}return value.result;
     },
     on:(event,callback)=>{window.__listeners[event]=callback;}
   };
 },{account:process.env.ANVIL_ACCOUNT});
 await page.goto('http://127.0.0.1:18080');
 await expect(page.locator('#status')).toContainText('market ready');
 await page.click('#connect');await expect(page.locator('#status')).toContainText('Wallet connected');
 async function action(name,amount){
   await page.selectOption('#action',name);if(amount)await page.fill('#amount',amount);
   await page.click('#execute');await expect(page.locator('#confirm')).toBeVisible();
   await page.click('#confirm');await expect(page.locator('#status')).toContainText('Action confirmed',{timeout:30000});
   await expect(page.locator('#execute')).toBeEnabled();confirmations.push(name);
 }
 await action('deposit','1000');
 await action('withdraw','100');
 await action('addCollateral','1');
 await action('borrow','100');
 await expect(page.locator('#debt')).toContainText('100');
 await action('repay');
 await expect(page.locator('#health')).toHaveText('Debt free');
 await action('removeCollateral','1');
 await action('redeem');
 await expect(page.locator('#cash')).toContainText('0 mUSD');
 // Invalid decimal input is rejected before any transaction.
 await page.selectOption('#action','deposit');await page.fill('#amount','-1');await page.click('#execute');
 await expect(page.locator('#status')).toContainText('positive decimal');await expect(page.locator('#confirm')).toBeHidden();
 // Unhealthy-position liquidation is exercised through the UI using the local RPC, not a mocked receipt.
 const cfg=JSON.parse(fs.readFileSync('apps/web/config.json','utf8'));
 const sel=JSON.parse(fs.readFileSync('apps/web/selectors.json','utf8'));
 const word=x=>BigInt(x).toString(16).padStart(64,'0');
 async function tx(from,to,signature,args){
   const data='0x'+sel[signature]+args.map(word).join('');
   const result=await fetch('http://127.0.0.1:18545',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:1,method:'eth_sendTransaction',params:[{from,to,data,gas:'0x989680'}]})}).then(r=>r.json());
   if(result.error)throw Error(result.error.message);
   let receipt;
   for(let i=0;i<100;i++){
     receipt=await fetch('http://127.0.0.1:18545',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:1,method:'eth_getTransactionReceipt',params:[result.result]})}).then(r=>r.json());
     if(receipt.result)break;await new Promise(r=>setTimeout(r,100));
   }
   if(!receipt.result||BigInt(receipt.result.status)!==1n){
     const trace=await fetch('http://127.0.0.1:18545',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:1,method:'debug_traceTransaction',params:[result.result,{tracer:'callTracer'}]})}).then(r=>r.json());
     fs.writeFileSync('evidence/browser-fixture-failure.json',JSON.stringify({signature,args:args.map(String),receipt,trace},null,2));
     throw Error('External fixture transaction failed: '+signature+' '+JSON.stringify(receipt));
   }
   return result.result;
 }
 await action('deposit','1000');
 const borrower=process.env.BORROWER_ACCOUNT;
 await tx(borrower,cfg.vault,'addCollateral(uint256)',[10n**18n]);
 await tx(borrower,cfg.vault,'borrow(uint256)',[500n*10n**6n]);
 await page.selectOption('#action','liquidate');await page.fill('#borrower',borrower);await page.click('#execute');
 await expect(page.locator('#status')).toContainText('healthy');await expect(page.locator('#confirm')).toBeHidden();
 await tx(process.env.ANVIL_ACCOUNT,cfg.oracle,'setPrice(uint256)',[500n*10n**18n]);
 await page.selectOption('#action','liquidate');await page.fill('#borrower',borrower);
 await page.click('#execute');await expect(page.locator('#confirm')).toBeVisible();await page.click('#confirm');
 await expect(page.locator('#status')).toContainText('Action confirmed',{timeout:30000});
 await expect(page.locator('#execute')).toBeEnabled();confirmations.push('liquidate');
 async function rawRead(to,signature,args=[]){
   const data='0x'+sel[signature]+args.map(word).join('');
   const d=await fetch('http://127.0.0.1:18545',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:1,method:'eth_call',params:[{to,data},'latest']})}).then(r=>r.json());
   if(d.error)throw Error(d.error.message);return BigInt(d.result);
 }
 if(await rawRead(cfg.vault,'debtShares(address)',[borrower])!==0n)throw Error('Liquidation left debt');
 if(await rawRead(cfg.vault,'collateralOf(address)',[borrower])!==0n)throw Error('Liquidation left collateral');
 const hashes=await page.evaluate(()=>window.__transactions);
 const receipts=[];
 for(const hash of hashes){
   const d=await fetch('http://127.0.0.1:18545',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:1,method:'eth_getTransactionReceipt',params:[hash]})}).then(r=>r.json());
   if(!d.result||BigInt(d.result.status)!==1n)throw Error('Wallet transaction did not succeed: '+hash);
   receipts.push(d.result);
 }
 if(receipts.length<9)throw Error('Not all wallet flows sent transactions');
 await tx(process.env.ANVIL_ACCOUNT,cfg.oracle,'setPrice(uint256)',[2000n*10n**18n]);
 await page.screenshot({path:'evidence/frontend-desktop.png',fullPage:true});
 await page.setViewportSize({width:390,height:844});
 await page.screenshot({path:'evidence/frontend-mobile.png',fullPage:true});
 const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>window.innerWidth);
 if(overflow)throw Error('Mobile layout overflows');
 const beforeRejected=await page.evaluate(()=>window.__transactions.length);
 await page.evaluate(()=>{window.__chainOverride='0x1';});
 await page.selectOption('#action','deposit');await page.fill('#amount','1');await page.click('#execute');
 await expect(page.locator('#status')).toContainText('Switch wallet');
 await expect(page.locator('#confirm')).toBeHidden();
 await page.evaluate(()=>{window.__listeners.chainChanged('0x1');});
 await expect(page.locator('#execute')).toBeDisabled();
 await page.evaluate(()=>{window.__chainOverride=undefined;});
 await page.click('#connect');await expect(page.locator('#execute')).toBeEnabled();
 await page.evaluate(()=>window.__listeners.accountsChanged([]));
 await expect(page.locator('#execute')).toBeDisabled();
 if(await page.evaluate(()=>window.__transactions.length)!==beforeRejected)throw Error('Rejected network/account action broadcast a transaction');
 
 // Switch chains while the real Anvil gas estimate is in flight.
 await page.click('#connect');await expect(page.locator('#execute')).toBeEnabled();
 await page.selectOption('#action','withdraw');await page.fill('#amount','1');
 await page.click('#execute');await expect(page.locator('#confirm')).toBeVisible();
 await page.evaluate(()=>{window.__switchDuringEstimate=true;});
 await page.click('#confirm');
 await expect(page.locator('#status')).toContainText('Switch wallet');
 if(await page.evaluate(()=>window.__transactions.length)!==beforeRejected)throw Error('Gas-estimation race broadcast a transaction');
 await page.evaluate(()=>{window.__chainOverride=undefined;});
 if(errors.length)throw Error(errors.join('\n'));
 fs.writeFileSync('evidence/browser.json',JSON.stringify({status:'PASS',engine:browser.version(),flow:['connect','deposit','withdraw','addCollateral','borrow','repay','removeCollateral','redeem','invalid input','healthy liquidation rejection','liquidate','wrong network rejection','account/chain change','chain change during gas estimation'],viewport:[1280,1000],mobile:[390,844],pageErrors:errors,provider:'unlocked local Anvil, no private key',confirmations,receipts},null,2));
 await browser.close();console.log('PASS browser wallet and liquidation flows');
})().catch(e=>{console.error(e);process.exit(1)});
