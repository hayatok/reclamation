#!/usr/bin/env python3
"""27 deterministic static mechanic overlays for original RECLAMATION artwork.

Dependency-free SVG authoring. All vector geometry is original. Existing shared
game illustrations are loaded separately by upgrade_diagram.gd, never duplicated
into these plates. No network assets, text/font dependency, or runtime animation.
"""
from pathlib import Path
from math import sin,cos,pi
import json

BRASS='#d5ad63'
PAPER='#e8dec1'
DIM='#737b68'
RUST='#d77859'
INK='#171e1b'
GREEN='#a9c2a3'
ELECTRIC='#b4d5cc'

def path(d,stroke=PAPER,width=2,fill='none',extra=''):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round" {extra}/>'
def line(x1,y1,x2,y2,color=PAPER,width=2,extra=''):
    return path(f'M{x1} {y1}L{x2} {y2}',color,width,extra=extra)
def circle(x,y,r,color=PAPER,width=2,fill='none',extra=''):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{color}" stroke-width="{width}" {extra}/>'
def rect(x,y,w,h,color=PAPER,width=2,fill='none',extra=''):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="{color}" stroke-width="{width}" {extra}/>'
def group(body,x=0,y=0,scale=1,rotate=0,opacity=1):
    return f'<g transform="translate({x} {y}) rotate({rotate}) scale({scale})" opacity="{opacity}">{body}</g>'
def arrow(x1,y1,x2,y2,color=BRASS,width=2.6,head=7,extra=''):
    dx,dy=x2-x1,y2-y1
    length=(dx*dx+dy*dy)**.5
    ux,uy=dx/length,dy/length
    return line(x1,y1,x2,y2,color,width,extra)+path(f'M{x2-ux*head-uy*head*.65:.2f} {y2-uy*head+ux*head*.65:.2f}L{x2} {y2}L{x2-ux*head+uy*head*.65:.2f} {y2-uy*head-ux*head*.65:.2f}',color,width)
def bullet(x,y,scale=1,rotate=0,color=BRASS):
    body=path('M-12 -4H6L14 0L6 4H-12Z',INK,1,color)
    body+=line(-6,-3,-6,3,INK,1.2)+line(-19,0,-15,0,color,1.6)
    return group(body,x,y,scale,rotate)
def plus(x,y,scale=1,color=GREEN):
    return group(path('M-3 -10H3V-3H10V3H3V10H-3V3H-10V-3H-3Z',INK,1.8,color),x,y,scale)
def infected(x,y,scale=1,dead=False,opacity=1):
    body=path('M-10 -24L-8 -35L1 -39L9 -33L7 -23L-1 -18Z',INK,1.8,RUST)
    body+=path('M-5 -20L7 -19L17 -3L9 12L-9 9L-16 -6Z',INK,1.8,RUST)
    body+=path('M-9 -17L-19 -6L-27 -3L-25 4L-11 1L-1 -9M10 -12L18 -4L27 -10L31 -5L19 5L8 -1',INK,1.8,RUST)
    body+=path('M-8 7L-15 23L-13 39H-3L-7 33L-4 21L1 16L8 29L5 40H16L20 27L10 9Z',INK,1.8,RUST)
    body+=line(-3,-29,4,-28,INK,2.4)+path('M-5 -9L1 -3L-4 5',INK,1.7)
    return group(body,x,y,scale,72 if dead else 0,opacity)
def soldier(x,y,scale=1):
    body=path('M-13 -28Q-14 -41 -3 -43Q9 -43 10 -29L3 -26H-8Z',INK,1.5,PAPER)
    body+=path('M-9 -27L7 -27L9 -18L3 -11H-7L-12 -18Z',INK,1.5,PAPER)
    body+=line(-5,-23,7,-23,INK,2)
    body+=path('M-17 -11L-6 -15L8 -11L13 11L5 19H-13L-19 5Z',INK,1.6,PAPER)
    body+=path('M-17 -8L-25 -5L-23 10L-17 13ZM-11 16L-15 41H-26V46H-8L-2 24L6 42H21V36L14 32L10 15Z',INK,1.8,PAPER)
    body+=path('M-3 -8L8 -1L24 -5L26 1L8 9L-9 0Z',INK,1.5,PAPER)
    body+=path('M12 -8H37V-12H46V-4H31L22 5H15Z',INK,1.5,BRASS)
    return group(body,x,y,scale)
def tower(x,y,scale=1):
    body=path('M-23 36L-15 -8H13L21 36ZM-21 -11V-25H22V-11ZM19 -23H47V-17H19Z',INK,2,PAPER)
    body+=path('M-8 0H5V18H-8ZM-28 36H28V42H-28Z',INK,1.8,PAPER)
    return group(body,x,y,scale)
def burst(x,y,r=28,color=BRASS):
    points=[]
    for i in range(24):
        a=i*pi/12;rad=r if i%2==0 else r*.60
        points.append((x+cos(a)*rad,y+sin(a)*rad))
    return path('M'+'L'.join(f'{x:.2f} {y:.2f}' for x,y in points)+'Z',color,2,INK)
def crosshair(x,y,r=24,color=BRASS):
    return circle(x,y,r,color,1.8)+''.join(line(x+cos(a)*(r-5),y+sin(a)*(r-5),x+cos(a)*(r+7),y+sin(a)*(r+7),color,2) for a in [0,pi/2,pi,pi*1.5])
def crate(x,y,scale=1):
    body=path('M-20 -12L-10 -20H20V13L10 21H-20Z',INK,2,PAPER)
    body+=path('M-20 -12H10L20 -20M10 -12V21M-12 -12V13M2 -12V13',INK,1.6)
    body+=rect(-9,-6,9,12,INK,1.2,BRASS)
    return group(body,x,y,scale)
def bolt(points,width=3):
    return path('M'+'L'.join(f'{x} {y}' for x,y in points),ELECTRIC,width)
def hourglass(x,y,scale=1):
    body=path('M-10 -15H10M-10 15H10M-8 -12H8V-7L1 0L8 7V12H-8V7L-1 0L-8 -7Z',PAPER,1.7,INK)
    body+=path('M-5 -9H5L0 -3ZM-5 10L0 5L5 10Z',BRASS,1,BRASS)
    return group(body,x,y,scale)
def rail(y=177,x1=155,x2=282,color=DIM):
    return line(x1,y,x2,y,color,1.5)+''.join(line(x,y,x-4,y+4,color,1.0,extra='opacity=".6"') for x in range(x1+5,x2-2,14))

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/ui/upgrades/composite'
OUT.mkdir(parents=True,exist_ok=True)

def svg(body):
    return '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="200" viewBox="0 0 300 200">'+body+'</svg>'

background='''<defs><linearGradient id="b" x2="0.8" y2="1"><stop stop-color="#232a2a"/><stop offset="1" stop-color="#202828"/></linearGradient><pattern id="grain" width="19" height="17" patternUnits="userSpaceOnUse"><path d="M2 4h3M11 10h1M6 16h2" stroke="#ead8aa" opacity=".06" stroke-width="1"/></pattern></defs><rect width="300" height="200" fill="url(#b)"/><rect width="300" height="200" fill="url(#grain)"/><path d="M12 14H287M12 186H287" stroke="#a18b60" stroke-width="1" opacity=".28"/>'''
(OUT/'backdrop.svg').write_text(svg(background))

# Range: the subject sits before two clearly separated spatial reach limits.
r=path('M164 32Q204 66 204 152',DIM,2.5,extra='stroke-dasharray="6 6"')
r+=path('M196 22Q270 68 270 159',BRASS,3.2)
r+=path('M202 151H216M257 158H278',BRASS,2)
r+=arrow(206,43,246,27,BRASS,2.8,head=7)
r+=line(114,141,276,100,PAPER,1.6,extra='stroke-dasharray="3 5"')
r+=circle(263,104,23,BRASS,2.5)+circle(263,104,8,PAPER,1.6)
r+=path('M263 74V88M263 120V134M233 104H248M277 104H291',BRASS,2.4)
r+=path('M136 168H204M217 168H271M204 162V174M271 162V174',DIM,1.8)
(OUT/'range.svg').write_text(svg(r))

# Rate: two equal time spans; twice as many cartridges fit the improved span.
r=rect(152,25,136,56,INK,0,INK,extra='opacity=".33"')
r+=rect(152,97,136,60,INK,0,INK,extra='opacity=".42"')
for y,color in [(46,DIM),(122,BRASS)]:
    r+=path(f'M159 {y+18}V{y+24}H282V{y+18}',color,1.8)
    r+=line(159,y,282,y,color,1.2,extra='opacity=".6"')
for x in [170,219,270]:r+=bullet(x,44,.65,color=DIM)
for x in [164,186,208,230,252,274]:r+=bullet(x,120,.62)
r+=arrow(221,78,221,101,BRASS,2.5,head=6)
r+=path('M163 169H281M163 165V173M281 165V173',BRASS,1.5)
r+=path('M194 163L201 169L194 175M229 163L236 169L229 175',BRASS,2.2)
(OUT/'rate.svg').write_text(svg(r))

# Build: material assembly rail, visibly shorter bright completion interval.
r=path('M139 41H280V133M145 39V134M163 39V134M182 39V134M201 39V134M220 39V134M239 39V134M258 39V134M278 42L146 128M146 42L278 128',DIM,1.1,extra='opacity=".4"')
r+=path('M124 116L137 116M128 109L137 116L128 123',BRASS,2.5)
r+=path('M32 153V159H269V153',DIM,2.3)
r+=path('M32 176V182H199V176',BRASS,3)
r+=arrow(266,180,216,180,BRASS,2.6,head=7)
r+=path('M41 151H71M78 151H108M115 151H145M152 151H182M189 151H219M226 151H256',DIM,2)
r+=path('M42 174H66M70 174H94M98 174H122M126 174H150M154 174H178',BRASS,2.4)
(OUT/'build.svg').write_text(svg(r))

# Normal damage: the large solid round and impact show force, without weak-point marks.
r=infected(260,113,.99)+line(147,108,260,108,DIM,1.5)
r+=bullet(199,108,1.75)+burst(252,108,23)
r+=path('M195 63L211 63M206 57L213 63L206 69',BRASS,2)+bullet(177,63,.54,color=DIM)+bullet(236,63,.89)
r+=rail()
(OUT/'damage.svg').write_text(svg(r))

# The original target plus one added target, matching first-rank penetration.
r=infected(182,114,.65,opacity=.55)+infected(260,114,.65)
r+=plus(262,52,.68)
r+=path('M137 103H288',INK,7)+arrow(139,103,289,103,BRASS,3.1,head=7)
r+=bullet(145,103,.62)
for x in [182,260]:r+=circle(x,103,5,PAPER,1.6)
r+=rail(168,145,283)
(OUT/'pierce.svg').write_text(svg(r))

# Additional projectiles visibly diverge from the same firing point.
r=infected(267,62,.65)+infected(267,146,.65)
r+=circle(143,105,5,BRASS,2,INK)
for y,angle in [(53,-25),(137,16)]:
    r+=line(146,105,252,y,DIM,1.8)+bullet(205,(105+y)/2,.90,angle)
r+=path('M162 90L171 85M161 119L171 124',BRASS,2.3)
(OUT/'multi.svg').write_text(svg(r))

# Linked targets receive bent electric jumps rather than physical cartridges.
r=''
for x,y,s in [(161,134,.59),(215,65,.59),(271,139,.59)]:r+=infected(x,y,s)
r+=bolt([(137,112),(150,108),(155,124),(162,124)])
r+=bolt([(166,116),(178,96),(190,99),(192,79),(212,61)])
r+=bolt([(221,64),(241,85),(234,101),(255,119),(270,128)])
for x,y in [(161,123),(215,58),(271,128)]:r+=circle(x,y,6,PAPER,1.5)
(OUT/'chain.svg').write_text(svg(r))

# Directly killed target is the origin of exactly one burst.
r=infected(280,115,.62)+line(133,109,181,109,DIM,1.8)+bullet(150,109,.68)
r+=burst(217,110,48,RUST)+burst(217,110,30,BRASS)+infected(216,116,.48,dead=True)
r+=path('M208 72L215 85M249 94L239 98M240 141L232 131M194 130L200 123',PAPER,2.4)
r+=path('M271 83L260 88M272 151L261 143',RUST,2.2)
(OUT/'blast.svg').write_text(svg(r))

# Radius changes the extent around a single origin, with no extra blast generations.
r=circle(215,104,66,BRASS,2.8)+circle(215,104,34,DIM,2,extra='stroke-dasharray="4 5"')
r+=burst(215,104,21,RUST)+burst(215,104,11,BRASS)
r+=infected(156,122,.49)+infected(274,116,.49)
r+=arrow(237,80,260,57,BRASS,2.4,head=6)+arrow(195,129,174,152,BRASS,2.4,head=6)
r+=path('M215 34V43M215 166V175',BRASS,2)
(OUT/'blast_radius.svg').write_text(svg(r))

# Three diminishing, separated bursts represent the initial kill and two generations.
r=''
for x,y,rad,s in [(151,84,35,.34),(218,137,28,.29),(273,70,20,.24)]:
    r+=burst(x,y,rad,RUST)+burst(x,y,rad*.64,BRASS)+infected(x,y+1,s,dead=True)
r+=arrow(176,110,194,124,BRASS,2.5,head=6)+arrow(239,114,257,90,BRASS,2.3,head=5)
r+=path('M139 136L151 144L163 136M211 175L219 180L227 175M268 103L275 107L282 103',DIM,1.5)
(OUT/'cascade.svg').write_text(svg(r))

# Weak-point acquisition: three aiming traces converge on a head, not a damage burst.
r=infected(230,116,1.23)+crosshair(231,76,24)+circle(231,76,7,PAPER,1.9)
r+=path('M145 128L211 88M145 102L206 78M147 74L207 72',DIM,1.7,extra='stroke-dasharray="4 4"')
r+=path('M241 45L253 36H280M262 84H282M180 152L205 152',BRASS,1.7)
r+=rail(174,164,283)
(OUT/'crit.svg').write_text(svg(r))

# Same weak point, but a larger fractured impact rather than more aiming chances.
r=infected(230,116,1.23)+line(144,130,226,82,DIM,1.7)+bullet(173,113,1.05,-29)
r+=burst(231,76,38,BRASS)+crosshair(231,76,15,PAPER)
r+=path('M228 63L236 73L226 81L238 91',INK,3)
r+=path('M193 45L181 34M267 42L281 31M270 103L284 112M197 108L185 118',BRASS,2.6)
r+=rail(174,164,283)
(OUT/'critpower.svg').write_text(svg(r))

# Three physically separated armor plates and a deflected incoming round.
r=''
for x,y,color in [(162,76,DIM),(182,61,BRASS),(205,46,PAPER)]:
    r+=path(f'M{x} {y}L{x+36} {y+9}V{y+50}Q{x+36} {y+70} {x+18} {y+84}Q{x} {y+68} {x} {y+48}Z',color,2.4,INK)
    r+=line(x+8,y+16,x+28,y+21,DIM,1.2)
r+=bullet(273,87,.83,180,color=RUST)
r+=path('M246 91L257 77M248 97L266 100M244 103L257 117',BRASS,2.5)
r+=plus(237,160,.95)
(OUT/'armor.svg').write_text(svg(r))

# The mobile vehicle is paired with a squad silhouette and two motion paths.
r=soldier(239,76,.61)
r+=arrow(198,108,282,108,BRASS,2.8)
r+=arrow(38,179,277,179,BRASS,3.3)
r+=path('M170 143H211M178 153H220M181 162H225',BRASS,2)
r+=path('M197 64H212M191 77H210M197 90H211',DIM,1.5)
(OUT/'move.svg').write_text(svg(r))

# Same shot output, visibly less ammo spent: no return/refill loop.
r=''
for y,count,color in [(61,3,DIM),(133,2,BRASS)]:
    for i in range(count):r+=bullet(160+i*20,y,.48,-90,color)
    r+=arrow(209,y,243,y,color,2.0,head=5)
    r+=bullet(267,y,.78,color=BRASS)
    r+=path(f'M147 {y+23}H201M147 {y+18}V{y+23}M201 {y+18}V{y+23}',color,1.6)
r+=path('M208 98H224',GREEN,3.1)
r+=arrow(216,82,216,114,GREEN,2.1,head=5)
(OUT/'supply.svg').write_text(svg(r))

# Rusted structure is dismantled into usable salvaged crates.
r=path('M152 108L171 79L184 87L198 57L213 78L231 72L245 107Z',INK,2,DIM)
r+=path('M163 103L179 90L183 105M199 68L209 89L202 104M222 81L229 101',INK,2.2)
r+=path('M184 69L180 57M211 52L219 40M227 63L241 57',BRASS,2.1)
r+=arrow(196,119,222,143,BRASS,2.5,head=6)+crate(250,153,.85)
r+=path('M149 151L166 139L175 148L159 160Z',BRASS,1.5,INK)+path('M175 162L182 154L187 161L180 169Z',BRASS,1.5,INK)
r+=rail(182,152,284)
r+=circle(263,48,20,BRASS,2.4,INK)+path('M263 35V48L273 53',PAPER,2.1)
r+=path('M233 37L241 45L233 53M224 37L232 45L224 53',BRASS,2.2)
(OUT/'salvage.svg').write_text(svg(r))

# Power storage/capacity is represented by filled physical cells, without enemy arcs.
r=''
for x,y,s,fill_count in [(170,116,.72,1),(221,110,.86,3),(270,103,.96,3)]:
    cell=path('M-18 -40H-7V-48H7V-40H18V37H-18Z',BRASS,2.1,INK)
    for i,yy in enumerate([-27,-8,11]):cell+=rect(-12,yy,24,12,BRASS,.8,BRASS if i>=3-fill_count else DIM)
    r+=group(cell,x,y,s)
r+=arrow(156,49,281,33,BRASS,2.5,head=6)+rail(165,155,285)
(OUT/'power.svg').write_text(svg(r))

# Alarm pressure is the trigger for boosted attack force.
r=path('M198 82V60Q198 34 221 34Q244 34 244 60V82ZM191 82H251V91H191Z',INK,2,RUST)
r+=path('M208 62Q208 46 218 44',PAPER,2)
r+=path('M185 42Q169 61 184 81M258 42Q275 61 259 81',RUST,2.5)
r+=arrow(220,99,220,116,BRASS,2.5,head=5)
r+=bullet(216,141,1.45)+burst(263,141,21)
r+=rail(178,158,284)
(OUT/'overload.svg').write_text(svg(r))

# A counted shot sequence triggers one broad free battery lane.
r=''
for x in [157,211,266]:r+=infected(x,132,.58)
r+=path('M135 110H275L290 121L275 132H135',BRASS,1.5,extra='opacity=".40"')
r+=arrow(137,121,288,121,BRASS,4.1,head=8)
for i in range(6):r+=bullet(150+i*24,52,.49,color=BRASS if i==5 else DIM)
r+=circle(270,52,12,BRASS,1.8)+path('M270 67V86L280 96',BRASS,1.8)
r+=rail(172,146,285)
(OUT/'salvo.svg').write_text(svg(r))

# Each broad lane can cross six foes; added lane is not a three-target limit.
r=''
for y in [65,143]:
    for x in [151,177,203,229,255,281]:r+=infected(x,y,.31)
for y in [57,135]:
    r+=path(f'M133 {y-9}H276L291 {y}L276 {y+9}H133',BRASS,1.5,extra='opacity=".38"')
    r+=arrow(135,y,288,y,BRASS,4,head=7)
r+=path('M138 57H145V135H138',PAPER,1.7)+rail(183,143,286)
(OUT/'sweep.svg').write_text(svg(r))

# A fixed supply area continuously sustains both crews and defensive structures.
r=f'<ellipse cx="169" cy="112" rx="121" ry="68" fill="none" stroke="{GREEN}" stroke-width="2.1"/>'
r+=soldier(201,127,.53)+tower(260,132,.52)
r+=plus(194,68,.80)+plus(259,75,.80)
r+=path('M183 163Q205 174 220 163M231 167Q259 177 274 155',GREEN,2)
r+=path('M124 67L147 62M142 156L163 165',GREEN,1.9,extra='stroke-dasharray="3 5"')
(OUT/'repair.svg').write_text(svg(r))

# Kills feed the production building, rather than a generic economy resource pile.
r=infected(178,54,.42,dead=True)+infected(246,54,.42,dead=True)
r+=path('M163 41L191 69M231 41L259 69',DIM,1.4)
r+=arrow(211,70,211,88,BRASS,2.5,head=5)
r+=path('M153 172H262',BRASS,1.8)
r+=path('M236 166L245 172L236 178M252 166L261 172L252 178M267 166L276 172L267 178',BRASS,2.3)
r+=hourglass(279,36,.9)
(OUT/'economy.svg').write_text(svg(r))

# Additional electric target and charged-fence web, visibly richer than a simple chain.
r=''
for x,y in [(151,107),(204,58),(262,106),(208,153)]:r+=infected(x,y,.47)
for pts in [[(153,98),(172,75),(184,83),(202,51)],[(209,54),(231,62),(226,79),(260,98)],[(260,106),(253,128),(231,124),(211,144)],[(203,143),(179,140),(181,122),(151,101)]]:r+=bolt(pts,2.6)
for x,y in [(134,48),(282,53),(281,162),(140,162)]:r+=path(f'M{x} {y+11}V{y-10}M{x-5} {y-5}H{x+5}M{x-5} {y+2}H{x+5}',PAPER,2.3)
r+=path('M136 48L151 35L173 42M283 69L274 79L284 90M149 175L162 181L176 175',ELECTRIC,2)
(OUT/'storm.svg').write_text(svg(r))

# Truck-carried moving coverage includes a fighting squad, with direction underneath.
r=f'<ellipse cx="157" cy="111" rx="134" ry="65" fill="none" stroke="{GREEN}" stroke-width="2.3"/>'
r+=soldier(256,123,.58)+bullet(263,69,.76)
r+=path('M224 139L231 144L240 137',GREEN,2)
r+=arrow(36,185,278,185,BRASS,3.1)
r+=path('M44 38H88M35 48H77M47 58H91',BRASS,1.8)
(OUT/'fortress.svg').write_text(svg(r))

# A one-off material delivery is stock, rather than ammo reuse or healing.
r=crate(188,137,.84)+crate(246,139,.87)+crate(217,92,.80)
r+=plus(265,57,.93,BRASS)+rail(176,161,283)
(OUT/'reserve.svg').write_text(svg(r))

# Full restoration has no radius: crews, tower and vehicle all receive the burst.
r=plus(217,61,1.57)
r+=soldier(164,127,.43)+tower(220,126,.43)
r+=path('M255 113H276V130H255ZM276 119H285L291 126V132H276Z',INK,1.5,PAPER)
r+=circle(261,135,5,INK,1.5,PAPER)+circle(284,135,5,INK,1.5,PAPER)
for x in [166,221,276]:
    r+=rect(x-15,163,30,6,GREEN,1,GREEN)
    r+=arrow(x,87,x,102,GREEN,2,head=4)
r+=path('M155 51L166 59M273 51L262 59',GREEN,2)
(OUT/'field_repair.svg').write_text(svg(r))

# A temporary whole-factory push emits crew and structure production in parallel.
r=path('M139 104H170V66H211M169 104V143H211',BRASS,2.6)
r+=path('M202 60L212 66L202 72M202 137L212 143L202 149',BRASS,2.6)
r+=soldier(252,64,.54)+tower(250,145,.53)
r+=path('M151 175L160 182L151 189M168 175L177 182L168 189M185 175L194 182L185 189',BRASS,2.4)
r+=hourglass(184,36,1.0)
(OUT/'reserve2.svg').write_text(svg(r))

MECHANICS={
 'damage':'Larger direct round and impact force; no weak-point reticle.',
 'rate':'Equal firing intervals show sparse versus dense sequential rounds; no electricity.',
 'range':'A receding old reach limit and extended targeting arc.',
 'pierce':'One straight projectile trajectory through successive foes; no secondary bursts.',
 'blast_radius':'One blast origin with a larger radial extent and outward arrows.',
 'crit':'Multiple aiming traces acquire the same head weak point.',
 'armor':'Three layered physical plates deflect a round; recovery mark accompanies added durability.',
 'move':'Truck and squad context move forward on parallel directional paths.',
 'supply':'The same projectile output uses fewer consumed cartridges, without a replenishment arrow.',
 'salvage':'Resource collection gains a fast-clock cue; output crate count is unchanged.',
 'build':'Worker and real production building with long-to-short assembly interval.',
 'power':'Larger physical energy-cell capacity with more filled storage.',
 'multi':'Additional physical rounds diverge from one firing point toward separate targets.',
 'chain':'Bent electric links visit three human targets in sequence.',
 'blast':'Directly killed central foe creates one burst that reaches a neighboring foe.',
 'critpower':'Same acquired weak point produces a larger fractured impact.',
 'overload':'Alarm pressure triggers a stronger direct round.',
 'salvo':'A six-round firing sequence triggers one broad tower battery lane.',
 'repair':'A stationary supply coverage area sustains both crew and tower.',
 'economy':'Defeated foes feed a production building and accelerate its output.',
 'storm':'Four electric targets form a charged fence network.',
 'cascade':'Initial burst and two diminishing subsequent blast generations.',
 'sweep':'Two broad simultaneous lanes pierce six foes.',
 'fortress':'A mobile truck carries a coverage area around a fighting squad.',
 'reserve':'Immediate replenishment of material stocks.',
 'field_repair':'One full restoration reaches crew, tower and vehicle without a supply-radius limit.',
 'reserve2':'Parallel crew and structure production surge from the real workshop.',
}
assert len(MECHANICS)==27
assert {p.stem for p in OUT.glob('*.svg')}==set(MECHANICS)|{'backdrop'}
print(f'Wrote {len(MECHANICS)} original mechanic overlays and one shared backdrop.')
