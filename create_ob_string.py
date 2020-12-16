import os
import sys
import numpy as np
import matplotlib.pyplot as mpl
import matplotlib.colors as colors
import matplotlib.cm as cmx

from matplotlib.patches import Polygon
from matplotlib.collections import PatchCollection

# absolute path to this script
SIM_PATH = '/'.join(os.path.realpath(__file__).split('/')[:-1]) + '/'
sys.path.append(SIM_PATH + 'obs/')

from doombound_02 import t, T, COLORS, OB_DATA

#
# select the ob to generate
#
tiles   = OB_DATA['ob 3']['tiles']
expList = OB_DATA['ob 3']['uv']

#
lexico_tile = sorted([(int(n[1:]),n) for n in tiles.keys()])

# plotting
polygons = []
allX     = []
allY     = []
p_text   = []
p_col    = []
for i in xrange(len(lexico_tile)):
	ct = tiles[lexico_tile[i][1]]
	if lexico_tile[i][1][0] == 't':
		myBox = [[ct[0],ct[1]], [ct[0]+T,ct[1]], [ct[0]+T,ct[1]-T], [ct[0],ct[1]-T]]
	elif lexico_tile[i][1][0] == 'T':
		myBox = [[ct[0],ct[1]], [ct[0]+ct[2]*T,ct[1]], [ct[0]+ct[2]*T,ct[1]-ct[3]*T], [ct[0],ct[1]-ct[3]*T]]
	allX.extend([n[0] for n in myBox])
	allY.extend([n[1] for n in myBox])
	polygons.append(Polygon(np.array(myBox), closed=True))
	p_text.append([myBox[0][0]+16, myBox[0][1]-72, lexico_tile[i][1]])
	p_col.append(COLORS[ct[5]-1])
fig = mpl.figure(0,figsize=(10,10))
ax  = mpl.gca()
for i in xrange(len(polygons)):
	ax.add_collection(PatchCollection([polygons[i]], alpha=0.7, color=p_col[i]))
mpl.axis([min(allX)-T, max(allX)+T, min(allY)-T, max(allY)+T])
ax.set_aspect('equal', 'box')
for i in range(len(p_text)):
	mpl.text(p_text[i][0], p_text[i][1], p_text[i][2], ha='left', fontsize=10)
#mpl.show()

#
# super-tiles --> multiple normal tiles
#
out_tiles = {}
tile_imap = {}
adj = 0
for i in xrange(len(lexico_tile)):
	print lexico_tile[i]
	if lexico_tile[i][1][0] == 't':
		ct = tiles[lexico_tile[i][1]]
		newName = 't'+str(lexico_tile[i][0]+adj)
		tile_imap[lexico_tile[i][1]] = [newName]
		out_tiles[newName] = (ct[0], ct[1], ct[4], ct[5])
	elif lexico_tile[i][1][0] == 'T':
		for j in xrange(tiles[lexico_tile[i][1]][2]):
			for k in xrange(tiles[lexico_tile[i][1]][3]):
				myBorder = 0
				if tiles[lexico_tile[i][1]][4] == 15:	# add border if supertile border is 15
					if j == 0: myBorder += 8
					if k == 0: myBorder += 4
					if j == tiles[lexico_tile[i][1]][2]-1: myBorder += 2
					if k == tiles[lexico_tile[i][1]][3]-1: myBorder += 1
				nn0 = 't'+str(lexico_tile[i][0]+adj)
				td0 = (tiles[lexico_tile[i][1]][0]+j*T, tiles[lexico_tile[i][1]][1]-k*T, myBorder, tiles[lexico_tile[i][1]][5])
				if lexico_tile[i][1] not in tile_imap:
					tile_imap[lexico_tile[i][1]] = []
				tile_imap[lexico_tile[i][1]].append(nn0)
				out_tiles[nn0] = td0
				adj += 1
lexico_tile = sorted([(int(n[1:]),n) for n in out_tiles.keys()])

# plotting (II)
polygons = []
allX     = []
allY     = []
p_text   = []
p_col    = []
b_lines  = []
for i in xrange(len(lexico_tile)):
	ct = out_tiles[lexico_tile[i][1]]
	
	myBox = [[ct[0],ct[1]], [ct[0]+T,ct[1]], [ct[0]+T,ct[1]-T], [ct[0],ct[1]-T]]

	if ct[2]&8:
		b_lines.append([[ct[0], ct[0]], [ct[1]-T, ct[1]]])
	if ct[2]&4:
		b_lines.append([[ct[0], ct[0]+T], [ct[1], ct[1]]])
	if ct[2]&2:
		b_lines.append([[ct[0]+T, ct[0]+T], [ct[1]-T, ct[1]]])
	if ct[2]&1:
		b_lines.append([[ct[0], ct[0]+T], [ct[1]-T, ct[1]-T]])

	allX.extend([n[0] for n in myBox])
	allY.extend([n[1] for n in myBox])
	polygons.append(Polygon(np.array(myBox), closed=True))
	p_text.append([myBox[0][0]+16, myBox[0][1]-72, lexico_tile[i][1]])
	p_col.append(COLORS[ct[3]-1])
fig = mpl.figure(1,figsize=(10,10))
ax  = mpl.gca()
for i in xrange(len(polygons)):
	ax.add_collection(PatchCollection([polygons[i]], alpha=0.7, color=p_col[i]))
for i in xrange(len(b_lines)):
	mpl.plot(b_lines[i][0], b_lines[i][1], '-k', linewidth=3)
mpl.axis([min(allX)-T, max(allX)+T, min(allY)-T, max(allY)+T])
ax.set_aspect('equal', 'box')
for i in range(len(p_text)):
	print p_text[i]
	mpl.text(p_text[i][0], p_text[i][1], p_text[i][2], ha='left', fontsize=10)
mpl.show()

# parse explosions
out_exp  = []
out_wait = []
for i in xrange(len(expList)):
	out_wait.append(expList[i][1])
	temp = []
	for n in expList[i][0]:
		temp.extend(tile_imap[n])
	temp = sorted([(int(n[1:]),n) for n in temp])
	out_exp.append([n[1] for n in temp])

# write outstring
outStr = ''
for i in xrange(len(lexico_tile)):
	print lexico_tile[i][1], out_tiles[lexico_tile[i][1]]
	outStr += lexico_tile[i][1] + '=' + str(out_tiles[lexico_tile[i][1]]).replace(' ','') + ';'
for i in xrange(len(out_exp)):
	print i+1, out_exp[i], out_wait[i]
	outStr += 'e'+str(i+1) + '=' + '['+','.join(out_exp[i])+']' + ';' + 'w'+str(i+1) + '=' + str(out_wait[i]) + ';'

print ''
print outStr
print ''
