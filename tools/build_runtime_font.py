#!/usr/bin/env python3
"""Deterministic UI font generation and coverage gate. Requires fontTools 4.61.1.
Reads source only; --check never regenerates. Review input paths after adding text input,
localization, remote content, external catalogs, dynamic codepoints, or new text formats.
"""
import argparse, hashlib, io, json, re, zlib
from pathlib import Path
import fontTools
from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import RecordingPen
EXCLUDED={'.git','.godot','tests','tools','docs','scripts','art_source','licenses','builds'}
EXTENSIONS={'.gd','.tscn','.tres','.godot','.json','.csv','.tsv','.po','.cfg','.gdshader','.txt'}
# Existing dormant helpers, not excluded from shaping corpus. Their original Japanese
# face also lacks these chars; preserve that fallback behavior. Any new occurrence fails.
EXCEPTIONS={'command_deck.gd': {
 '   key={"Period":".","Space":"SP","Escape":"Esc","Enter":"↵"}.get(key,key)': {'↵'},
 ' l.text="▰  "+text': {'▰'},
}}
def corpus(root):
    chars=set(range(32,127)); files=[]; lines=[]; omitted=[]
    for p in sorted(root.rglob('*')):
        r=p.relative_to(root)
        if not p.is_file() or any(part in EXCLUDED for part in r.parts) or p.suffix not in EXTENSIONS: continue
        text=p.read_text(encoding='utf-8'); files.append(str(r))
        if re.search(r'\.section_rule\s*\(|[\"\']Enter ',text):
            raise AssertionError(f'Dormant unsupported symbol helper may be activated: {r}')
        # Current game has no runtime text-entry controls, remote text or char construction.
        if p.suffix=='.gd' and re.search(r'(?:LineEdit|TextEdit)\.new\s*\(|HTTPRequest|HTTPClient|WebSocket|TranslationServer|String\.chr\s*\(|\bchar\s*\(',text):
            raise AssertionError(f'Text-input surface changed; audit required: {r}')
        for line in text.splitlines():
            lines.append(line)
            skip=EXCEPTIONS.get(str(r),{}).get(line,set())
            if skip: omitted.append({'file':str(r),'line':line,'codepoints':[ord(c) for c in sorted(skip)]})
            chars.update(ord(c) for c in line if ord(c)>=32 and c not in skip)
        chars.update(int(x,16) for x in re.findall(r'\\u([0-9a-fA-F]{4})',text))
        chars.update(int(x,16) for x in re.findall(r'\\U([0-9a-fA-F]{6,8})',text))
    assert len(omitted)==2, 'Dormant helper exceptions changed: review before updating'
    return chars,files,lines,omitted

def make(original,chars):
    font=TTFont(original,fontNumber=0,recalcTimestamp=False)
    opts=subset.Options(); opts.layout_features=['*']; opts.layout_scripts=['*']
    opts.name_IDs=['*']; opts.name_languages=['*']; opts.name_legacy=True
    opts.notdef_outline=True;opts.hinting=True;opts.glyph_names=True
    opts.drop_tables=[];opts.passthrough_tables=True;opts.recalc_timestamp=False
    opts.harfbuzz_repacker=False;opts.ignore_missing_unicodes=False
    s=subset.Subsetter(options=opts);s.populate(unicodes=sorted(chars));s.subset(font)
    names={1:'Reclamation UI JP',2:'Regular',3:'ReclamationUIJP-Regular-Subset-v1',4:'Reclamation UI JP Regular',6:'ReclamationUIJP-Regular',16:'Reclamation UI JP',17:'Regular'}
    for n in font['name'].names:
        if n.nameID in names: n.string=names[n.nameID].encode(n.getEncoding())
    cff=font['CFF '].cff;cff.fontNames=['ReclamationUIJP-Regular']
    cff.topDictIndex[0].FamilyName='Reclamation UI JP';cff.topDictIndex[0].FullName='Reclamation UI JP Regular'
    b=io.BytesIO();font.save(b,reorderTables=True);return b.getvalue()

def verify(source,target,chars):
    orig=TTFont(source,fontNumber=0,recalcTimestamp=False);out=TTFont(target,recalcTimestamp=False)
    missing=chars-set(out.getBestCmap()); assert not missing, 'MISSING UI CHARACTERS: '+repr([f'U+{c:04X} {chr(c)}' for c in sorted(missing)])
    a=orig.getGlyphSet();b=out.getGlyphSet()
    for glyph in out.getGlyphOrder():
        p=RecordingPen();q=RecordingPen();a[glyph].draw(p);b[glyph].draw(q)
        assert p.value==q.value, f'Outline changed: {glyph}'
        for table in ['hmtx','vmtx']:
            assert orig[table][glyph]==out[table][glyph],f'Metrics changed: {table}/{glyph}'
    for table,attributes in {'head':['unitsPerEm'],'hhea':['ascent','descent','lineGap'],'vhea':['ascent','descent','lineGap'],'OS/2':['sTypoAscender','sTypoDescender','sTypoLineGap','usWinAscent','usWinDescent'],'post':['underlinePosition','underlineThickness']}.items():
        for attr in attributes: assert getattr(orig[table],attr)==getattr(out[table],attr),(table,attr)
    for cp in chars: assert orig.getBestCmap()[cp]==out.getBestCmap()[cp],f'Cmap changed {cp}'
    for name in [0,13,14]: assert orig['name'].getDebugName(name)==out['name'].getDebugName(name),'License metadata changed'
    return len(out.getGlyphOrder())

def main():
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--check',action='store_true');args=p.parse_args()
    assert fontTools.__version__=='4.61.1', 'Use audited fontTools 4.61.1'
    chars,files,lines,omitted=corpus(args.source);original=args.source/'assets/Japanese.ttc'
    original_font=TTFont(original,fontNumber=0); missing=chars-set(original_font.getBestCmap())
    assert not missing, 'Source font itself lacks UI characters; audit required: '+repr([chr(c) for c in sorted(missing)])
    if not args.check:
        data=make(original,chars);assert data==make(original,chars),'Non-deterministic font output'
        args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_bytes(data)
    glyphs=verify(original,args.output,chars)
    result={'fonttools':fontTools.__version__,'source_font_bytes':original.stat().st_size,'output_font_bytes':args.output.stat().st_size,'zlib_size_estimate_not_godot':len(zlib.compress(args.output.read_bytes(),9)),'source_sha256':hashlib.sha256(original.read_bytes()).hexdigest(),'output_sha256':hashlib.sha256(args.output.read_bytes()).hexdigest(),'face_index':0,'source_family':original_font['name'].getDebugName(1),'codepoints':len(chars),'glyphs_including_layout_closure':glyphs,'files':files,'dormant_original_missing_glyphs':omitted,'verified':'determinism; coverage; every retained glyph outline, horizontal/vertical metric; global line metrics; cmap; license metadata','import_export_runtime_test':'pending Godot slot'}
    print(json.dumps(result,ensure_ascii=False,indent=2))
if __name__=='__main__':main()
