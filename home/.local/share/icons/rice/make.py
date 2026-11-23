import os
OUT='rice/scalable/places'
# Ordner: hinten hellgrau mit Lasche, vorne weiss. 64x64.
BACK='<path d="M10 10h13.2a3 3 0 0 1 2.1.9L29 14.6a3 3 0 0 0 2.1.9H54a4 4 0 0 1 4 4V50a4 4 0 0 1-4 4H10a4 4 0 0 1-4-4V14a4 4 0 0 1 4-4z" fill="#cfcfcf"/>'
FRONT='<rect x="6" y="21" width="52" height="33" rx="4" fill="#ffffff"/>'
G='fill="none" stroke="#1c1c1c" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"'
GF='fill="#1c1c1c"'
glyphs={
 'folder':'',
 'folder-download':f'<path d="M32 30v12M26.5 37l5.5 5.5 5.5-5.5M25 46.5h14" {G}/>',
 'folder-documents':f'<path d="M25 32h14M25 37.5h14M25 43h9" {G}/>',
 'folder-music':f'<path d="M30 43.5V31l9-2v12" {G}/><circle cx="27.5" cy="43.5" r="2.8" {GF}/><circle cx="36.5" cy="41" r="2.8" {GF}/>',
 'folder-pictures':f'<path d="M24 45l6-7 4 4.5 2.5-3L41 45z" {GF}/><circle cx="37" cy="32.5" r="2.4" {GF}/>',
 'folder-videos':f'<path d="M28.5 30.5v14l11.5-7z" {GF} stroke="#1c1c1c" stroke-width="1.5" stroke-linejoin="round"/>',
 'user-home':f'<path d="M25 46V37.5l7-6 7 6V46h-5v-5.5h-4V46z" {GF} stroke="#1c1c1c" stroke-width="1.5" stroke-linejoin="round"/>',
 'user-desktop':f'<rect x="24" y="30" width="16" height="11" rx="1.5" {G}/><path d="M29 46h6M32 41v5" {G}/>',
 'folder-publicshare':f'<circle cx="27" cy="37.5" r="2.6" {GF}/><circle cx="37" cy="32" r="2.6" {GF}/><circle cx="37" cy="43" r="2.6" {GF}/><path d="M27 37.5L37 32M27 37.5L37 43" {G}/>',
 'folder-templates':f'<rect x="26" y="30" width="12" height="15" rx="1.5" {G} stroke-dasharray="3 2.6"/>',
 'folder-remote':f'<circle cx="32" cy="38" r="7.5" {G}/><path d="M24.5 38h15M32 30.5c-3 3-3 12 0 15M32 30.5c3 3 3 12 0 15" {G}/>',
}
alias={'folder':['folder','inode-directory','folder-visiting','folder-drag-accept','folder-saved-search','folder-recent','folder-new'],
       'folder-download':['folder-download'],'folder-documents':['folder-documents'],'folder-music':['folder-music'],
       'folder-pictures':['folder-pictures'],'folder-videos':['folder-videos'],'user-home':['user-home','folder-home'],
       'user-desktop':['user-desktop','folder-desktop'],'folder-publicshare':['folder-publicshare'],
       'folder-templates':['folder-templates'],'folder-remote':['folder-remote','network-workgroup']}
for k,g in glyphs.items():
    svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">{BACK}{FRONT}{g}</svg>\n'
    for name in alias[k]:
        open(os.path.join(OUT,name+'.svg'),'w').write(svg)
# offen = gleich wie zu
open(os.path.join(OUT,'folder-open.svg'),'w').write(open(os.path.join(OUT,'folder.svg')).read())
open('rice/index.theme','w').write('''[Icon Theme]
Name=rice
Comment=Adwaita, nur Ordner weiss und gefuellt (passend zum Rice)
Inherits=Adwaita,hicolor
Directories=scalable/places

[scalable/places]
Context=Places
Size=64
MinSize=8
MaxSize=512
Type=Scalable
''')
print(sorted(os.listdir(OUT)))
