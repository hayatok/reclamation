"""Bounded clean integration archives; excludes Godot cache/extracted duplicates."""
from pathlib import Path
import hashlib,json,zipfile
P=Path(__file__).resolve().parent.parent
names=['house','depot','barracks','vehicle_workshop','garden']
files=sorted((P/'assets').glob('*.glb'))+sorted((P/'icons').glob('*.svg'))+sorted((P/'icons').glob('*.png'))
(P/'SHA256SUMS.txt').write_text(''.join(hashlib.sha256(f.read_bytes()).hexdigest()+'  '+str(f.relative_to(P))+'\n' for f in files))
manifest={'version':'0.9-settlement-art','coordinate_system':{'up':'+Y','front':'-Z','root':'footprint center at ground'},'assets':json.loads((P/'reports'/'asset_stats.json').read_text()),'runtime_files':[str(f.relative_to(P)) for f in files],'atlas_embedded':True,'one_surface_each':True,'external_asset_dependencies':[]}
(P/'manifest.json').write_text(json.dumps(manifest,indent=2))
docs=[P/x for x in ['README.md','INTEGRATION.md','ASSET_PROVENANCE.md','SHA256SUMS.txt','manifest.json']]
reports=[P/'reports'/x for x in ['asset_stats.json','glb_contract.json','godot_import_checks.json','godot_validation.log','packed_source_checks.json','native_harness_boot.log','portrait_checks.json']]
with zipfile.ZipFile(P/'reclamation_settlement_v09_runtime.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for f in files+docs+reports:z.write(f,str(f.relative_to(P)))
with zipfile.ZipFile(P/'reclamation_settlement_v09_editable.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for f in sorted((P/'source').glob('*'))+[P/'source'/'.gdignore']+[P/'assets'/('settlement_'+k+'.png') for k in ['albedo','normal','orm']]+docs:
  if f.is_file() and f.suffix!='.import':z.write(f,str(f.relative_to(P)))
print('CLEAN_SETTLEMENT_PACKAGES_WRITTEN')
