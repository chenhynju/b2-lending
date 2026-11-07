#!/usr/bin/env python3
"""Install pinned Linux verification tools with recorded SHA-256 checks."""
import hashlib,json,os,subprocess,tarfile,tempfile,urllib.request
from pathlib import Path
r=Path(__file__).resolve().parents[1];m=json.loads((r/"scripts/toolchain.lock.json").read_text())
dest=Path.home()/".local/bin";dest.mkdir(parents=True,exist_ok=True)
for name in ["foundry","aderyn"]:
    item=m[name]
    with tempfile.TemporaryDirectory(prefix="b2-tools-") as temp:
        p=Path(temp);archive=p/"archive"
        request=urllib.request.Request(item["url"],headers={"User-Agent":"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36"})
        with urllib.request.urlopen(request) as response:archive.write_bytes(response.read())
        assert hashlib.sha256(archive.read_bytes()).hexdigest()==item["sha256"],name+" digest mismatch"
        with tarfile.open(archive) as tar:tar.extractall(p/"files",filter="data")
        required=["forge","cast","anvil"] if name=="foundry" else ["aderyn"]
        for binary in required:
            matches=list((p/"files").rglob(binary));assert len(matches)==1
            output=dest/binary;output.write_bytes(matches[0].read_bytes());output.chmod(0o755)
solc=m["solc"];target=Path.home()/".local/share/svm/0.8.38/solc-0.8.38";target.parent.mkdir(parents=True,exist_ok=True)
request=urllib.request.Request(solc["url"],headers={"User-Agent":"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36"})
with urllib.request.urlopen(request) as response:data=response.read()
assert hashlib.sha256(data).hexdigest()==solc["sha256"];target.write_bytes(data);target.chmod(0o755)
print("Installed pinned tools with digest checks")
