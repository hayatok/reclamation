#!/usr/bin/env python3
"""Compare system HarfBuzz output on every runtime source line, without Godot.
Glyph IDs are normalized to retained original glyph names before comparison.
"""
import argparse, ctypes as C, ctypes.util, json
from pathlib import Path
from fontTools.ttLib import TTFont
from build_runtime_font import corpus
h=C.CDLL(ctypes.util.find_library('harfbuzz'))
def bind(name,args,ret):
    f=getattr(h,name);f.argtypes=args;f.restype=ret;return f
P=C.c_void_p; U=C.c_uint; I=C.c_int; S=C.c_char_p
blob=bind('hb_blob_create_from_file_or_fail',[S],P)
face=bind('hb_face_create',[P,U],P); font=bind('hb_font_create',[P],P)
funcs=bind('hb_ot_font_set_funcs',[P],None);scale=bind('hb_font_set_scale',[P,I,I],None)
buf=bind('hb_buffer_create',[],P);add=bind('hb_buffer_add_utf8',[P,S,I,U,I],None)
guess=bind('hb_buffer_guess_segment_properties',[P],None)
lang=bind('hb_language_from_string',[S,I],P);setlang=bind('hb_buffer_set_language',[P,P],None)
direction=bind('hb_direction_from_string',[S,I],I);setdir=bind('hb_buffer_set_direction',[P,I],None)
class Info(C.Structure): _fields_=[('glyph',U),('mask',U),('cluster',U),('v1',U),('v2',U)]
class Pos(C.Structure): _fields_=[('xa',I),('ya',I),('xo',I),('yo',I),('v',U)]
class Feature(C.Structure): _fields_=[('tag',U),('value',U),('start',U),('end',U)]
parse=bind('hb_feature_from_string',[S,I,C.POINTER(Feature)],I)
shape=bind('hb_shape',[P,P,C.POINTER(Feature),U],None)
infos=bind('hb_buffer_get_glyph_infos',[P,C.POINTER(U)],C.POINTER(Info))
positions=bind('hb_buffer_get_glyph_positions',[P,C.POINTER(U)],C.POINTER(Pos))
destroy=bind('hb_buffer_destroy',[P],None)
version=bind('hb_version_string',[],S)
def load(path,index):
    b=blob(str(path).encode());assert b; f=font(face(b,index));funcs(f);scale(f,1000,1000);return f

def run(f,order,text,language,flow,feature=None):
    b=buf();s=text.encode();add(b,s,len(s),0,len(s));setlang(b,lang(language.encode(),-1));setdir(b,direction(flow.encode(),-1));guess(b)
    ft=Feature()
    if feature:assert parse((feature+'=1').encode(),-1,C.byref(ft))
    shape(f,b,C.byref(ft) if feature else None,1 if feature else 0)
    n=U();a=infos(b,C.byref(n));p=positions(b,C.byref(n))
    result=[(order[a[i].glyph],a[i].cluster,p[i].xa,p[i].ya,p[i].xo,p[i].yo) for i in range(n.value)]
    destroy(b);return result

def main():
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--font',type=Path,required=True);a=p.parse_args()
    original=a.source/'assets/Japanese.ttc';f=TTFont(original,fontNumber=0);g=TTFont(a.font)
    first=load(original,0);second=load(a.font,0);oo=f.getGlyphOrder();so=g.getGlyphOrder()
    chars,files,lines,_=corpus(a.source)
    # Exact source lines cover every string fragment including catalogs and escaped data;
    # concatenated sorted charset additionally exercises closure beyond individual UI strings.
    samples=sorted(set(lines))+[''.join(chr(c) for c in sorted(chars))]
    count=0
    for language,flow in [('ja','ltr'),('en','ltr'),('zh','ltr'),('ko','ltr'),('ja','ttb')]:
        for text in samples:
            assert run(first,oo,text,language,flow)==run(second,so,text,language,flow),f'Shaping mismatch: {language}/{flow} {text}'
            count+=1
    tags=sorted({r.FeatureTag for table in ['GPOS','GSUB'] for r in f[table].table.FeatureList.FeatureRecord})
    text=''.join(chr(c) for c in sorted(chars))
    for tag in tags:
        assert run(first,oo,text,'ja','ltr',tag)==run(second,so,text,'ja','ltr',tag),f'Feature mismatch: {tag}'
        count+=1
    print(json.dumps({'harfbuzz_version':version().decode(),'comparisons':count,'unique_lines_and_charset':len(samples),'feature_tags_checked':tags,'result':'all normalized glyph sequences, advances and offsets identical'},indent=2))
if __name__=='__main__':main()
