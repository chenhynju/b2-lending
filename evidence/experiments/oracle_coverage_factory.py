from pathlib import Path
import shutil,tempfile,subprocess,json,os
r=Path('/home/chenhy/workspace/web3-portfolio/b2-lending');e=r/'evidence'
os.environ['PATH']=str(Path.home()/'.foundry/bin')+':'+os.environ['PATH']
with tempfile.TemporaryDirectory(prefix='b2-oracle-coverage-') as temp:
 p=Path(temp);(p/'src/interfaces').mkdir(parents=True);(p/'test').mkdir()
 for path in ['src/FeedOracle.sol','src/interfaces/IPriceOracle.sol']:shutil.copy(r/path,p/path)
 (p/'lib').symlink_to(r/'lib',target_is_directory=True)
 (p/'foundry.toml').write_text((r/'foundry.toml').read_text().replace('via_ir = true','via_ir = false'))
 mocks=(r/'test/mocks/Mocks.sol').read_text();start=mocks.index('contract MockFeed');end=mocks.index('/// @notice USDT-style')
 (p/'test/MockFeed.sol').write_text('// SPDX-License-Identifier: MIT\npragma solidity 0.8.38;\nimport {IAggregatorV3} from "../src/FeedOracle.sol";\n'+mocks[start:end])
 test=(r/'test/FeedOracle.t.sol').read_text().replace('"./mocks/Mocks.sol"','"./MockFeed.sol"').replace('new FeedOracle(','factory.deploy(')
 test=test.replace('contract FeedOracleTest is Test {','contract FeedOracleTest is Test {\n OracleTestFactory factory;')
 test=test.replace('vm.warp(10 days);','vm.warp(10 days); factory=new OracleTestFactory();')
 test+='\ncontract OracleTestFactory { function deploy(address c,address l,address s,uint256 a) external returns(FeedOracle) { return new FeedOracle(c,l,s,a); } }\n'
 (p/'test/FeedOracle.t.sol').write_text(test)
 cmd=['forge','coverage','--report','summary','--report','lcov','--fuzz-runs','256']
 with (e/'oracle-coverage-factory.txt').open('w') as log:result=subprocess.run(cmd,cwd=p,stdout=log,stderr=subprocess.STDOUT)
 if (p/'lcov.info').exists():shutil.copy(p/'lcov.info',e/'oracle-factory-lcov.info')
 (e/'oracle-coverage-factory-execution.json').write_text(json.dumps({'exitCode':result.returncode,'command':cmd,'scope':'Unmodified oracle; full tests use explicit external deployment factory to check constructor coverage mapping.'},indent=2))
 print(result.returncode)
