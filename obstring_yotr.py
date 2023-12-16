import matplotlib.pyplot as mpl
import matplotlib.colors as colors
import matplotlib.cm as cmx

from matplotlib.patches import Polygon
from matplotlib.collections import PatchCollection

import numpy as np

COLORS = ['orange', 'yellow', 'green', 'blue', 'darkblue', 'lightgray', 'dimgray']
T = 256
t = 128
w = 32


def round(num):
    return int(num+0.5)


def rotate(point, origin, degrees):
    if round(degrees) == 0:
        return point
    radians = np.deg2rad(degrees)
    (x, y)  = point
    offset_x, offset_y = origin
    adjusted_x = (x - offset_x)
    adjusted_y = (y - offset_y)
    cos_rad = np.cos(radians)
    sin_rad = np.sin(radians)
    qx = offset_x + cos_rad * adjusted_x + sin_rad * adjusted_y
    qy = offset_y + -sin_rad * adjusted_x + cos_rad * adjusted_y
    return (round(qx), round(qy))

# t1=(x,y,w,h,col)


#
# ob 1
#
OB_DATA = {}
OB_DATA['tile'] = {'t1':(  0,   0, 8, 8, 1),
                   't2':(128, 256, 8, 8, 2),
                   't3':(256, 512, 8, 8, 1),
                   't4':(384, 768, 8, 8, 2),
                   't5':(512, 512, 8, 8, 1),
                   't6':(640, 256, 8, 8, 2),
                   't7':(768,   0, 8, 8, 1)}
OB_DATA['exp'] = [[[1,           ], 32],
                  [[  2,         ], 32],
                  [[    3,       ], 32],
                  [[      4,     ], 32],
                  [[        5,   ], 32],
                  [[          6, ], 32],
                  [[            7], 128],
                  [[    3,4,5,   ], 64],
                  [[1,2,      6,7], 64],
                  [[    3,4,5,   ], 128],
                  [[1,2,3,  5,6,7], 128]]

tiles = OB_DATA['tile']

for k in tiles.keys():
    tp = (tiles[k][0], tiles[k][1])
    newp = rotate(tp, (0,0), 0)
    tiles[k] = (newp[0], newp[1], tiles[k][2], tiles[k][3], tiles[k][4])
lexico_tile = sorted([(int(n[1:]),n) for n in tiles.keys()])

# plotting
polygons = []
all_x    = []
all_y    = []
p_text   = []
p_col    = []
for i in range(len(lexico_tile)):
    ct = tiles[lexico_tile[i][1]]
    my_box = [[ct[0],ct[1]], [ct[0]+w*ct[2],ct[1]], [ct[0]+w*ct[2],ct[1]+w*ct[3]], [ct[0],ct[1]+w*ct[3]]]
    all_x.extend([n[0] for n in my_box])
    all_y.extend([n[1] for n in my_box])
    polygons.append(Polygon(np.array(my_box), closed=True))
    p_text.append([my_box[3][0]+16, my_box[3][1]-44, lexico_tile[i][1]])
    p_col.append(COLORS[ct[4]-1])
fig = mpl.figure(0,figsize=(10,10))
ax  = mpl.gca()
for i in range(len(polygons)):
    ax.add_collection(PatchCollection([polygons[i]], alpha=0.7, color=p_col[i]))
mpl.axis([min(all_x)-T, max(all_x)+T, min(all_y)-T, max(all_y)+T])
ax.set_aspect('equal', 'box')
for i in range(len(p_text)):
    mpl.text(p_text[i][0], p_text[i][1], p_text[i][2], ha='left', fontsize=10)
mpl.show()

t_out = ';'.join(f'{k}=({v[0]},{v[1]},{v[2]},{v[3]},{v[4]})' for k,v in OB_DATA['tile'].items()) + ';'
e_out = ''
for i,expdat in enumerate(OB_DATA['exp']):
    e_out += f'e{i+1}=[' + ','.join(['t'+str(n) for n in expdat[0]]) + '];'
w_out = ';'.join(f'w{i+1}={expdat[1]}' for i,expdat in enumerate(OB_DATA['exp'])) + ';'

print(t_out + e_out + w_out)