from pathlib import Path
import shutil,tempfile,subprocess,json,os
r=Path(__file__).resolve().parents[1];e=r/'evidence'
os.environ['PATH']=str(Path.home()/'.foundry/bin')+':'+os.environ['PATH']
with tempfile.TemporaryDirectory(prefix='b2-oracle-coverage-') as temp:
 p=Path(temp);(p/'src/interfaces').mkdir(parents=True);(p/'test').mkdir()
 for path in ['src/FeedOracle.sol','src/interfaces/IPriceOracle.sol']:shutil.copy(r/path,p/path)
 (p/'lib').symlink_to(r/'lib',target_is_directory=True)
 (p/'foundry.toml').write_text((r/'foundry.toml').read_text().replace('via_ir = true','via_ir = false'))
 mocks=(r/'test/mocks/Mocks.sol').read_text();start=mocks.index('contract MockFeed');end=mocks.index('/// @notice USDT-style')
 (p/'test/MockFeed.sol').write_text('// SPDX-License-Identifier: MIT\npragma solidity 0.8.38;\nimport {IAggregatorV3} from "../src/FeedOracle.sol";\n'+mocks[start:end])
 (p/'test/FeedOracle.t.sol').write_text((r/'test/FeedOracle.t.sol').read_text().replace('"./mocks/Mocks.sol"','"./MockFeed.sol"'))
 cmd=['forge','coverage','--report','summary','--report','lcov','--fuzz-runs','256']
 with (e/'oracle-coverage-legacy.txt').open('w') as log:result=subprocess.run(cmd,cwd=p,stdout=log,stderr=subprocess.STDOUT)
 if (p/'lcov.info').exists():shutil.copy(p/'lcov.info',e/'oracle-legacy-lcov.info')
 (e/'oracle-coverage-execution.json').write_text(json.dumps({'exitCode':result.returncode,'command':cmd,'scope':'Unmodified oracle and full oracle tests; non-IR 0.8.38 coverage in isolation to avoid unrelated vault stack depth.'},indent=2))
 print(result.returncode)
