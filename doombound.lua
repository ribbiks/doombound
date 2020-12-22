---
--- doombound.lua
---
--- generates DoomBound maps from a text description of an obstacle
---

---FLAT_LIGHT_VERT  = {'LITEO2R',  'LITEY2R'}
---FLAT_LIGHT_HORZ  = {'LITEO1R',  'LITEY1R'}
FLAT_LIGHT_VERT  = {'LITER2R',  'LITER2R'}
FLAT_LIGHT_HORZ  = {'LITER1R',  'LITER1R'}
FLAT_STATIC_VERT = {'LITORG2R', 'LITYEL2R'}
FLAT_STATIC_HORZ = {'LITORG5R', 'LITYEL5R'}
TEX_SIDEDEF      = {'LITEO1RR', 'LITEY1RR'}
FLAT_MAIN_TILE   = 'ITS_RED2'
DARK_VALUE       = 96

--- HARD-CODED TAGS
TAG_HNTR_BLOCK  = 20000
TAG_HNTR_SCROLL = 20001
TAG_HMP_BLOCK   = 20002
TAG_HMP_SCROLL  = 20003
TAG_UV_BLOCK    = 20004
TAG_UV_SCROLL   = 20005
UNIVERSAL_OB_ON = 20006
OB_TRANSITION   = 20007
--- max tag = OB_TRANSITION + (# obs) x 5

--- crashes if pattern is too complex
function split_old(pString, pPattern)
	local Table = {}  -- NOTE: use {n = 0} in Lua-5.0
	local fpat = "(.-)" .. pPattern
	local last_end = 1
	local s, e, cap = pString:find(fpat, 1)
	while s do
		if s ~= 1 or cap ~= "" then
			table.insert(Table,cap)
		end
		last_end = e+1
		s, e, cap = pString:find(fpat, last_end)
	end
	if last_end <= #pString then
		cap = pString:sub(last_end)
		table.insert(Table, cap)
	end
	return Table
end

function split(s, sep)
	local fields = {}
	local sep = sep or " "
	local pattern = string.format("([^%s]+)", sep)
	string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)
	return fields
end

function spairs(t, order)
	local keys = {}
	for k in pairs(t) do keys[#keys+1] = k end
	if order then
		table.sort(keys, function(a,b) return order(t, a, b) end)
	else
		table.sort(keys)
	end
	local i = 0
	return function()
		i = i + 1
		if keys[i] then
			return keys[i], t[keys[i]]
		end
	end
end

--- returns index of linedef with specified vertex coordinates
function get_linedef_index(linedefList, vpos1, vpos2)
	for i=1, #linedefList do
		local lv1 = linedefList[#linedefList-i+1].start_vertex.position
		local lv2 = linedefList[#linedefList-i+1].end_vertex.position
		if lv1 == vpos1 and lv2 == vpos2 then return #linedefList-i+1 end
		if lv1 == vpos2 and lv2 == vpos1 then return #linedefList-i+1 end
	end
end

--- helper function to apply actions & tags to linedefs
function change_linedef(linedefList, vpos1, vpos2, newaction, newtag)
	local myLind = get_linedef_index(linedefList, vpos1, vpos2)
	linedefList[myLind].action = newaction
	linedefList[myLind].tag    = newtag
end

--- helper function to apply actions & tags to sectors
function change_sector(sectorList, centerPos, newFheight, newCheight, neweffect, newtag, newbrightness)
	for i=1, #sectorList do
		local myCenter = sectorList[i].GetCenter()
		if math.abs(myCenter.x - centerPos.x) <= 0.5 and math.abs(myCenter.y - centerPos.y) <= 0.5 then
			sectorList[i].floorheight = newFheight
			sectorList[i].ceilheight  = newCheight
			sectorList[i].effect      = neweffect
			sectorList[i].tag         = newtag
			sectorList[i].brightness  = newbrightness
		end
	end
end

-- get sector index of sector associated with front side of linedef with specified coordinates
function get_sector_index_from_linedef_coords(sectorList, linedefList, vpos1, vpos2)
	local lInd     = get_linedef_index(linedefList, vpos1, vpos2)
	local myFront  = linedefList[lInd].GetFront()
	local mySector = myFront.GetSector()
	return mySector.GetIndex()+1 --- +1 because sector indices are 0-indexed
end

function get_sector_index_from_linedef_coords_back(sectorList, linedefList, vpos1, vpos2)
	local lInd     = get_linedef_index(linedefList, vpos1, vpos2)
	local myBack  = linedefList[lInd].GetBack()
	local mySector = myBack.GetSector()
	return mySector.GetIndex()+1 --- +1 because sector indices are 0-indexed
end

UI.AddParameter("ob_string", "obstacle string", "")
UI.AddParameter("skill", "skill setting (2/3/4)", 4)
UI.AddParameter("ob_num", "obstacle number", 1)
UI.AddParameter("s_tag", "starting tag number", 1000)
UI.AddParameter("conv_x", "where to build conveyors (x)", 0)
UI.AddParameter("conv_y", "where to build conveyors (y)", -2048)
UI.AddParameter("num_sound", "number of sound objects", 1)
UI.AddParameter("only_timings", "only timings (0/1)", 0)
UI.AddParameter("draw_starts", "draw transitions (i.e. # total obs, 0=None)", 1)
parameters = UI.AskForParameters()

STARTING_TAG   = tonumber(parameters.s_tag)
ONLY_TIMINGS   = tonumber(parameters.only_timings)
SKILL_SETTING  = tonumber(parameters.skill)
OB_NUMBER      = tonumber(parameters.ob_num)
NUM_SOUND      = tonumber(parameters.num_sound)
DRAW_STARTS    = tonumber(parameters.draw_starts)
OB_GLOBAL_TAG  = OB_TRANSITION + (OB_NUMBER-1)*5
--- voodoo conveyor specs
CONVEYOR_SPEED  = 256
EXP_TO_FLOORUP  = 48
EXP_TO_LIGHTUP  = 52
EXP_TO_SOUNDON  = 56
EXP_TO_SOUNDOFF = 74
--- explosion conveyor specs
EXP_CONV_SPEED    = 512
EXP_CONV_OFFSET_X = tonumber(parameters.conv_x)
EXP_CONV_OFFSET_Y = tonumber(parameters.conv_y)
EXP_CLOSET_WIDTH  = 128
MIN_REFIRE_WAIT   = 96
--- tile specs
TILE_SIZE     = 256
TILE_FLOOR    = 0
TILE_CEILING  = 128
KEEN_CEILING  = 32
TAGS_PER_TILE = 5

s = tostring(parameters.ob_string)
---s = "t1=(0,0);t2=(0,256);t3=(0,512);e1=[t2,t3];w1=160;e2=[t1,t3];w2=160;e3=[t1,t2];w3=320;"

---
--- (x,y) are coordinates of the TOP-LEFT corner of the tile!!!
---
--- TAG_OFFSET + 0 = primary tile sector
--- TAG_OFFSET + 1 = backup teleport sector
--- TAG_OFFSET + 2 = keen cubby
--- TAG_OFFSET + 3 = burning-barrel conveyor
--- TAG_OFFSET + 4 = burning-barrel blocking sector
function draw_tile(x, y, border_num, color_num, noise_id, TAG_OFFSET)
	local p = Pen.From(x,y)
	p.snaptogrid  = false
	p.stitchrange = 1
	--- border
	p.DrawVertexAt(Vector2D.From(x,y))
	p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y))
	p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-TILE_SIZE))
	p.DrawVertexAt(Vector2D.From(x,y-TILE_SIZE))
	p.DrawVertexAt(Vector2D.From(x,y))
	p.FinishPlacingVertices()
	--- primary tele lines
	local v1 = Vector2D.From(x+TILE_SIZE/2+16, y-TILE_SIZE/2-8)
	local v2 = Vector2D.From(x+TILE_SIZE/2-16, y-TILE_SIZE/2-8)
	p.DrawVertexAt(v1)
	p.DrawVertexAt(v2)
	p.FinishPlacingVertices()
	p.DrawVertexAt(v1+Vector2D.From(0,-8))
	p.DrawVertexAt(v2+Vector2D.From(0,-8))
	p.FinishPlacingVertices()
	--- texturize & tag tile now, for convenience
	local allSectors  = Map.GetSectors()
	local allLinedefs = Map.GetLinedefs()
	local sInd = get_sector_index_from_linedef_coords(allSectors, allLinedefs, v1, v2)
	allSectors[sInd].floortex = FLAT_MAIN_TILE
	allSectors[sInd].ceiltex  = FLAT_MAIN_TILE
	change_sector(allSectors, Vector2D.From(x+TILE_SIZE/2, y-TILE_SIZE/2), TILE_FLOOR, TILE_CEILING, 8, TAG_OFFSET, DARK_VALUE)
	--- backup tele lines
	local v3 = Vector2D.From(x+TILE_SIZE/2+16+64,y-TILE_SIZE/2-8)
	local v4 = Vector2D.From(x+TILE_SIZE/2-16+64,y-TILE_SIZE/2-8)
	p.DrawVertexAt(v3)
	p.DrawVertexAt(v4)
	p.FinishPlacingVertices()
	p.DrawVertexAt(v3+Vector2D.From(0,-8))
	p.DrawVertexAt(v4+Vector2D.From(0,-8))
	p.FinishPlacingVertices()
	p.DrawVertexAt(v3)
	p.DrawVertexAt(v3+Vector2D.From(0,16))
	p.DrawVertexAt(v4+Vector2D.From(0,16))
	p.DrawVertexAt(v4)
	p.FinishPlacingVertices()
	--- keen cubby
	local v5 = Vector2D.From(x+TILE_SIZE/2+24, y-TILE_SIZE/2+8)
	if noise_id > 0 then
		p.DrawVertexAt(v5)
		p.DrawVertexAt(v5+Vector2D.From(0,-16))
		p.DrawVertexAt(v5+Vector2D.From(16,-16))
		p.DrawVertexAt(v5+Vector2D.From(16,0))
		p.DrawVertexAt(v5)
		p.FinishPlacingVertices()
	end
	---
	--- colored borders, this is gonna be a serious ordeal!!!
	---
	if border_num == 1 then
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x,y-TILE_SIZE+8))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x,y-TILE_SIZE+24))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x,y-TILE_SIZE+32))
		p.FinishPlacingVertices()
		allSectors  = Map.GetSectors()
		allLinedefs = Map.GetLinedefs()
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+8), Vector2D.From(x,y-TILE_SIZE+8))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+32), Vector2D.From(x,y-TILE_SIZE+32))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+24), Vector2D.From(x,y-TILE_SIZE+24))
		allSectors[sind].floortex   = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
	elseif border_num == 2 then
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE))
		p.FinishPlacingVertices()
		allSectors  = Map.GetSectors()
		allLinedefs = Map.GetLinedefs()
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-8,y), Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-32,y), Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-24,y), Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE))
		allSectors[sind].floortex   = FLAT_STATIC_VERT[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_VERT[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
	elseif border_num == 3 then
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x,y-TILE_SIZE+8))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x,y-TILE_SIZE+24))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x,y-TILE_SIZE+32))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-0,y-TILE_SIZE+0))
		p.FinishPlacingVertices()
		allSectors  = Map.GetSectors()
		allLinedefs = Map.GetLinedefs()
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-8,y), Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE+8))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-32,y), Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE+32))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-24,y), Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE+24))
		allSectors[sind].floortex   = FLAT_STATIC_VERT[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_VERT[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x,y-TILE_SIZE+8), Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE+8))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x,y-TILE_SIZE+32), Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE+32))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x,y-TILE_SIZE+24), Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE+24))
		allSectors[sind].floortex   = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
	elseif border_num == 4 then
		p.DrawVertexAt(Vector2D.From(x,y-8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-8))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x,y-24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-24))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x,y-32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-32))
		p.FinishPlacingVertices()
		allSectors  = Map.GetSectors()
		allLinedefs = Map.GetLinedefs()
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x,y-8), Vector2D.From(x+TILE_SIZE,y-8))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x,y-32), Vector2D.From(x+TILE_SIZE,y-32))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x,y-24), Vector2D.From(x+TILE_SIZE,y-24))
		allSectors[sind].floortex   = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
	elseif border_num == 5 then
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x,y-TILE_SIZE+8))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x,y-TILE_SIZE+24))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x,y-TILE_SIZE+32))
		p.FinishPlacingVertices()
		allSectors  = Map.GetSectors()
		allLinedefs = Map.GetLinedefs()
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+8), Vector2D.From(x,y-TILE_SIZE+8))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+32), Vector2D.From(x,y-TILE_SIZE+32))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+24), Vector2D.From(x,y-TILE_SIZE+24))
		allSectors[sind].floortex   = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
		p.DrawVertexAt(Vector2D.From(x,y-8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-8))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x,y-24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-24))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x,y-32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-32))
		p.FinishPlacingVertices()
		allSectors  = Map.GetSectors()
		allLinedefs = Map.GetLinedefs()
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x,y-8), Vector2D.From(x+TILE_SIZE,y-8))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x,y-32), Vector2D.From(x+TILE_SIZE,y-32))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x,y-24), Vector2D.From(x+TILE_SIZE,y-24))
		allSectors[sind].floortex   = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
	elseif border_num == 6 then
		p.DrawVertexAt(Vector2D.From(x,y-8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x,y-24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x,y-32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-0,y-0))
		p.FinishPlacingVertices()
		allSectors  = Map.GetSectors()
		allLinedefs = Map.GetLinedefs()
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x,y-8), Vector2D.From(x+TILE_SIZE-8,y-8))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x,y-32), Vector2D.From(x+TILE_SIZE-32,y-32))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x,y-24), Vector2D.From(x+TILE_SIZE-24,y-24))
		allSectors[sind].floortex   = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE), Vector2D.From(x+TILE_SIZE-8,y-8))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE), Vector2D.From(x+TILE_SIZE-32,y-32))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE), Vector2D.From(x+TILE_SIZE-24,y-24))
		allSectors[sind].floortex   = FLAT_STATIC_VERT[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_VERT[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
	elseif border_num == 7 then
		p.DrawVertexAt(Vector2D.From(x,y-8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x,y-TILE_SIZE+8))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x,y-24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x,y-TILE_SIZE+24))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x,y-32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x,y-TILE_SIZE+32))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-0,y-0))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-0,y-TILE_SIZE+0))
		p.FinishPlacingVertices()
		allSectors  = Map.GetSectors()
		allLinedefs = Map.GetLinedefs()
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x,y-8), Vector2D.From(x+TILE_SIZE-8,y-8))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x,y-32), Vector2D.From(x+TILE_SIZE-32,y-32))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x,y-24), Vector2D.From(x+TILE_SIZE-24,y-24))
		allSectors[sind].floortex   = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE+8), Vector2D.From(x+TILE_SIZE-8,y-8))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE+32), Vector2D.From(x+TILE_SIZE-32,y-32))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE+24), Vector2D.From(x+TILE_SIZE-24,y-24))
		allSectors[sind].floortex   = FLAT_STATIC_VERT[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_VERT[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE+8), Vector2D.From(x,y-TILE_SIZE+8))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE+32), Vector2D.From(x,y-TILE_SIZE+32))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE+24), Vector2D.From(x,y-TILE_SIZE+24))
		allSectors[sind].floortex   = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
	elseif border_num == 8 then
		p.DrawVertexAt(Vector2D.From(x+8,y-TILE_SIZE))
		p.DrawVertexAt(Vector2D.From(x+8,y))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+24,y-TILE_SIZE))
		p.DrawVertexAt(Vector2D.From(x+24,y))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+32,y-TILE_SIZE))
		p.DrawVertexAt(Vector2D.From(x+32,y))
		p.FinishPlacingVertices()
		allSectors  = Map.GetSectors()
		allLinedefs = Map.GetLinedefs()
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+8,y-TILE_SIZE), Vector2D.From(x+8,y))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+32,y-TILE_SIZE), Vector2D.From(x+32,y))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+24,y-TILE_SIZE), Vector2D.From(x+24,y))
		allSectors[sind].floortex   = FLAT_STATIC_VERT[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_VERT[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
	elseif border_num == 9 then
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x+8,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x+8,y))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x+24,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x+24,y))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x+32,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x+32,y))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+32,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x+24,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x+8,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x+0,y-TILE_SIZE+0))
		p.FinishPlacingVertices()
		allSectors  = Map.GetSectors()
		allLinedefs = Map.GetLinedefs()
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+8), Vector2D.From(x+8,y-TILE_SIZE+8))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+32), Vector2D.From(x+32,y-TILE_SIZE+32))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+24), Vector2D.From(x+24,y-TILE_SIZE+24))
		allSectors[sind].floortex   = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+8,y), Vector2D.From(x+8,y-TILE_SIZE+8))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+32,y), Vector2D.From(x+32,y-TILE_SIZE+32))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+24,y), Vector2D.From(x+24,y-TILE_SIZE+24))
		allSectors[sind].floortex   = FLAT_STATIC_VERT[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_VERT[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
	elseif border_num == 10 then
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE))
		p.FinishPlacingVertices()
		allSectors  = Map.GetSectors()
		allLinedefs = Map.GetLinedefs()
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-8,y), Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-32,y), Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-24,y), Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE))
		allSectors[sind].floortex   = FLAT_STATIC_VERT[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_VERT[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
		p.DrawVertexAt(Vector2D.From(x+8,y-TILE_SIZE))
		p.DrawVertexAt(Vector2D.From(x+8,y))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+24,y-TILE_SIZE))
		p.DrawVertexAt(Vector2D.From(x+24,y))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+32,y-TILE_SIZE))
		p.DrawVertexAt(Vector2D.From(x+32,y))
		p.FinishPlacingVertices()
		allSectors  = Map.GetSectors()
		allLinedefs = Map.GetLinedefs()
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+8,y-TILE_SIZE), Vector2D.From(x+8,y))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+32,y-TILE_SIZE), Vector2D.From(x+32,y))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+24,y-TILE_SIZE), Vector2D.From(x+24,y))
		allSectors[sind].floortex   = FLAT_STATIC_VERT[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_VERT[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
	elseif border_num == 11 then
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x+8,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x+8,y))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x+24,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x+24,y))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x+32,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x+32,y))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-0,y-TILE_SIZE+0))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+32,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x+24,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x+8,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x+0,y-TILE_SIZE+0))
		p.FinishPlacingVertices()
		allSectors  = Map.GetSectors()
		allLinedefs = Map.GetLinedefs()
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-8,y), Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE+8))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-32,y), Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE+32))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-24,y), Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE+24))
		allSectors[sind].floortex   = FLAT_STATIC_VERT[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_VERT[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+8,y-TILE_SIZE+8), Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE+8))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+32,y-TILE_SIZE+32), Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE+32))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+24,y-TILE_SIZE+24), Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE+24))
		allSectors[sind].floortex   = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+8,y-TILE_SIZE+8), Vector2D.From(x+8,y))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+32,y-TILE_SIZE+32), Vector2D.From(x+32,y))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+24,y-TILE_SIZE+24), Vector2D.From(x+24,y))
		allSectors[sind].floortex   = FLAT_STATIC_VERT[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_VERT[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
	elseif border_num == 12 then
		p.DrawVertexAt(Vector2D.From(x+8,y-TILE_SIZE))
		p.DrawVertexAt(Vector2D.From(x+8,y-8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-8))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+24,y-TILE_SIZE))
		p.DrawVertexAt(Vector2D.From(x+24,y-24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-24))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+32,y-TILE_SIZE))
		p.DrawVertexAt(Vector2D.From(x+32,y-32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-32))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+32,y-32))
		p.DrawVertexAt(Vector2D.From(x+24,y-24))
		p.DrawVertexAt(Vector2D.From(x+8,y-8))
		p.DrawVertexAt(Vector2D.From(x+0,y-0))
		p.FinishPlacingVertices()
		allSectors  = Map.GetSectors()
		allLinedefs = Map.GetLinedefs()
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+8,y-TILE_SIZE), Vector2D.From(x+8,y-8))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+32,y-TILE_SIZE), Vector2D.From(x+32,y-32))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+24,y-TILE_SIZE), Vector2D.From(x+24,y-24))
		allSectors[sind].floortex   = FLAT_STATIC_VERT[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_VERT[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE,y-8), Vector2D.From(x+8,y-8))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE,y-32), Vector2D.From(x+32,y-32))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE,y-24), Vector2D.From(x+24,y-24))
		allSectors[sind].floortex   = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
	elseif border_num == 13 then
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x+8,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x+8,y-8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-8))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x+24,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x+24,y-24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-24))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x+32,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x+32,y-32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE,y-32))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+32,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x+24,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x+8,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x+0,y-TILE_SIZE+0))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+32,y-32))
		p.DrawVertexAt(Vector2D.From(x+24,y-24))
		p.DrawVertexAt(Vector2D.From(x+8,y-8))
		p.DrawVertexAt(Vector2D.From(x+0,y-0))
		p.FinishPlacingVertices()
		allSectors  = Map.GetSectors()
		allLinedefs = Map.GetLinedefs()
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+8), Vector2D.From(x+8,y-TILE_SIZE+8))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+32), Vector2D.From(x+32,y-TILE_SIZE+32))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE,y-TILE_SIZE+24), Vector2D.From(x+24,y-TILE_SIZE+24))
		allSectors[sind].floortex   = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+8,y-8), Vector2D.From(x+8,y-TILE_SIZE+8))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+32,y-32), Vector2D.From(x+32,y-TILE_SIZE+32))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+24,y-24), Vector2D.From(x+24,y-TILE_SIZE+24))
		allSectors[sind].floortex   = FLAT_STATIC_VERT[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_VERT[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+8,y-8), Vector2D.From(x+TILE_SIZE,y-8))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+32,y-32), Vector2D.From(x+TILE_SIZE,y-32))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+24,y-24), Vector2D.From(x+TILE_SIZE,y-24))
		allSectors[sind].floortex   = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
	elseif border_num == 14 then
		p.DrawVertexAt(Vector2D.From(x+8,y-TILE_SIZE))
		p.DrawVertexAt(Vector2D.From(x+8,y-8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+24,y-TILE_SIZE))
		p.DrawVertexAt(Vector2D.From(x+24,y-24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+32,y-TILE_SIZE))
		p.DrawVertexAt(Vector2D.From(x+32,y-32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+32,y-32))
		p.DrawVertexAt(Vector2D.From(x+24,y-24))
		p.DrawVertexAt(Vector2D.From(x+8,y-8))
		p.DrawVertexAt(Vector2D.From(x+0,y-0))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-0,y-0))
		p.FinishPlacingVertices()
		allSectors  = Map.GetSectors()
		allLinedefs = Map.GetLinedefs()
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+8,y-TILE_SIZE), Vector2D.From(x+8,y-8))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+32,y-TILE_SIZE), Vector2D.From(x+32,y-32))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+24,y-TILE_SIZE), Vector2D.From(x+24,y-24))
		allSectors[sind].floortex   = FLAT_STATIC_VERT[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_VERT[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-8,y-8), Vector2D.From(x+8,y-8))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-32,y-32), Vector2D.From(x+32,y-32))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-24,y-24), Vector2D.From(x+24,y-24))
		allSectors[sind].floortex   = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-8,y-8), Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-32,y-32), Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-24,y-24), Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE))
		allSectors[sind].floortex   = FLAT_STATIC_VERT[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_VERT[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
	elseif border_num == 15 then
		p.DrawVertexAt(Vector2D.From(x+8,y-8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x+8,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x+8,y-8))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+24,y-24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x+24,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x+24,y-24))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+32,y-32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x+32,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x+32,y-32))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+32,y-32))
		p.DrawVertexAt(Vector2D.From(x+24,y-24))
		p.DrawVertexAt(Vector2D.From(x+8,y-8))
		p.DrawVertexAt(Vector2D.From(x+0,y-0))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-0,y-0))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x+TILE_SIZE-0,y-TILE_SIZE+0))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+32,y-TILE_SIZE+32))
		p.DrawVertexAt(Vector2D.From(x+24,y-TILE_SIZE+24))
		p.DrawVertexAt(Vector2D.From(x+8,y-TILE_SIZE+8))
		p.DrawVertexAt(Vector2D.From(x+0,y-TILE_SIZE+0))
		p.FinishPlacingVertices()
		allSectors  = Map.GetSectors()
		allLinedefs = Map.GetLinedefs()
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+8,y-8), Vector2D.From(x+TILE_SIZE-8,y-8))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+32,y-32), Vector2D.From(x+TILE_SIZE-32,y-32))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+24,y-24), Vector2D.From(x+TILE_SIZE-24,y-24))
		allSectors[sind].floortex   = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-8,y-8), Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE+8))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-32,y-32), Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE+32))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-24,y-24), Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE+24))
		allSectors[sind].floortex   = FLAT_STATIC_VERT[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_VERT[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-8,y-TILE_SIZE+8), Vector2D.From(x+8,y-TILE_SIZE+8))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-32,y-TILE_SIZE+32), Vector2D.From(x+32,y-TILE_SIZE+32))
		allSectors[sind].floortex = FLAT_LIGHT_HORZ[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_HORZ[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+TILE_SIZE-24,y-TILE_SIZE+24), Vector2D.From(x+24,y-TILE_SIZE+24))
		allSectors[sind].floortex   = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_HORZ[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+8,y-TILE_SIZE+8), Vector2D.From(x+8,y-8))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+32,y-TILE_SIZE+32), Vector2D.From(x+32,y-32))
		allSectors[sind].floortex = FLAT_LIGHT_VERT[color_num]
		allSectors[sind].ceiltex  = FLAT_LIGHT_VERT[color_num]
		sind = get_sector_index_from_linedef_coords_back(allSectors, allLinedefs, Vector2D.From(x+24,y-TILE_SIZE+24), Vector2D.From(x+24,y-24))
		allSectors[sind].floortex   = FLAT_STATIC_VERT[color_num]
		allSectors[sind].ceiltex    = FLAT_STATIC_VERT[color_num]
		allSectors[sind].tag        = 0
		allSectors[sind].effect     = 0
		allSectors[sind].brightness = 256
	end
	--- apply tags & actions
	allLinedefs = Map.GetLinedefs()
	allSectors  = Map.GetSectors()
	change_linedef(allLinedefs, v1, v2, 269, TAG_OFFSET+3)
	change_linedef(allLinedefs, v1+Vector2D.From(0,-8), v2+Vector2D.From(0,-8), 269, TAG_OFFSET+3)
	change_linedef(allLinedefs, v3, v4, 269, TAG_OFFSET+3)
	change_linedef(allLinedefs, v3+Vector2D.From(0,-8), v4+Vector2D.From(0,-8), 269, TAG_OFFSET+3)
	change_sector(allSectors, Vector2D.From(x+TILE_SIZE/2+64, y-TILE_SIZE/2), TILE_FLOOR, TILE_CEILING, 0, TAG_OFFSET+1, DARK_VALUE)
	change_sector(allSectors, Vector2D.From(x+TILE_SIZE/2+32, y-TILE_SIZE/2), TILE_FLOOR, TILE_CEILING+KEEN_CEILING, 0, TAG_OFFSET+2, DARK_VALUE)
	change_linedef(allLinedefs, v3, v3+Vector2D.From(0,16), 213, TAG_OFFSET+1)
	change_linedef(allLinedefs, v4, v4+Vector2D.From(0,16), 261, TAG_OFFSET+1)
	-- no noise-making thing if we don't want it
	if noise_id > 0 then
		change_linedef(allLinedefs, v5, v5+Vector2D.From(0,-16), 213, TAG_OFFSET+2)
		change_linedef(allLinedefs, v5+Vector2D.From(0,-16), v5+Vector2D.From(16,-16), 261, TAG_OFFSET+2)
		local newThing2 = Map.InsertThing(x+TILE_SIZE/2+32, y-TILE_SIZE/2)
		newThing2.type  = noise_id
		newThing2.SetAngleDoom(270)
	end
	--- add things
	local newThing1 = Map.InsertThing(x+TILE_SIZE/2, y-TILE_SIZE/2)
	local newThing3 = Map.InsertThing(x+TILE_SIZE/2+64, y-TILE_SIZE/2)
	newThing1.type  = 14
	newThing3.type  = 14
	newThing1.SetAngleDoom(270)
	newThing3.SetAngleDoom(270)
end

---
---
---
function draw_barrel_closet(x, y, TAG_OFFSET)
	local p = Pen.From(x,y)
	p.snaptogrid  = false
	p.stitchrange = 1
	--- border
	p.DrawVertexAt(Vector2D.From(x,y))
	p.DrawVertexAt(Vector2D.From(x+64,y))
	p.DrawVertexAt(Vector2D.From(x+64,y-EXP_CONV_SPEED))
	p.DrawVertexAt(Vector2D.From(x,y-EXP_CONV_SPEED))
	p.DrawVertexAt(Vector2D.From(x,y))
	p.FinishPlacingVertices()
	--- aux conveyor
	p.DrawVertexAt(Vector2D.From(x+80,y))
	p.DrawVertexAt(Vector2D.From(x+112,y))
	p.DrawVertexAt(Vector2D.From(x+112,y-EXP_CONV_SPEED))
	p.DrawVertexAt(Vector2D.From(x+80,y))
	p.FinishPlacingVertices()
	--- mechanical bits
	p.DrawVertexAt(Vector2D.From(x+16,y-128))
	p.DrawVertexAt(Vector2D.From(x+48,y-128))
	p.DrawVertexAt(Vector2D.From(x+48,y-132))
	p.DrawVertexAt(Vector2D.From(x+16,y-132))
	p.DrawVertexAt(Vector2D.From(x+16,y-128))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+48,y-144))
	p.DrawVertexAt(Vector2D.From(x+16,y-144))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+48,y-160))
	p.DrawVertexAt(Vector2D.From(x+16,y-160))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+48,y-192))
	p.DrawVertexAt(Vector2D.From(x+16,y-192))
	p.FinishPlacingVertices()
	--- apply tags & actions
	local allLinedefs = Map.GetLinedefs()
	local allSectors  = Map.GetSectors()
	change_linedef(allLinedefs, Vector2D.From(x+64,y), Vector2D.From(x+64,y-EXP_CONV_SPEED), 253, TAG_OFFSET+3)
	change_linedef(allLinedefs, Vector2D.From(x+112,y), Vector2D.From(x+112,y-EXP_CONV_SPEED), 253, TAG_OFFSET+4)
	change_sector(allSectors, Vector2D.From(x+32, y-EXP_CONV_SPEED/2), 0, 128, 0, TAG_OFFSET+3, 192)
	change_sector(allSectors, Vector2D.From(x+32, y-130), 128, 128, 0, TAG_OFFSET+4, 192)
	change_linedef(allLinedefs, Vector2D.From(x+48,y-144), Vector2D.From(x+16,y-144), 269, TAG_OFFSET)
	change_linedef(allLinedefs, Vector2D.From(x+48,y-160), Vector2D.From(x+16,y-160), 269, TAG_OFFSET+1)
	change_linedef(allLinedefs, Vector2D.From(x+48,y-192), Vector2D.From(x+16,y-192), 269, TAG_OFFSET+3)
	--- add things
	local newThing1 = Map.InsertThing(x+32, y-80)
	local newThing2 = Map.InsertThing(x+32, y-112)
	newThing1.type  = 14
	newThing2.type  = 70
	newThing1.SetAngleDoom(270)
	newThing2.SetAngleDoom(270)
end

---
--- TAG_OFFSET + 0 = primary scrolling
--- TAG_OFFSET + 1 = voodoo 1, floor lower
--- TAG_OFFSET + 2 = voodoo 2, floor raise
--- TAG_OFFSET + 3 = voodoo 3, light flashing
--- TAG_OFFSET + 4 = voodoo 4, global explosion sound
--- HMP:  +5
--- HNTR: +10
--- sound control: > +10
---
function draw_voodoo_frame(x, y, total_wait, TAG_OFFSET, tag_difficulty)
	local p = Pen.From(x,y)
	p.snaptogrid  = false
	p.stitchrange = 1
	--- border
	p.DrawVertexAt(Vector2D.From(x,y))
	p.DrawVertexAt(Vector2D.From(x+256,y))
	p.DrawVertexAt(Vector2D.From(x+256,y-CONVEYOR_SPEED))
	p.DrawVertexAt(Vector2D.From(x+256,y-total_wait-256))
	p.DrawVertexAt(Vector2D.From(x,y-total_wait-256))
	p.DrawVertexAt(Vector2D.From(x,y))
	p.FinishPlacingVertices()
	--- teleporters
	p.DrawVertexAt(Vector2D.From(x+48,y-total_wait-128))
	p.DrawVertexAt(Vector2D.From(x+16,y-total_wait-128))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+16,y-128))
	p.DrawVertexAt(Vector2D.From(x+48,y-128))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+48+64,y-total_wait-128))
	p.DrawVertexAt(Vector2D.From(x+16+64,y-total_wait-128))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+16+64,y-128))
	p.DrawVertexAt(Vector2D.From(x+48+64,y-128))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+48+128,y-total_wait-128))
	p.DrawVertexAt(Vector2D.From(x+16+128,y-total_wait-128))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+16+128,y-128))
	p.DrawVertexAt(Vector2D.From(x+48+128,y-128))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+48+192,y-total_wait-128))
	p.DrawVertexAt(Vector2D.From(x+16+192,y-total_wait-128))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+16+192,y-128))
	p.DrawVertexAt(Vector2D.From(x+48+192,y-128))
	p.FinishPlacingVertices()
	--- difficulty / ob-number blockers
	p.DrawVertexAt(Vector2D.From(x+16,y-64))
	p.DrawVertexAt(Vector2D.From(x+240,y-64))
	p.DrawVertexAt(Vector2D.From(x+240,y-68))
	p.DrawVertexAt(Vector2D.From(x+16,y-68))
	p.DrawVertexAt(Vector2D.From(x+16,y-64))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+16,y-72))
	p.DrawVertexAt(Vector2D.From(x+240,y-72))
	p.DrawVertexAt(Vector2D.From(x+240,y-76))
	p.DrawVertexAt(Vector2D.From(x+16,y-76))
	p.DrawVertexAt(Vector2D.From(x+16,y-72))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+16,y-total_wait-136))
	p.DrawVertexAt(Vector2D.From(x+240,y-total_wait-136))
	p.DrawVertexAt(Vector2D.From(x+240,y-total_wait-152))
	p.DrawVertexAt(Vector2D.From(x+16,y-total_wait-152))
	p.DrawVertexAt(Vector2D.From(x+16,y-total_wait-136))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+272,y-16))
	p.DrawVertexAt(Vector2D.From(x+304,y-16))
	p.DrawVertexAt(Vector2D.From(x+304,y-48))
	p.DrawVertexAt(Vector2D.From(x+272,y-48))
	p.DrawVertexAt(Vector2D.From(x+272,y-16))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+272,y-48))
	p.DrawVertexAt(Vector2D.From(x+304,y-16))
	p.FinishPlacingVertices()
	--- global ob on/off lines
	p.DrawVertexAt(Vector2D.From(x+48+192,y-160))
	p.DrawVertexAt(Vector2D.From(x+16+192,y-160))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+48,y-total_wait-96))
	p.DrawVertexAt(Vector2D.From(x+16,y-total_wait-96))
	p.FinishPlacingVertices()
	--- apply tags & actions
	local allLinedefs = Map.GetLinedefs()
	local allSectors  = Map.GetSectors()
	change_linedef(allLinedefs, Vector2D.From(x+48,y-total_wait-128), Vector2D.From(x+16,y-total_wait-128), 244, TAG_OFFSET+1)
	change_linedef(allLinedefs, Vector2D.From(x+48+64,y-total_wait-128), Vector2D.From(x+16+64,y-total_wait-128), 244, TAG_OFFSET+2)
	change_linedef(allLinedefs, Vector2D.From(x+48+128,y-total_wait-128), Vector2D.From(x+16+128,y-total_wait-128), 244, TAG_OFFSET+3)
	change_linedef(allLinedefs, Vector2D.From(x+48+192,y-total_wait-128), Vector2D.From(x+16+192,y-total_wait-128), 244, TAG_OFFSET+4)
	change_linedef(allLinedefs, Vector2D.From(x+48,y-128), Vector2D.From(x+16,y-128), 0, TAG_OFFSET+1)
	change_linedef(allLinedefs, Vector2D.From(x+48+64,y-128), Vector2D.From(x+16+64,y-128), 0, TAG_OFFSET+2)
	change_linedef(allLinedefs, Vector2D.From(x+48+128,y-128), Vector2D.From(x+16+128,y-128), 0, TAG_OFFSET+3)
	change_linedef(allLinedefs, Vector2D.From(x+48+192,y-128), Vector2D.From(x+16+192,y-128), 0, TAG_OFFSET+4)
	change_linedef(allLinedefs, Vector2D.From(x+256,y), Vector2D.From(x+256,y-CONVEYOR_SPEED), 253, TAG_OFFSET)
	change_sector(allSectors, Vector2D.From(x+128, y-(total_wait+256)/2), 0, 128, 0, TAG_OFFSET, 192)
	change_sector(allSectors, Vector2D.From(x+128, y-66), 32, 128, 0, tag_difficulty, 192)
	change_sector(allSectors, Vector2D.From(x+128, y-74), 32, 128, 0, OB_GLOBAL_TAG, 192)
	change_linedef(allLinedefs, Vector2D.From(x+48+192,y-160), Vector2D.From(x+16+192,y-160), 24961, UNIVERSAL_OB_ON)
	change_linedef(allLinedefs, Vector2D.From(x+48,y-total_wait-96), Vector2D.From(x+16,y-total_wait-96), 24769, UNIVERSAL_OB_ON)
	local sind1 = get_sector_index_from_linedef_coords(allSectors, allLinedefs, Vector2D.From(x+16,y-72), Vector2D.From(x+16,y-76))
	local sind2 = get_sector_index_from_linedef_coords(allSectors, allLinedefs, Vector2D.From(x+16,y-total_wait-136), Vector2D.From(x+16,y-total_wait-152))
	local sind3 = get_sector_index_from_linedef_coords(allSectors, allLinedefs, Vector2D.From(x+272,y-16), Vector2D.From(x+304,y-16))
	local sind4 = get_sector_index_from_linedef_coords(allSectors, allLinedefs, Vector2D.From(x+304,y-16), Vector2D.From(x+304,y-48))
	allSectors[sind4].floorheight = 0
	allSectors[sind4].ceilheight  = 32
	Map.JoinSectors({allSectors[sind1], allSectors[sind2], allSectors[sind3]})
	local lInd = 0
	--- add things
	local newThing1 = Map.InsertThing(x+32, y-32)
	local newThing2 = Map.InsertThing(x+32+64, y-32)
	local newThing3 = Map.InsertThing(x+32+128, y-32)
	local newThing4 = Map.InsertThing(x+32+192, y-32)
	newThing1.type  = 1
	newThing2.type  = 1
	newThing3.type  = 1
	newThing4.type  = 1
	newThing1.SetAngleDoom(270)
	newThing2.SetAngleDoom(270)
	newThing3.SetAngleDoom(270)
	newThing4.SetAngleDoom(270)
end

---
--- separating guardrail drawing because we need to do it last (as to not split overlapping linedefs)
---
function draw_voodoo_frame_guardrails(x, y, total_wait)
	local p = Pen.From(x,y)
	p.snaptogrid  = false
	p.stitchrange = 1
	for i=0, 3 do
		p.DrawVertexAt(Vector2D.From(x+16+i*64,y-16))
		p.DrawVertexAt(Vector2D.From(x+16+i*64,y-48))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+48+i*64,y-48))
		p.DrawVertexAt(Vector2D.From(x+48+i*64,y-16))
		p.FinishPlacingVertices()
	end
	local allLinedefs = Map.GetLinedefs()
	for i=0, 3 do
		lInd = get_linedef_index(allLinedefs, Vector2D.From(x+16+i*64,y-16), Vector2D.From(x+16+i*64,y-48))
		allLinedefs[lInd].SetFlag("1", true)
		allLinedefs[lInd].start_vertex.position = Vector2D.From(x+16+i*64, y-96)
		allLinedefs[lInd].end_vertex.position   = Vector2D.From(x+16+i*64, y-total_wait-128)
		lInd = get_linedef_index(allLinedefs, Vector2D.From(x+48+i*64,y-48), Vector2D.From(x+48+i*64,y-16))
		allLinedefs[lInd].SetFlag("1", true)
		allLinedefs[lInd].start_vertex.position = Vector2D.From(x+48+i*64, y-total_wait-128)
		allLinedefs[lInd].end_vertex.position   = Vector2D.From(x+48+i*64, y-96)
	end
end

--- pointless attempt to reduce code copy-pasting
function draw_and_apply_actions_to_explosion_linedefs(xPos, yPos, tag_offsets, action_tag_offset, action)
	local len = 1
	local p   = Pen.From(xPos,yPos)
	p.snaptogrid  = false
	p.stitchrange = 1
	local tag_base = {0,32,64,96}
	local y_base   = {0,1,2,3}
	for j=1, #tag_base do
		if #tag_offsets > tag_base[j] then
			len = math.floor(32/math.min(32,#tag_offsets-tag_base[j]))
			-- when drawing vertices very close together, use "false, false"
			p.DrawVertexAt(Vector2D.From(xPos,yPos-y_base[j]), false, false)
			for i=tag_base[j]+1, math.min(tag_base[j]+32, #tag_offsets) do
				p.DrawVertexAt(Vector2D.From(xPos-(i-tag_base[j])*len,yPos-y_base[j]), false, false)
			end
			p.FinishPlacingVertices()
		end
	end
	--- actions
	allLinedefs = Map.GetLinedefs()
	for j=1, #tag_base do
		if #tag_offsets > tag_base[j] then
			len = math.floor(32/math.min(32,#tag_offsets-tag_base[j]))
			for i=tag_base[j]+1, math.min(tag_base[j]+32, #tag_offsets) do
				change_linedef(allLinedefs, Vector2D.From(xPos-(i-1-tag_base[j])*len,yPos-y_base[j]), Vector2D.From(xPos-(i-tag_base[j])*len,yPos-y_base[j]), action, tag_offsets[i]+action_tag_offset)
			end
		end
	end
end

---
--- now supports up to 128 concurrent explosions!! (up from 32)
---
function draw_explosion_trigger(x, y, tag_offsets, sound_tag)
	--- voodoo 1, floor lower
	draw_and_apply_actions_to_explosion_linedefs(x+48, y-192, tag_offsets, 4, 24769)
	--- voodoo 2, floor raise
	draw_and_apply_actions_to_explosion_linedefs(x+48+64, y-192-EXP_TO_FLOORUP, tag_offsets, 4, 25089)
	--- voodoo 3, light flashing
	draw_and_apply_actions_to_explosion_linedefs(x+48+128, y-192-EXP_TO_LIGHTUP, tag_offsets, 0, 81)
	--- voodoo 4, global explosion sound
	local p = Pen.From(x,y)
	p.snaptogrid  = false
	p.stitchrange = 1
	local xPos = x+48+192
	local yPos = y-192-4
	p.DrawVertexAt(Vector2D.From(xPos-16,yPos))
	p.DrawVertexAt(Vector2D.From(xPos-32,yPos))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(xPos-0,yPos-EXP_TO_FLOORUP))
	p.DrawVertexAt(Vector2D.From(xPos-16,yPos-EXP_TO_FLOORUP))
	p.FinishPlacingVertices()
	--- voodoo 4 actions
	local allLinedefs = Map.GetLinedefs()
	change_linedef(allLinedefs, Vector2D.From(xPos-16,yPos), Vector2D.From(xPos-32,yPos), 24769, sound_tag+4)
	change_linedef(allLinedefs, Vector2D.From(xPos-0,yPos-EXP_TO_FLOORUP), Vector2D.From(xPos-16,yPos-EXP_TO_FLOORUP), 25089, sound_tag+4)
end

---
--- DRAW SKILL CLOSETS
---
function draw_skill_closet(x, y, tag_block, tag_scroll, mySkill)
	local p = Pen.From(x,y)
	p.snaptogrid  = false
	p.stitchrange = 1
	p.DrawVertexAt(Vector2D.From(x,y))
	p.DrawVertexAt(Vector2D.From(x+64,y))
	p.DrawVertexAt(Vector2D.From(x+64,y-256))
	p.DrawVertexAt(Vector2D.From(x,y-256))
	p.DrawVertexAt(Vector2D.From(x,y))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+48,y-128))
	p.DrawVertexAt(Vector2D.From(x+16,y-128))
	p.FinishPlacingVertices()
	--- apply tags & actions
	local allLinedefs = Map.GetLinedefs()
	local allSectors  = Map.GetSectors()
	local sInd = get_sector_index_from_linedef_coords(allSectors, allLinedefs, Vector2D.From(x+64,y), Vector2D.From(x+64,y-256))
	allSectors[sInd].tag = tag_scroll
	change_linedef(allLinedefs, Vector2D.From(x+64,y), Vector2D.From(x+64,y-256), 253, tag_scroll)
	change_linedef(allLinedefs, Vector2D.From(x+48,y-128), Vector2D.From(x+16,y-128), 24728, tag_block)
	--- add things
	local newThing1 = Map.InsertThing(x+32, y-32)
	newThing1.type  = 1
	newThing1.SetAngleDoom(270)
	local newThings2 = {}
	for i=1,6 do
		newThings2[#newThings2+1]    = Map.InsertThing(x+32, y-(i-1)*32-80)
		newThings2[#newThings2].type = 41
		if mySkill == 2 then
			newThings2[#newThings2].SetFlag("1",false)
			newThings2[#newThings2].SetFlag("2",true)
			newThings2[#newThings2].SetFlag("4",true)
		elseif mySkill == 3 then
			newThings2[#newThings2].SetFlag("1",true)
			newThings2[#newThings2].SetFlag("2",false)
			newThings2[#newThings2].SetFlag("4",true)
		elseif mySkill == 4 then
			newThings2[#newThings2].SetFlag("1",true)
			newThings2[#newThings2].SetFlag("2",true)
			newThings2[#newThings2].SetFlag("4",false)
		end
	end
end

---
--- DRAW OB TRANSITION CLOSETS (ALSO GLOBAL OB ON/OFF CONTROL SECTOR)
---
--- starting_tag = OB_TRANSITION + (# obs) x 5
---
--- starting_tag + 0 = blocking sector(s) in explosion closet
--- starting_tag + 1 = increment closet scroll
--- starting_tag + 2 = increment closet lift
--- starting_tag + 3 = decrement closet scroll
--- starting_tag + 4 = decrement closet lift
---
function draw_transition_closet(x, y, tag_prevOff, tag_nextOn, tag_scroll, tag_lift, global_control_coords)
	local p = Pen.From(x,y)
	p.snaptogrid  = false
	p.stitchrange = 1
	p.DrawVertexAt(Vector2D.From(x,y))
	p.DrawVertexAt(Vector2D.From(x+64,y))
	p.DrawVertexAt(Vector2D.From(x+64,y-256))
	p.DrawVertexAt(Vector2D.From(x+64,y-640))
	p.DrawVertexAt(Vector2D.From(x,y-640))
	p.DrawVertexAt(Vector2D.From(x,y))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+8,y-64))
	p.DrawVertexAt(Vector2D.From(x+56,y-64))
	p.DrawVertexAt(Vector2D.From(x+56,y-80))
	p.DrawVertexAt(Vector2D.From(x+8,y-80))
	p.DrawVertexAt(Vector2D.From(x+8,y-64))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+8,y-80))
	p.DrawVertexAt(Vector2D.From(x+4,y-64))
	p.DrawVertexAt(Vector2D.From(x+8,y-64))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+48,y-128))
	p.DrawVertexAt(Vector2D.From(x+16,y-128))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+48,y-256))
	p.DrawVertexAt(Vector2D.From(x+16,y-256))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+48,y-384))
	p.DrawVertexAt(Vector2D.From(x+16,y-384))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+48,y-512))
	p.DrawVertexAt(Vector2D.From(x+16,y-512))
	p.FinishPlacingVertices()
	local allLinedefs = Map.GetLinedefs()
	local allSectors  = Map.GetSectors()
	local sind_global = -1
	local drew_closet = 0
	-- if first time drawing one of these, draw the global on/off control
	if global_control_coords[1] == -1 and global_control_coords[2] == -1 then
		p.DrawVertexAt(Vector2D.From(x+80,y-16))
		p.DrawVertexAt(Vector2D.From(x+112,y-16))
		p.DrawVertexAt(Vector2D.From(x+112,y-48))
		p.DrawVertexAt(Vector2D.From(x+80,y-48))
		p.DrawVertexAt(Vector2D.From(x+80,y-16))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+80,y-48))
		p.DrawVertexAt(Vector2D.From(x+112,y-16))
		p.FinishPlacingVertices()
		allLinedefs = Map.GetLinedefs()
		allSectors  = Map.GetSectors()
		sind_global = get_sector_index_from_linedef_coords(allSectors, allLinedefs, Vector2D.From(x+80,y-16), Vector2D.From(x+112,y-16))
		allSectors[sind_global].floorheight = 0
		allSectors[sind_global].ceilheight  = 32
		sind_global = get_sector_index_from_linedef_coords(allSectors, allLinedefs, Vector2D.From(x+112,y-16), Vector2D.From(x+112,y-48))
		allSectors[sind_global].tag = UNIVERSAL_OB_ON
		drew_closet = 1
	else
		gx = {global_control_coords[1]+32, global_control_coords[1]+32}
		gy = {global_control_coords[2],    global_control_coords[2]-32}
		sind_global = get_sector_index_from_linedef_coords(allSectors, allLinedefs, Vector2D.From(gx[1],gy[1]), Vector2D.From(gx[2],gy[2]))
	end
	local sind1 = get_sector_index_from_linedef_coords(allSectors, allLinedefs, Vector2D.From(x+4,y-64), Vector2D.From(x+8,y-64))
	Map.JoinSectors({allSectors[sind_global], allSectors[sind1]})
	--- tags & actions
	change_linedef(allLinedefs, Vector2D.From(x+64,y), Vector2D.From(x+64,y-256), 253, tag_scroll)
	change_linedef(allLinedefs, Vector2D.From(x+16,y-128), Vector2D.From(x+48,y-128), 24985, tag_prevOff)
	change_linedef(allLinedefs, Vector2D.From(x+16,y-256), Vector2D.From(x+48,y-256), 24961, UNIVERSAL_OB_ON)
	change_linedef(allLinedefs, Vector2D.From(x+16,y-384), Vector2D.From(x+48,y-384), 24729, tag_nextOn)
	change_linedef(allLinedefs, Vector2D.From(x+16,y-512), Vector2D.From(x+48,y-512), 97, tag_scroll)
	local sind2 = get_sector_index_from_linedef_coords(allSectors, allLinedefs, Vector2D.From(x+8,y-64), Vector2D.From(x+56,y-64))
	allSectors[sind2].floorheight = 40
	allSectors[sind2].ceilheight  = 128
	allSectors[sind2].tag         = tag_lift
	local sind3 = get_sector_index_from_linedef_coords(allSectors, allLinedefs, Vector2D.From(x,y), Vector2D.From(x+64,y))
	allSectors[sind3].floorheight = 0
	allSectors[sind3].ceilheight  = 128
	allSectors[sind3].tag         = tag_scroll
	--- things!
	local newThing1 = Map.InsertThing(x+32, y-48)
	newThing1.type  = 1
	newThing1.SetAngleDoom(270)
	local newThing2 = Map.InsertThing(x+32, y-16)
	newThing2.type  = 14
	newThing2.SetAngleDoom(270)
	--- return coords of universal ob control sector
	if drew_closet == 1 then
		return {x+80, y-16}
	end
	return global_control_coords
end


---
--- from top to bottom:
---
--- [WR] ME ON
--- [WR] ME OFF
--- [WR] INCREMENT TO NEXT
--- [WR] DECREMENT TO ME
---
function draw_transition_switches(x, y, tag_on, tag_off, tag_incr, tag_decr)
	local p = Pen.From(x,y)
	p.snaptogrid  = false
	p.stitchrange = 1
	p.DrawVertexAt(Vector2D.From(x,y))
	p.DrawVertexAt(Vector2D.From(x+64,y))
	p.DrawVertexAt(Vector2D.From(x+64,y-80))
	p.DrawVertexAt(Vector2D.From(x,y-80))
	p.DrawVertexAt(Vector2D.From(x,y))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+48,y-16))
	p.DrawVertexAt(Vector2D.From(x+16,y-16))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+48,y-32))
	p.DrawVertexAt(Vector2D.From(x+16,y-32))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+48,y-48))
	p.DrawVertexAt(Vector2D.From(x+16,y-48))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+48,y-64))
	p.DrawVertexAt(Vector2D.From(x+16,y-64))
	p.FinishPlacingVertices()
	--- actions
	local allLinedefs = Map.GetLinedefs()
	change_linedef(allLinedefs, Vector2D.From(x+48,y-16), Vector2D.From(x+16,y-16), 24729, tag_on)
	change_linedef(allLinedefs, Vector2D.From(x+48,y-32), Vector2D.From(x+16,y-32), 24985, tag_off)
	change_linedef(allLinedefs, Vector2D.From(x+48,y-48), Vector2D.From(x+16,y-48), 13593, tag_incr)
	change_linedef(allLinedefs, Vector2D.From(x+48,y-64), Vector2D.From(x+16,y-64), 13593, tag_decr)
end


---
--- READ INPUT OBSTACLE DATA
---
print("\n=== READING INPUT OB STRING...\n")
ob_tiles    = {}
ob_expls    = {}
ob_waits    = {}
ob_duration = 0
t = split(s,";")
for k, v in pairs(t) do
	t2 = split(v,"=")
	--- PARSE INPUT TILE COORDINATES
	if t2[1].sub(t2[1],1,1) == "t" then
		if t2[2].sub(t2[2],1,1) == "(" and t2[2].sub(t2[2],#t2[2]) == ")" then
			t3 = split(t2[2].sub(t2[2],2,#t2[2]-1),",")
			print("valid tile:", tonumber(t3[1]), tonumber(t3[2]), tonumber(t3[3]), tonumber(t3[4]))
			ob_tiles[tonumber(t2[1].sub(t2[1],2))] = {tonumber(t3[1]), tonumber(t3[2]), tonumber(t3[3]), tonumber(t3[4])}
		else
			print("invalid tile!")
		end
	end
	--- PARSE EXPLOSION PATTERN
	if t2[1].sub(t2[1],1,1) == "e" then
		if t2[2].sub(t2[2],1,1) == "[" and t2[2].sub(t2[2],#t2[2]) == "]" then
			t3 = split(t2[2].sub(t2[2],2,#t2[2]-1),",")
			s3 = ""
			for k3, v3 in pairs(t3) do
				s3 = s3 .. " " .. v3
			end
			print("valid explosion:", s3)
			ob_expls[tonumber(t2[1].sub(t2[1],2))] = t3
		else
			print("invalid explosion!")
		end
	end
	--- PARSE WAIT DURATION
	if t2[1].sub(t2[1],1,1) == "w" then
		print("wait:", tonumber(t2[2]))
		ob_waits[tonumber(t2[1].sub(t2[1],2))] = tonumber(t2[2])
		ob_duration = ob_duration + tonumber(t2[2])
	end
end

---
--- TODO: ADD ALL THESE CHECKS TO FAIL OUT IF SOMETHING IS GONNA GO WRONG!!!
---

fail = false
--- FAILURE 0: empty or malformed ob string
--- FAILURE 1: if final wait is not long enough
if ob_waits[#ob_waits] < 128+EXP_TO_SOUNDOFF-32 then
	fail = true
end
--- FAILURE 2: too many simultaneously tiles exploding (>128)
--- FAILURE 3: tile is refired too soon
--- FAILURE 4: tiles are overlapping
--- FAILURE 5: conveyor closet build locations overlap tiles
--- FAILURE 6: any of the tags we are going to need are already used somewhere

if fail == true then
	UI.LogLine("FINAL WAIT TOO SHORT: " .. tostring(ob_waits[#ob_waits]) .. " < " .. 128+EXP_TO_SOUNDOFF-32)
else
	---
	--- DRAW TILES
	---
	print("\n=== DRAWING TILES...\n")
	tile_2_tagOffset = {}
	currentTagOffset = STARTING_TAG
	currentExp_X     = EXP_CONV_OFFSET_X
	currentExp_Y     = EXP_CONV_OFFSET_Y
	for k, v in spairs(ob_tiles) do
		if ONLY_TIMINGS == 0 then
			print("creating tile " .. k .. ": (" .. tostring(v[1]) .. ", " .. tostring(v[2]) .. "), tag: " .. tostring(currentTagOffset))
			draw_tile(v[1], v[2], v[3], v[4], 0, currentTagOffset) -- 84 --> 0. no more local sound objects
			draw_barrel_closet(currentExp_X, currentExp_Y, currentTagOffset)
		end
		tile_2_tagOffset[k] = currentTagOffset
		currentTagOffset    = currentTagOffset + TAGS_PER_TILE
		currentExp_X        = currentExp_X + EXP_CLOSET_WIDTH
	end
	--- barrel closets used for global sounds
	sound_tile_X = currentExp_X + EXP_CLOSET_WIDTH*NUM_SOUND + 128 + 960 + 64
	for i=1, NUM_SOUND do
		my_id = "s" .. tostring(i)
		if ONLY_TIMINGS == 0 then
			print("creating tile " .. my_id .. ": (" .. sound_tile_X .. ", " .. currentExp_Y .. "), tag: " .. tostring(currentTagOffset))
			draw_tile(sound_tile_X, currentExp_Y, 0, 1, 72, currentTagOffset)
			draw_barrel_closet(currentExp_X, currentExp_Y, currentTagOffset)
		end
		tile_2_tagOffset[my_id] = currentTagOffset
		currentTagOffset        = currentTagOffset + TAGS_PER_TILE
		currentExp_X            = currentExp_X + EXP_CLOSET_WIDTH
		sound_tile_X            = sound_tile_X + TILE_SIZE + 64
	end
	currentExp_X = currentExp_X + 128

	---
	--- DRAW VOODOO MACHINERY
	---
	print("\n=== DRAWING VOODOO MACHINERY...\n")
	if SKILL_SETTING == 4 then
		draw_voodoo_frame(currentExp_X, currentExp_Y, ob_duration, currentTagOffset, TAG_UV_BLOCK)
		skill_x_offset = 0
	end
	if SKILL_SETTING == 3 then
		draw_voodoo_frame(currentExp_X+320, currentExp_Y, ob_duration, currentTagOffset+5, TAG_HMP_BLOCK)
		skill_x_offset = 320
	end
	if SKILL_SETTING == 2 then
		draw_voodoo_frame(currentExp_X+640, currentExp_Y, ob_duration, currentTagOffset+10, TAG_HNTR_BLOCK)
		skill_x_offset = 640
	end
	voodoo_xy = {currentExp_X+skill_x_offset, currentExp_Y}

	---
	--- DRAW STARTS AND GLOBAL STUFF
	---
	y_skill = TILE_SIZE + 64
	y_trans = TILE_SIZE + 64 + 256 + 64
	y_swtch = TILE_SIZE + 64 + 256 + 64 + 640 + 64
	print("\n=== DRAWING OB TRANSITION VOODOO...\n")
	if DRAW_STARTS > 0 and ONLY_TIMINGS == 0 then
		draw_skill_closet(currentExp_X+1024,     currentExp_Y-y_skill, TAG_UV_BLOCK, TAG_UV_SCROLL, 4)
		draw_skill_closet(currentExp_X+1024+128, currentExp_Y-y_skill, TAG_HMP_BLOCK, TAG_HMP_SCROLL, 3)
		draw_skill_closet(currentExp_X+1024+256, currentExp_Y-y_skill, TAG_HNTR_BLOCK, TAG_HNTR_SCROLL, 2)
		gcoords = {-1,-1}
		for i=1, DRAW_STARTS do
			t_prevOff = OB_TRANSITION+(i-1)*5
			t_nextOn  = OB_TRANSITION+(i-0)*5
			t_scroll  = OB_TRANSITION+(i-1)*5 + 1
			t_lift    = OB_TRANSITION+(i-1)*5 + 2
			print("drawing transition: " .. tostring(i) .. " --> " .. tostring(i+1))
			gcoords = draw_transition_closet(currentExp_X+1024+(i-1)*256, currentExp_Y-y_trans, t_prevOff, t_nextOn, t_scroll, t_lift, gcoords)
			if i < DRAW_STARTS then
				t_prevOff = OB_TRANSITION+(i-0)*5
				t_nextOn  = OB_TRANSITION+(i-1)*5
				t_scroll  = OB_TRANSITION+(i-1)*5 + 3
				t_lift    = OB_TRANSITION+(i-1)*5 + 4
				print("drawing transition: " .. tostring(i+1) .. " --> " .. tostring(i))
				gcoords = draw_transition_closet(currentExp_X+1024+(i-1)*256+128, currentExp_Y-y_trans, t_prevOff, t_nextOn, t_scroll, t_lift, gcoords)
			end
			t_on   = OB_TRANSITION+(i-1)*5
			t_off  = OB_TRANSITION+(i-1)*5
			t_incr = OB_TRANSITION+(i-1)*5 + 2
			t_decr = OB_TRANSITION+(i-1)*5 + 4
			draw_transition_switches(currentExp_X+1024+(i-1)*256, currentExp_Y-y_swtch, t_on, t_off, t_incr, t_decr)
		end
	end

	---
	--- DRAW EXPLOSION TRIGGERS
	---
	print("\n=== DRAWING EXPLOSION TRIGGERS...\n")
	current_soundTag = 1
	for k, v in spairs(ob_expls) do
		print('w:',ob_waits[k])
		t_off = {}
		for k2, v2 in spairs(v) do
			t_off[k2] = tile_2_tagOffset[tonumber(v2.sub(v2,2))]
		end
		my_id = "s" .. tostring(current_soundTag)
		s_tag = tile_2_tagOffset[my_id]
		draw_explosion_trigger(currentExp_X+skill_x_offset, currentExp_Y, t_off, s_tag)
		currentExp_Y = currentExp_Y - ob_waits[k]
		current_soundTag = current_soundTag + 1
		if current_soundTag > NUM_SOUND then
			current_soundTag = 1
		end
	end
	--- draw guardrails last
	draw_voodoo_frame_guardrails(voodoo_xy[1], voodoo_xy[2], ob_duration)

end
