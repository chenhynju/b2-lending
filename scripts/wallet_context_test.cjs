const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '../apps/web/app.js'), 'utf8');
const boot = source.indexOf('try{const [c,s]=await');
assert(boot > 0, 'Expected module initialization boundary');

async function scenario(name, change) {
  const elements = new Map();
  function element(id) {
    if (!elements.has(id)) elements.set(id, {
      value: 'deposit', hidden: false, disabled: false, textContent: '',
      addEventListener() {}
    });
    return elements.get(id);
  }
  const context = vm.createContext({
    document: {getElementById: element, querySelector: () => element('label')},
    setTimeout, Date
  });
  vm.runInContext(source.slice(0, boot), context);
  const sender = '0x0118e172324801a6333e7d0faf7f9bb4ed72628f';
  let chain = '0x14a34';
  let active = sender;
  const requests = [];
  context.provider = {request: async ({method, params}) => {
    if (method === 'eth_chainId') return chain;
    if (method === 'eth_accounts') return [active];
    if (method === 'eth_estimateGas') {
      if (change === 'chain') chain = '0x1';
      if (change === 'account') active = '0x' + '2'.repeat(40);
      if (change === 'event') vm.runInContext('epoch++; account=null; invalidate();', context);
      return '0x10000';
    }
    if (method === 'eth_sendTransaction') {
      requests.push(params[0]);
      if (change === 'receipt') vm.runInContext('epoch++; account=null; invalidate();', context);
      return '0x' + '1'.repeat(64);
    }
    if (method === 'eth_getTransactionReceipt') return {status: '0x1'};
    throw Error('Unexpected RPC method ' + method);
  }};
  vm.runInContext(
    "config={chainId:84532}; selectors={'borrow(uint256)':'c5ebeaec'}; account='" +
    sender + "'; wallet=provider;", context
  );
  let error;
  try {
    await vm.runInContext(
      "send('0x4a9c4c103ec26ed88528a9c8daf032bedb854999','borrow(uint256)',[1n])",
      context
    );
  } catch (e) { error = e; }
  if (change === 'none') {
    assert.equal(error, undefined);
    assert.equal(requests.length, 1);
    assert.equal(requests[0].chainId, '0x14a34');
    assert.equal(requests[0].from, sender);
  } else if (change === 'receipt') {
    assert.match(error?.message || '', /Wallet changed after submission/);
    assert.equal(requests.length, 1);
  } else {
    assert(error, 'Changed wallet must reject');
    assert.equal(requests.length, 0, 'No transaction request after invalidation');
  }
  console.log('PASS ' + name);
}
(async () => {
  await scenario('unchanged wallet binds sender and chain', 'none');
  await scenario('network changes during gas estimation', 'chain');
  await scenario('active account changes without an event', 'account');
  await scenario('wallet event invalidates pending action', 'event');
  await scenario('wallet change prevents stale receipt completion', 'receipt');
})().catch(error => { console.error(error); process.exitCode = 1; });
