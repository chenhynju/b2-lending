const $=id=>document.getElementById(id);
const MAX=(1n<<256n)-1n;
let config,selectors,wallet,account,pending,busy=false,epoch=0;
const words=values=>values.map(v=>BigInt(v).toString(16).padStart(64,'0')).join('');
const data=(signature,values=[])=>'0x'+selectors[signature]+words(values);
const show=text=>{$('status').textContent=text;};
const fmt=(n,d=6)=>{n=BigInt(n);const scale=10n**BigInt(d);const f=(n%scale).toString().padStart(d,'0').slice(0,6).replace(/0+$/,'');return (n/scale).toString()+(f?'.'+f:'');};
function units(text,d){if(!/^(0|[1-9][0-9]*)(\.[0-9]+)?$/.test(text))throw Error('Enter a positive decimal amount.');const [a,b='']=text.split('.');if(b.length>d)throw Error('Too many decimal places.');const n=BigInt(a)*10n**BigInt(d)+BigInt(b.padEnd(d,'0')||'0');if(n<=0n||n>MAX)throw Error('Amount out of range.');return n;}
async function rpc(method,params=[]){return wallet.request({method,params});}
async function checkNetwork(){const chain=BigInt(await rpc('eth_chainId'));if(chain!==BigInt(config.chainId)||![31337n,84532n].includes(chain))throw Error('Switch wallet to the configured local or Base Sepolia network.');}
async function read(to,signature,args=[]){const result=await rpc('eth_call',[{to,data:data(signature,args)},'latest']);return BigInt(result);}
async function send(to,signature,args=[]){
 await checkNetwork();
 const transaction={from:account,to,data:data(signature,args)};
 const estimate=BigInt(await rpc('eth_estimateGas',[transaction]));
 transaction.gas='0x'+((estimate*120n+99n)/100n).toString(16);
 const hash=await rpc('eth_sendTransaction',[transaction]);
 show('Transaction submitted: '+hash);
 const deadline=Date.now()+120000;
 while(Date.now()<deadline){const receipt=await rpc('eth_getTransactionReceipt',[hash]);if(receipt){if(BigInt(receipt.status)!==1n)throw Error('Transaction reverted. Refresh the position before retrying.');return receipt;}await new Promise(r=>setTimeout(r,500));}
 throw Error('Confirmation is still pending. Check the wallet before retrying.');
}
async function approve(token,amount){
 const allowance=await read(token,'allowance(address,address)',[account,config.vault]);
 if(allowance>=amount)return;
 if(allowance!==0n)await send(token,'approve(address,uint256)',[config.vault,0n]);
 await send(token,'approve(address,uint256)',[config.vault,amount]);
}
async function refresh(){
 await checkNetwork();
 const readV=(sig,args=[])=>read(config.vault,sig,args);
 const [assets,cash,apr,loss,shares,collateral,debt,health]=await Promise.all([
 readV('totalAssets()'),readV('cash()'),readV('borrowRate()'),readV('cumulativeBadDebt()'),
 readV('balanceOf(address)',[account]),readV('collateralOf(address)',[account]),
 readV('debtOf(address)',[account]),readV('healthFactor(address)',[account])]);
 $('assets').textContent=fmt(assets,config.loanDecimals)+' '+config.loanSymbol;
 $('cash').textContent=fmt(cash,config.loanDecimals)+' '+config.loanSymbol;
 $('apr').textContent=fmt(apr/10n**14n,2)+'%';
 $('loss').textContent=fmt(loss,config.loanDecimals)+' '+config.loanSymbol;
 $('shares').textContent=fmt(shares,config.loanDecimals+6);
 $('collateral').textContent=fmt(collateral,config.collateralDecimals)+' '+config.collateralSymbol;
 $('debt').textContent=fmt(debt,config.loanDecimals)+' '+config.loanSymbol;
 $('health').textContent=health===MAX?'Debt free':fmt(health,18);
 $('network').textContent=config.chainId===31337?'Local demonstration · Anvil':'Base Sepolia · Test tokens';
}
function invalidate(){pending=null;$('confirm').hidden=true;$('quote').textContent='';}
async function review(){
 await checkNetwork();invalidate();
 const action=$('action').value;
 const collateral=['addCollateral','removeCollateral'].includes(action);
 const signature={deposit:'deposit(uint256,uint256)',withdraw:'withdraw(uint256,uint256)',redeem:'redeem(uint256,uint256)',addCollateral:'addCollateral(uint256)',removeCollateral:'removeCollateral(uint256)',borrow:'borrow(uint256)',repay:'repay(address,uint256,uint256)',liquidate:'liquidate(address,uint256,uint256,uint256)'}[action];
 let amount,args,approval;
 if(!['redeem','repay','liquidate'].includes(action))amount=units($('amount').value,collateral?config.collateralDecimals:config.loanDecimals);
 if(action==='deposit'){
 const quote=await read(config.vault,'previewDeposit(uint256)',[amount]);if(quote===0n)throw Error('Amount is too small to mint a share.');
 args=[amount,quote*995n/1000n];approval=[config.loan,amount];
 }else if(action==='withdraw'){
 const [s,a]=await Promise.all([read(config.vault,'totalSupply()'),read(config.vault,'totalAssets()')]);
 if(a===0n)throw Error('No assets available.');args=[amount,((amount*s+a-1n)/a)*1005n/1000n+1n];
 }else if(action==='redeem'){
 const shares=await read(config.vault,'balanceOf(address)',[account]);if(shares===0n)throw Error('No shares to redeem.');
 const [s,a]=await Promise.all([read(config.vault,'totalSupply()'),read(config.vault,'totalAssets()')]);
 args=[shares,(shares*a/s)*995n/1000n];
 }else if(action==='repay'||action==='liquidate'){
 const borrower=action==='repay'?account:$('borrower').value.trim();
 if(!/^0x[0-9a-fA-F]{40}$/.test(borrower))throw Error('Enter a valid borrower address.');
 const [shares,debt]=await Promise.all([read(config.vault,'debtShares(address)',[borrower]),read(config.vault,'debtOf(address)',[borrower])]);
 if(shares===0n)throw Error('This position has no debt.');
 const maximum=debt*1005n/1000n+1n;
 if(action==='liquidate'){
 const [health,collateralAmount,p]=await Promise.all([read(config.vault,'healthFactor(address)',[borrower]),read(config.vault,'collateralOf(address)',[borrower]),read(config.oracle,'price()')]);
 if(health>=10n**18n)throw Error('This position is healthy and cannot be liquidated.');
 const quote=debt*(10n**18n+5n*10n**16n)*10n**BigInt(config.collateralDecimals)/(p*10n**BigInt(config.loanDecimals));
 const seized=quote<collateralAmount?quote:collateralAmount;
 args=[borrower,shares,maximum,seized*995n/1000n];
 }else args=[borrower,shares,maximum];
 approval=[config.loan,maximum];
 }else {args=[amount];if(action==='addCollateral')approval=[config.collateral,amount];}
 pending={signature,args,approval,account,epoch};
 $('quote').textContent=action==='repay'?'Repay all debt. Token approval is capped at the quoted debt plus 0.5%.':action==='redeem'?'Redeem all shares. Final proceeds depend on available liquidity.':action==='liquidate'?'Liquidate the quoted unhealthy position. The loan-token spending cap is '+fmt(args[2],config.loanDecimals)+' '+config.loanSymbol+'.':$('action').selectedOptions[0].text+': '+fmt(amount,collateral?config.collateralDecimals:config.loanDecimals)+' '+(collateral?config.collateralSymbol:config.loanSymbol)+'.';
 $('confirm').hidden=false;
}
async function execute(){
 if(busy)throw Error("An action is already pending.");
 const p=pending;if(!p||p.epoch!==epoch||p.account!==account)throw Error('Position changed. Review again.');
 busy=true;show('Awaiting wallet confirmation...');$('execute').disabled=true;$('confirm').disabled=true;
 try{
 await checkNetwork();
 if(p.approval)await approve(...p.approval);
 if(p.epoch!==epoch||p.account!==account)throw Error('Wallet changed. Review again.');
 await send(config.vault,p.signature,p.args);
 invalidate();await refresh();show('Action confirmed. Your position is up to date.');
 }finally{busy=false;$('execute').disabled=!account;$('confirm').disabled=false;}
}
const guarded=fn=>async()=>{try{await fn();}catch(e){show(e.shortMessage||e.message||'Wallet request failed.');}};
function syncInputs(){
 const action=$('action').value;
 const noAmount=['redeem','repay','liquidate'].includes(action);
 $('amount').hidden=noAmount;document.querySelector('label[for=amount]').hidden=noAmount;
 $('borrower').hidden=action!=='liquidate';document.querySelector('label[for=borrower]').hidden=action!=='liquidate';
 invalidate();
}
$('action').addEventListener('change',syncInputs);
syncInputs();
$('amount').addEventListener('input',invalidate);
$('borrower').addEventListener('input',invalidate);
$('execute').onclick=guarded(review);$('confirm').onclick=guarded(execute);
$('connect').onclick=guarded(async()=>{
 if(!config)throw Error('No deployment configured. Run the local demo first.');
 wallet=window.ethereum;if(!wallet)throw Error('Install an EIP-1193 wallet to continue.');
 await checkNetwork();[account]=await rpc('eth_requestAccounts');if(!account)throw Error('No wallet account selected.');
 epoch++;invalidate();$('connect').textContent=account.slice(0,6)+'…'+account.slice(-4);$('execute').disabled=false;
 if(wallet.on){wallet.on('accountsChanged',()=>{epoch++;account=null;invalidate();$('execute').disabled=true;show('Wallet account changed. Reconnect to refresh.');});wallet.on('chainChanged',()=>{epoch++;account=null;invalidate();$('execute').disabled=true;show('Network changed. Reconnect to refresh.');});}
 await refresh();show('Wallet connected. Review an action before confirming it.');
});
try{const [c,s]=await Promise.all([fetch('config.json').then(r=>r.json()),fetch('selectors.json').then(r=>r.json())]);if(!/^0x[0-9a-fA-F]{40}$/.test(c.vault))throw Error('No deployment');config=c;selectors=s;show('Local/testnet market ready. Connect a wallet to view your position.');}catch{show('No deployment configured. Run scripts/local_smoke.py first.');}
