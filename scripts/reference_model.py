#!/usr/bin/env python3
"""Independent rational/integer reference; no JS floats or Solidity calls."""
import json,random,argparse
from fractions import Fraction
from pathlib import Path
W=10**18;R=10**27;YEAR=365*86400
def ceil(x): return -(-x.numerator//x.denominator)
def rate(u):
    if u<=8*10**17: return int(Fraction(2,100)*W+Fraction(u,8*10**17)*8*10**16)
    return int(Fraction(W,10)+Fraction(u-8*10**17,2*10**17)*9*10**17)
def rows():
    rng=random.Random(20261105)
    result=[]
    for _ in range(256):
        u=rng.randrange(W+1);index=rng.randrange(R,10**30);dt=rng.randrange(365*86400*10)
        assets=rng.randrange(1,10**24);supply=rng.randrange(1,10**30);managed=rng.randrange(1,10**24)
        r=rate(u);next_index=min(10**36,index+int(Fraction(index*int(Fraction(r*dt,YEAR)),W)))
        result.append([u,r,index,dt,next_index,assets,supply,managed,int(Fraction(assets*supply,managed)),ceil(Fraction(assets*supply,managed)),ceil(Fraction(assets*R,index)),ceil(Fraction(assets*index,R))])
    return result
def check():
    rng=random.Random(101)
    for _ in range(50000):
        u=rng.randrange(W+1);v=rng.randrange(u,W+1)
        assert rate(u)<=rate(v)<=W
        assets=rng.randrange(1,10**30);supply=rng.randrange(1,10**36);managed=rng.randrange(1,10**36)
        minted=int(Fraction(assets*supply,managed))
        recovered=int(Fraction(minted*(managed+assets),supply+minted))
        assert recovered<=assets
    return {"properties":2,"samples":50000,"seed":101,"status":"PASS"}
if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--write",action="store_true");a=parser.parse_args()
    root=Path(__file__).resolve().parents[1];p=root/"test/fixtures/reference.json"
    expected=json.dumps(rows(),separators=(",",":"))
    if a.write:p.parent.mkdir(exist_ok=True,parents=True);p.write_text(expected)
    else:assert p.read_text()==expected
    print(json.dumps(check()))
