"""Apply one pinned MSS100 diagnostic patch; refuse other source contents."""
from pathlib import Path
import hashlib,json,subprocess,sys

source=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve()
recipe=Path(__file__).resolve().parents[1]
manifest=json.loads((recipe/'patches/aod-diagnostic/manifest.json').read_text())
target=source/'drivers/input/touchscreen/melfas_mss100/melfas_mss100.c'
sha=lambda b:hashlib.sha256(b).hexdigest()
revision=subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip()
assert revision==manifest['source_commit'],'Wrong source revision'
assert sha(target.read_bytes())==manifest['source_sha256'],'Original driver differs'
patch=recipe/'patches/aod-diagnostic/mss100-aod-diagnostics.patch'
assert sha(patch.read_bytes())==manifest['patch_sha256'],'Patch differs'
subprocess.run(['git','-C',str(source),'apply','--check',str(patch)],check=True)
subprocess.run(['git','-C',str(source),'apply',str(patch)],check=True)
assert sha(target.read_bytes())==manifest['patched_sha256'],'Patched driver differs'
changed=subprocess.check_output(['git','-C',str(source),'diff','--name-only'],text=True).splitlines()
assert changed==['drivers/input/touchscreen/melfas_mss100/melfas_mss100.c'],changed
out.mkdir(exist_ok=True)
(out/'aod-diagnostic.patch').write_bytes(patch.read_bytes())
record=dict(manifest,applied=True,build_purpose='diagnostic only; not an AOD functional fix')
(out/'aod-diagnostic.json').write_text(json.dumps(record,indent=2)+'\n')
print('Verified and applied MSS100 diagnostic patch:',record['patch_sha256'])
