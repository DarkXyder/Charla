# Renders the Charla app icon: python3 design/icon.py <Outfit-Bold.ttf> <out.png> [preview.png]
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import sys
S=1024; K=2; W=S*K
font, out = sys.argv[1], sys.argv[2]
img=Image.new('RGB',(W,W))
d=ImageDraw.Draw(img)
top=(255,120,84); bottom=(255,72,96)
for y in range(W):
    t=y/W
    d.line([(0,y),(W,y)],fill=tuple(int(top[i]+(bottom[i]-top[i])*t) for i in range(3)))
# warm glow top-left
g=Image.new('L',(W,W),0); ImageDraw.Draw(g).ellipse([-W*0.3,-W*0.35,W*0.75,W*0.55],fill=120)
img=Image.composite(Image.new('RGB',(W,W),(255,196,96)),img,g.filter(ImageFilter.GaussianBlur(160*K)))

def bubble(box, tail, color, shadow=True):
    global img
    m=Image.new('L',(W,W),0); md=ImageDraw.Draw(m)
    md.rounded_rectangle(box,radius=int((box[3]-box[1])*0.42),fill=255)
    md.polygon(tail,fill=255)
    if shadow:
        sh=m.filter(ImageFilter.GaussianBlur(26*K)).point(lambda v:int(v*0.35))
        sh=sh.transform((W,W),Image.AFFINE,(1,0,-10*K,0,1,-22*K))  # soft drop shadow, down-right
        img=Image.composite(Image.new('RGB',(W,W),(120,20,30)),img,sh)
    img=Image.composite(Image.new('RGB',(W,W),color),img,m)

# small teal bubble behind (the reply)
bubble([W*0.47,W*0.20,W*0.86,W*0.47],[(W*0.74,W*0.45),(W*0.82,W*0.56),(W*0.66,W*0.46)],(0,158,153))
# main white bubble
bubble([W*0.12,W*0.36,W*0.80,W*0.74],[(W*0.24,W*0.70),(W*0.18,W*0.86),(W*0.38,W*0.72)],(255,255,255))
d=ImageDraw.Draw(img)
f=ImageFont.truetype(font,int(150*K))
t="¡Hola!"; b=d.textbbox((0,0),t,font=f)
d.text((W*0.46-(b[2]-b[0])/2-b[0], W*0.55-(b[3]-b[1])/2-b[1]),t,font=f,fill=(255,92,80))
# dots in the teal bubble ("typing a reply")
for i in range(3):
    cx=W*(0.585+i*0.075); cy=W*0.335; r=W*0.022
    d.ellipse([cx-r,cy-r,cx+r,cy+r],fill=(255,255,255))
img=img.resize((S,S),Image.LANCZOS)
img.save(out)
if len(sys.argv)>3:
    p=img.resize((380,380),Image.LANCZOS)
    m=Image.new('L',(380,380),0); ImageDraw.Draw(m).rounded_rectangle([0,0,379,379],radius=85,fill=255)
    o=Image.new('RGB',(420,420),(242,242,247)); o.paste(p,(20,20),m); o.save(sys.argv[3])
