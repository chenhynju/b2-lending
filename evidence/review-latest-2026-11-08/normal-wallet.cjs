const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(__dirname + '/app.js', 'utf8');
const elements = new Map();
function element(id) {
 if (!elements.has(id)) elements.set(id, {value:'deposit',hidden:false,disabled:false,textContent:'',addEventListener() {}});
 return elements.get(id);
}
const context = vm.createContext({document:{getElementById:element,querySelector:()=>element('label')},console,setTimeout,Date,fetch:()=>new Promise(()=>{})});
vm.runInContext(source.slice(0, source.indexOf("try{const [c,s]=await")), context);
vm.runInContext(`
config = {chainId:84532};
selectors = {'borrow(uint256)':'c5ebeaec'};
account = '0x0118e172324801a6333e7d0faf7f9bb4ed72628f';
let chain = '0x14a34';
let sends = 0;
wallet = {request: async ({method,params}) => {
 if (method === 'eth_chainId') return chain;
 if (method === 'eth_accounts') return [account];
 if (method === 'eth_estimateGas') {
  chain = '0x14a34';
  
  return '0x10000';
 }
 if (method === 'eth_sendTransaction') {
  sends++;
  console.log(JSON.stringify({method,chain,from:params[0].from,epoch,account}));
  return '0x'+'1'.repeat(64);
 }
 if (method === 'eth_getTransactionReceipt') return {status:'0x1'};
 throw Error(method);
}};
send('0x4a9c4c103ec26ed88528a9c8daf032bedb854999','borrow(uint256)',[1n]).then(()=>{
 if (sends !== 1) throw Error('Missing normal transaction');
 console.log('PASS: unchanged wallet submits one transaction with chainId');
}, error => {
 if(sends !== 0) throw Error('Unsafe request reached wallet');
 console.log('PASS: switched network rejected before eth_sendTransaction: '+error.message);
});
`, context);
