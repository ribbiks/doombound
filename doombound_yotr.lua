
FLAT_COL_VERT = {'LITORG2R', 'LITYEL2R', 'LITGRN2R', 'LITGRN2R', 'LITBLU2R', 'LITBLD2R', 'LITWHT2R', 'LITBLK2R'}
FLAT_COL_HORZ = {'LITORG5R', 'LITYEL5R', 'LITGRN5R', 'LITGRN5R', 'LITBLU5R', 'LITBLD5R', 'LITWHT5R', 'LITBLK5R'}
FLAT_RED_VERT = 'LITER2R'
FLAT_RED_HORZ = 'LITER1R'
FLAT_CENTER   = 'ITS_RED2'
DARK_VALUE    = 96
VOODOO_SPEED  = 112

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

function change_all_linedefs_within_bbox(e, w, n, s, new_action, new_tag)
	local lines = Map.GetLinedefs()
	for _,line in ipairs(lines) do
		local west  = math.min(line.start_vertex.position.x, line.end_vertex.position.x)
		local east  = math.max(line.start_vertex.position.x, line.end_vertex.position.x)
		local south = math.min(line.start_vertex.position.y, line.end_vertex.position.y)
		local north = math.max(line.start_vertex.position.y, line.end_vertex.position.y)
		if east >= e and west <= w and north <= n and south >= s then
			line.action = new_action
			line.tag = new_tag
		end
	end
end

function get_sector_bounding_box(sector)
	local lines = sector.GetLinedefs()
	local east  = lines[1].start_vertex.position.x
	local west  = lines[1].start_vertex.position.x
	local north = lines[1].start_vertex.position.y
	local south = lines[1].start_vertex.position.y
	for _,line in ipairs(lines) do
		-- v1
		east  = math.min(east,  line.start_vertex.position.x)
		west  = math.max(west,  line.start_vertex.position.x)
		north = math.max(north, line.start_vertex.position.y)
		south = math.min(south, line.start_vertex.position.y)
		-- v2
		east  = math.min(east,  line.end_vertex.position.x)
		west  = math.max(west,  line.end_vertex.position.x)
		north = math.max(north, line.end_vertex.position.y)
		south = math.min(south, line.end_vertex.position.y)
	end
	return east, west, north, south
end

function join_all_sectors_within_bbox(e, w, n, s)
	local sectors = Map.GetSectors()
	local sectors_to_join = {}
	for i=1, #sectors do
		se, sw, sn, ss = get_sector_bounding_box(sectors[i])
		if se >= e and sw <= w and sn <= n and ss >= s then
			sectors_to_join[#sectors_to_join+1] = sectors[i]
		end
	end
	if #sectors_to_join >= 2 then
		Map.JoinSectors(sectors_to_join)
	end
end

function get_linedef_index(linedefList, vpos1, vpos2)
	for i=1, #linedefList do
		local lv1 = linedefList[#linedefList-i+1].start_vertex.position
		local lv2 = linedefList[#linedefList-i+1].end_vertex.position
		if lv1 == vpos1 and lv2 == vpos2 then return #linedefList-i+1 end
		if lv1 == vpos2 and lv2 == vpos1 then return #linedefList-i+1 end
	end
end

function get_sector_index_from_linedef_coords(sectorList, linedefList, vpos1, vpos2)
	local lInd     = get_linedef_index(linedefList, vpos1, vpos2)
	local myFront  = linedefList[lInd].GetFront()
	local mySector = myFront.GetSector()
	return mySector.GetIndex()+1 --- +1 because sector indices are 0-indexed
end

TAGS_PER_TILE = 11

-- t + 0  = tele linedefs
-- t + 1  = N segment
-- t + 2  = E segment
-- t + 3  = S segment
-- t + 4  = W segment
-- t + 5  = outer border
-- t + 6  = tele-sector left
-- t + 0  = tele-sector right
-- t + 7  = tele-sector left [dummy]
-- t + 8  = tele-sector right [dummy]
-- t + 9  = tile scroll dummy
-- t + 10 = voodoo silent tele

-- t + (n * TAGS_PER_TILE) + 0 = voodoo scroller
-- t + (n * TAGS_PER_TILE) + 1 = voodoo blocker

function explosion_linedefs(x, y, t, global_sound_tag)
	local p = Pen.From(x,y)
	p.snaptogrid  = false
	p.stitchrange = 1
	p.DrawVertexAt(Vector2D.From(x+32,y))
	p.DrawVertexAt(Vector2D.From(x+16,y))
	p.DrawVertexAt(Vector2D.From(x,y))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+32,y-4))
	p.DrawVertexAt(Vector2D.From(x,y-4))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+28,y-8))
	p.DrawVertexAt(Vector2D.From(x+24,y-8))
	p.DrawVertexAt(Vector2D.From(x+20,y-8))
	p.DrawVertexAt(Vector2D.From(x+16,y-8))
	p.DrawVertexAt(Vector2D.From(x+12,y-8))
	p.DrawVertexAt(Vector2D.From(x+8,y-8))
	p.DrawVertexAt(Vector2D.From(x+4,y-8))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+32,y-12))
	p.DrawVertexAt(Vector2D.From(x+16,y-12))
	p.DrawVertexAt(Vector2D.From(x,y-12))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+32,y-16))
	p.DrawVertexAt(Vector2D.From(x+16,y-16))
	p.DrawVertexAt(Vector2D.From(x,y-16))
	p.FinishPlacingVertices()
	--
	local all_sectors  = Map.GetSectors()
	local all_linedefs = Map.GetLinedefs()
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+32,y), Vector2D.From(x+16,y))
	all_linedefs[l_ind].action = 25025
	all_linedefs[l_ind].tag = t+8
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+16,y), Vector2D.From(x,y))
	all_linedefs[l_ind].action = 24577
	all_linedefs[l_ind].tag = t+7
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+32,y-4), Vector2D.From(x,y-4))
	all_linedefs[l_ind].action = 24577
	all_linedefs[l_ind].tag = t+9
	--
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+28,y-8), Vector2D.From(x+24,y-8))
	all_linedefs[l_ind].action = 24769
	all_linedefs[l_ind].tag = global_sound_tag
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+24,y-8), Vector2D.From(x+20,y-8))
	all_linedefs[l_ind].action = 81
	all_linedefs[l_ind].tag = t+1
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+20,y-8), Vector2D.From(x+16,y-8))
	all_linedefs[l_ind].action = 81
	all_linedefs[l_ind].tag = t+2
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+16,y-8), Vector2D.From(x+12,y-8))
	all_linedefs[l_ind].action = 81
	all_linedefs[l_ind].tag = t+3
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+12,y-8), Vector2D.From(x+8,y-8))
	all_linedefs[l_ind].action = 81
	all_linedefs[l_ind].tag = t+4
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+8,y-8), Vector2D.From(x+4,y-8))
	all_linedefs[l_ind].action = 81
	all_linedefs[l_ind].tag = t+5
	--
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+32,y-12), Vector2D.From(x+16,y-12))
	all_linedefs[l_ind].action = 24961
	all_linedefs[l_ind].tag = global_sound_tag
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+16,y-12), Vector2D.From(x,y-12))
	all_linedefs[l_ind].action = 25025
	all_linedefs[l_ind].tag = t+9
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+32,y-16), Vector2D.From(x+16,y-16))
	all_linedefs[l_ind].action = 24577
	all_linedefs[l_ind].tag = t+8
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+16,y-16), Vector2D.From(x,y-16))
	all_linedefs[l_ind].action = 25025
	all_linedefs[l_ind].tag = t+7
end

function draw_sound_closet(x, y, global_sound_tag)
	local p = Pen.From(x,y)
	p.snaptogrid  = false
	p.stitchrange = 1
	p.DrawVertexAt(Vector2D.From(x,y))
	p.DrawVertexAt(Vector2D.From(x+64,y))
	p.DrawVertexAt(Vector2D.From(x+64,y-128))
	p.DrawVertexAt(Vector2D.From(x,y-128))
	p.DrawVertexAt(Vector2D.From(x,y))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x,y-48))
	p.DrawVertexAt(Vector2D.From(x+64,y-48))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x,y-80))
	p.DrawVertexAt(Vector2D.From(x+64,y-80))
	p.FinishPlacingVertices()
	--
	local all_sectors  = Map.GetSectors()
	local all_linedefs = Map.GetLinedefs()
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, Vector2D.From(x,y-48), Vector2D.From(x+64,y-48))
	all_sectors[s_ind].floorheight = 128
	all_sectors[s_ind].ceilheight = 128
	all_sectors[s_ind].tag = global_sound_tag
	--
	local new_thing1 = Map.InsertThing(x+32, y-16)
	new_thing1.type = 70
	new_thing1.SetAngleDoom(270)
	local new_thing2 = Map.InsertThing(x+32, y-112)
	new_thing2.type = 83
	new_thing2.SetAngleDoom(270)
end

function draw_voodoo_frame(x, y, t, num_tiles, ob_duration, dont_place_things)
	local p = Pen.From(x,y)
	p.snaptogrid  = false
	p.stitchrange = 1
	p.DrawVertexAt(Vector2D.From(x,y))
	p.DrawVertexAt(Vector2D.From(x+64*num_tiles,y))
	p.DrawVertexAt(Vector2D.From(x+64*num_tiles,y-VOODOO_SPEED))
	p.DrawVertexAt(Vector2D.From(x+64*num_tiles,y-ob_duration-96))
	p.DrawVertexAt(Vector2D.From(x,y-ob_duration-96))
	p.DrawVertexAt(Vector2D.From(x,y))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+16,y-56))
	p.DrawVertexAt(Vector2D.From(x+64*num_tiles-16,y-56))
	p.DrawVertexAt(Vector2D.From(x+64*num_tiles-16,y-60))
	p.DrawVertexAt(Vector2D.From(x+16,y-60))
	p.DrawVertexAt(Vector2D.From(x+16,y-56))
	p.FinishPlacingVertices()
	for i=0, num_tiles-1 do
		p.DrawVertexAt(Vector2D.From(x+i*64+16,y-32))
		p.DrawVertexAt(Vector2D.From(x+i*64+48,y-32))
		p.FinishPlacingVertices()
		p.DrawVertexAt(Vector2D.From(x+i*64+48,y-32-ob_duration))
		p.DrawVertexAt(Vector2D.From(x+i*64+16,y-32-ob_duration))
		p.FinishPlacingVertices()
	end
	--
	local all_sectors  = Map.GetSectors()
	local all_linedefs = Map.GetLinedefs()
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x,y), Vector2D.From(x+64*num_tiles,y))
	all_linedefs[l_ind].tag = t
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+64*num_tiles,y), Vector2D.From(x+64*num_tiles,y-VOODOO_SPEED))
	all_linedefs[l_ind].action = 253
	all_linedefs[l_ind].tag = t + num_tiles*TAGS_PER_TILE
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, Vector2D.From(x+64*num_tiles,y), Vector2D.From(x+64*num_tiles,y-VOODOO_SPEED))
	all_sectors[s_ind].tag = t + num_tiles*TAGS_PER_TILE
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, Vector2D.From(x+16,y-60), Vector2D.From(x+16,y-56))
	all_sectors[s_ind].tag = t + num_tiles*TAGS_PER_TILE + 1
	for i=0, num_tiles-1 do
		l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+i*64+16,y-32), Vector2D.From(x+i*64+48,y-32))
		all_linedefs[l_ind].tag = t + i*TAGS_PER_TILE + 10
		l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+i*64+48,y-32-ob_duration), Vector2D.From(x+i*64+16,y-32-ob_duration))
		all_linedefs[l_ind].action = 244
		all_linedefs[l_ind].tag = t + i*TAGS_PER_TILE + 10
	end
	--
	if dont_place_things <= 0 then
		local new_things = {}
		for i=0, num_tiles-1 do
			new_things[#new_things] = Map.InsertThing(x+i*64+32, y-32)
			new_things[#new_things].type = 1
			new_things[#new_things].SetAngleDoom(270)
		end
	end
end

function draw_dummies(x, y, t)
	local p = Pen.From(x,y)
	p.snaptogrid  = false
	p.stitchrange = 1
	p.DrawVertexAt(Vector2D.From(x,y))
	p.DrawVertexAt(Vector2D.From(x+32,y))
	p.DrawVertexAt(Vector2D.From(x+32,y-32))
	p.DrawVertexAt(Vector2D.From(x,y-32))
	p.DrawVertexAt(Vector2D.From(x,y))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+64,y))
	p.DrawVertexAt(Vector2D.From(x+96,y))
	p.DrawVertexAt(Vector2D.From(x+96,y-32))
	p.DrawVertexAt(Vector2D.From(x+64,y-32))
	p.DrawVertexAt(Vector2D.From(x+64,y))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+64,y-32))
	p.DrawVertexAt(Vector2D.From(x+96,y))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+128,y))
	p.DrawVertexAt(Vector2D.From(x+160,y))
	p.DrawVertexAt(Vector2D.From(x+160,y-32))
	p.DrawVertexAt(Vector2D.From(x+128,y-32))
	p.DrawVertexAt(Vector2D.From(x+128,y))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+128,y-32))
	p.DrawVertexAt(Vector2D.From(x+160,y))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+192,y))
	p.DrawVertexAt(Vector2D.From(x+224,y))
	p.DrawVertexAt(Vector2D.From(x+256,y))
	p.DrawVertexAt(Vector2D.From(x+256,y-32))
	p.DrawVertexAt(Vector2D.From(x+256,y-64))
	p.DrawVertexAt(Vector2D.From(x+224,y-64))
	p.DrawVertexAt(Vector2D.From(x+192,y-64))
	p.DrawVertexAt(Vector2D.From(x+192,y))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+208,y-16))
	p.DrawVertexAt(Vector2D.From(x+240,y-16))
	p.DrawVertexAt(Vector2D.From(x+240,y-48))
	p.DrawVertexAt(Vector2D.From(x+208,y-48))
	p.DrawVertexAt(Vector2D.From(x+208,y-16))
	p.FinishPlacingVertices()
	--
	local all_sectors  = Map.GetSectors()
	local all_linedefs = Map.GetLinedefs()
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x,y), Vector2D.From(x+32,y))
	all_linedefs[l_ind].action = 242
	all_linedefs[l_ind].tag = t+6
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+32,y), Vector2D.From(x+32,y-32))
	all_linedefs[l_ind].action = 242
	all_linedefs[l_ind].tag = t+0
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, Vector2D.From(x,y), Vector2D.From(x+32,y))
	all_sectors[s_ind].floorheight = 8
	all_sectors[s_ind].ceilheight = 128
	--
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+64,y), Vector2D.From(x+96,y))
	all_linedefs[l_ind].action = 247
	all_linedefs[l_ind].tag = t+6
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, Vector2D.From(x+64,y), Vector2D.From(x+96,y))
	all_sectors[s_ind].floorheight = 0
	all_sectors[s_ind].ceilheight = 128
	all_sectors[s_ind].tag = t+7
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, Vector2D.From(x+96,y-32), Vector2D.From(x+64,y-32))
	all_sectors[s_ind].floorheight = 64
	all_sectors[s_ind].ceilheight = 0
	--
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+160,y-32), Vector2D.From(x+128,y-32))
	all_linedefs[l_ind].action = 247
	all_linedefs[l_ind].tag = t+0
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, Vector2D.From(x+128,y), Vector2D.From(x+160,y))
	all_sectors[s_ind].floorheight = 64
	all_sectors[s_ind].ceilheight = 0
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, Vector2D.From(x+160,y-32), Vector2D.From(x+128,y-32))
	all_sectors[s_ind].floorheight = 64
	all_sectors[s_ind].ceilheight = 128
	all_sectors[s_ind].tag = t+8
	--
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+192,y), Vector2D.From(x+224,y))
	all_linedefs[l_ind].action = 216
	all_linedefs[l_ind].tag = t+4
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+256,y), Vector2D.From(x+256,y-32))
	all_linedefs[l_ind].action = 216
	all_linedefs[l_ind].tag = t+1
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+256,y-64), Vector2D.From(x+224,y-64))
	all_linedefs[l_ind].action = 216
	all_linedefs[l_ind].tag = t+2
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+192,y-64), Vector2D.From(x+192,y))
	all_linedefs[l_ind].action = 216
	all_linedefs[l_ind].tag = t+3
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, Vector2D.From(x+192,y), Vector2D.From(x+224,y))
	all_sectors[s_ind].floorheight = 0
	all_sectors[s_ind].ceilheight = 128
	all_sectors[s_ind].tag = t+9
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, Vector2D.From(x+208,y-16), Vector2D.From(x+240,y-16))
	all_sectors[s_ind].floorheight = 128
	all_sectors[s_ind].ceilheight = 0
end

function draw_tele_closet(x, y, t, tele_tag)
	local p = Pen.From(x,y)
	p.snaptogrid  = false
	p.stitchrange = 1
	p.DrawVertexAt(Vector2D.From(x,y))
	p.DrawVertexAt(Vector2D.From(x+192,y))
	p.DrawVertexAt(Vector2D.From(x+192,y-192))
	p.DrawVertexAt(Vector2D.From(x,y-192))
	p.DrawVertexAt(Vector2D.From(x,y))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+32,y-32))
	p.DrawVertexAt(Vector2D.From(x+160,y-32))
	p.DrawVertexAt(Vector2D.From(x+160,y-160))
	p.DrawVertexAt(Vector2D.From(x+32,y-160))
	p.DrawVertexAt(Vector2D.From(x+32,y-32))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+96,y-160))
	p.DrawVertexAt(Vector2D.From(x+96,y-32))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+88,y-136))
	p.DrawVertexAt(Vector2D.From(x+40,y-136))
	p.DrawVertexAt(Vector2D.From(x+40,y-56))
	p.DrawVertexAt(Vector2D.From(x+88,y-56))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+88,y-120))
	p.DrawVertexAt(Vector2D.From(x+56,y-120))
	p.DrawVertexAt(Vector2D.From(x+56,y-72))
	p.DrawVertexAt(Vector2D.From(x+88,y-72))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+104,y-56))
	p.DrawVertexAt(Vector2D.From(x+152,y-56))
	p.DrawVertexAt(Vector2D.From(x+152,y-136))
	p.DrawVertexAt(Vector2D.From(x+104,y-136))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+104,y-72))
	p.DrawVertexAt(Vector2D.From(x+136,y-72))
	p.DrawVertexAt(Vector2D.From(x+136,y-120))
	p.DrawVertexAt(Vector2D.From(x+104,y-120))
	p.FinishPlacingVertices()
	--
	change_all_linedefs_within_bbox(x+8, x+184, y-8, y-184, 97, tele_tag)
	--
	p.DrawVertexAt(Vector2D.From(x+64,y-112))
	p.DrawVertexAt(Vector2D.From(x+64,y-80))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+128,y-80))
	p.DrawVertexAt(Vector2D.From(x+128,y-112))
	p.FinishPlacingVertices()
	--
	local all_sectors  = Map.GetSectors()
	local all_linedefs = Map.GetLinedefs()
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+96,y-32), Vector2D.From(x+96,y-160))
	all_linedefs[l_ind].action = 0
	all_linedefs[l_ind].tag = 0
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+64,y-112), Vector2D.From(x+64,y-80))
	all_linedefs[l_ind].SetFlag("2", true)
	l_ind = get_linedef_index(all_linedefs, Vector2D.From(x+128,y-80), Vector2D.From(x+128,y-112))
	all_linedefs[l_ind].SetFlag("2", true)
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, Vector2D.From(x,y), Vector2D.From(x+192,y))
	all_sectors[s_ind].brightness = 0
	all_sectors[s_ind].floorheight = 0
	all_sectors[s_ind].ceilheight = 128
	all_sectors[s_ind].floortex = "ALLBLAKF"
	all_sectors[s_ind].ceiltex = "ALLBLAKF"
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, Vector2D.From(x+32,y-32), Vector2D.From(x+96,y-32))
	all_sectors[s_ind].brightness = 0
	all_sectors[s_ind].floorheight = 4
	all_sectors[s_ind].ceilheight = 128
	all_sectors[s_ind].floortex = "ALLBLAKF"
	all_sectors[s_ind].ceiltex = "ALLBLAKF"
	all_sectors[s_ind].tag = t+6
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, Vector2D.From(x+96,y-32), Vector2D.From(x+160,y-32))
	all_sectors[s_ind].brightness = 0
	all_sectors[s_ind].floorheight = 4
	all_sectors[s_ind].ceilheight = 128
	all_sectors[s_ind].floortex = "ALLBLAKF"
	all_sectors[s_ind].ceiltex = "ALLBLAKF"
	all_sectors[s_ind].tag = t+0
	--
	local new_thing = Map.InsertThing(x+90, y-96)
	new_thing.type = 14
	new_thing.SetAngleDoom(270)
end

function draw_tile(x, y, w, h, color_ind, t)
	-- init
	if w < 2 or h < 2 then
		UI.LogLine("Error: Requesting a tile (" .. tostring(w) .. "x" .. tostring(h) .. ") that is too small.")
	end
	local p = Pen.From(x,y)
	p.snaptogrid  = false
	p.stitchrange = 1
	-- rings
	for i=0, 2*math.min(w,h)-1 do
		local dw = (32 * w) - 16 * i
		local dh = (32 * h) - 16 * i
		local xc = (8 * i) + x
		local yc = (-8 * i) + y
		if (i % 2 == 0) then
			p.DrawVertexAt(Vector2D.From(xc,yc))
			p.DrawVertexAt(Vector2D.From(xc+dw,yc))
			p.DrawVertexAt(Vector2D.From(xc+dw,yc-dh))
			p.DrawVertexAt(Vector2D.From(xc,yc-dh))
			p.DrawVertexAt(Vector2D.From(xc,yc))
			p.FinishPlacingVertices()
		else
			p.DrawVertexAt(Vector2D.From(xc,yc))
			p.DrawVertexAt(Vector2D.From(xc,yc-dh))
			p.DrawVertexAt(Vector2D.From(xc+dw,yc-dh))
			p.DrawVertexAt(Vector2D.From(xc+dw,yc))
			p.DrawVertexAt(Vector2D.From(xc,yc))
			p.FinishPlacingVertices()
		end
	end
	-- diags
	local d = 2*math.min(w,h) * 8
	p.DrawVertexAt(Vector2D.From(x+d,y-d))
	p.DrawVertexAt(Vector2D.From(x,y))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+32*w-d,y-d))
	p.DrawVertexAt(Vector2D.From(x+32*w,y))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+d,y-h*32+d))
	p.DrawVertexAt(Vector2D.From(x,y-h*32))
	p.FinishPlacingVertices()
	p.DrawVertexAt(Vector2D.From(x+w*32-d,y-h*32+d))
	p.DrawVertexAt(Vector2D.From(x+w*32,y-h*32))
	p.FinishPlacingVertices()
	-- center crosses
	local nc = 2*math.abs(w-h)
	local xs = x + d
	local ys = y - d
	if w > h then
		xs = xs + 8
		ys = ys + 8
	end
	for i=0, nc-1 do
		if w > h then
			p.DrawVertexAt(Vector2D.From(xs,ys))
			p.DrawVertexAt(Vector2D.From(xs-8,ys-8))
			p.FinishPlacingVertices()
			p.DrawVertexAt(Vector2D.From(xs,ys))
			p.DrawVertexAt(Vector2D.From(xs+8,ys-8))
			p.FinishPlacingVertices()
			p.DrawVertexAt(Vector2D.From(xs,ys-16))
			p.DrawVertexAt(Vector2D.From(xs+8,ys-8))
			p.FinishPlacingVertices()
			p.DrawVertexAt(Vector2D.From(xs,ys-16))
			p.DrawVertexAt(Vector2D.From(xs-8,ys-8))
			p.FinishPlacingVertices()
			xs = xs + 16
		else
			p.DrawVertexAt(Vector2D.From(xs-8,ys-8))
			p.DrawVertexAt(Vector2D.From(xs,ys))
			p.FinishPlacingVertices()
			p.DrawVertexAt(Vector2D.From(xs+8,ys-8))
			p.DrawVertexAt(Vector2D.From(xs,ys))
			p.FinishPlacingVertices()
			p.DrawVertexAt(Vector2D.From(xs+8,ys-8))
			p.DrawVertexAt(Vector2D.From(xs,ys-16))
			p.FinishPlacingVertices()
			p.DrawVertexAt(Vector2D.From(xs-8,ys-8))
			p.DrawVertexAt(Vector2D.From(xs,ys-16))
			p.FinishPlacingVertices()
			ys = ys - 16
		end
	end
	-- tele actions
	change_all_linedefs_within_bbox(x+4, x+32*w-4, y-4, y-32*h+4, 208, t)
	-- join sectors
	if w == 2 or h == 2 then
		join_all_sectors_within_bbox(x+20, x+32*w-20, y-20, y-32*h+20)
	else
		join_all_sectors_within_bbox(x-4, x+32*w+4, y-d+12, y-32*(h-1)-4)
		join_all_sectors_within_bbox(x-4, x+32*w+4, y-32+4, y-d+4)
		join_all_sectors_within_bbox(x+28, x+d-4, y-4, y-32*h+4)
		join_all_sectors_within_bbox(x+32*w-d+4, x+32*(w-1)+4, y-4, y-32*h+4)
	end
	-- apply flats / tags to central sectors
	local all_sectors  = Map.GetSectors()
	local all_linedefs = Map.GetLinedefs()
	local v1 = Vector2D.From(0,0)
	local v2 = Vector2D.From(0,0)
	if w == 2 or h == 2 then
		v1 = Vector2D.From(x+24,y-24)
		v2 = Vector2D.From(x+32,y-32)
		s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
		all_sectors[s_ind].tag = t+3
		all_sectors[s_ind].brightness = DARK_VALUE
		all_sectors[s_ind].floortex = FLAT_CENTER
		all_sectors[s_ind].effect = 8
	else
		v1 = Vector2D.From(x+24,y-24)
		v2 = Vector2D.From(x+32,y-32)
		s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
		all_sectors[s_ind].tag = t+1
		all_sectors[s_ind].brightness = DARK_VALUE
		all_sectors[s_ind].floortex = FLAT_RED_HORZ
		all_sectors[s_ind].effect = 8
		v1 = Vector2D.From(x+w*32-24,y-24)
		v2 = Vector2D.From(x+w*32-32,y-32)
		s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
		all_sectors[s_ind].tag = t+2
		all_sectors[s_ind].brightness = DARK_VALUE
		all_sectors[s_ind].floortex = FLAT_RED_VERT
		all_sectors[s_ind].effect = 8
		v1 = Vector2D.From(x+w*32-24,y-h*32+24)
		v2 = Vector2D.From(x+w*32-32,y-h*32+32)
		s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
		all_sectors[s_ind].tag = t+3
		all_sectors[s_ind].brightness = DARK_VALUE
		all_sectors[s_ind].floortex = FLAT_RED_HORZ
		all_sectors[s_ind].effect = 8
		v1 = Vector2D.From(x+24,y-h*32+24)
		v2 = Vector2D.From(x+32,y-h*32+32)
		s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
		all_sectors[s_ind].tag = t+4
		all_sectors[s_ind].brightness = DARK_VALUE
		all_sectors[s_ind].floortex = FLAT_RED_VERT
		all_sectors[s_ind].effect = 8
		--
		v1 = Vector2D.From(x+32,y-32)
		v2 = Vector2D.From(x+40,y-40)
		s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
		all_sectors[s_ind].tag = t+1
		all_sectors[s_ind].brightness = DARK_VALUE
		all_sectors[s_ind].floortex = FLAT_CENTER
		all_sectors[s_ind].effect = 8
		v1 = Vector2D.From(x+w*32-32,y-32)
		v2 = Vector2D.From(x+w*32-40,y-40)
		s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
		all_sectors[s_ind].tag = t+2
		all_sectors[s_ind].brightness = DARK_VALUE
		all_sectors[s_ind].floortex = FLAT_CENTER
		all_sectors[s_ind].effect = 8
		v1 = Vector2D.From(x+w*32-32,y-h*32+32)
		v2 = Vector2D.From(x+w*32-40,y-h*32+40)
		s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
		all_sectors[s_ind].tag = t+3
		all_sectors[s_ind].brightness = DARK_VALUE
		all_sectors[s_ind].floortex = FLAT_CENTER
		all_sectors[s_ind].effect = 8
		v1 = Vector2D.From(x+32,y-h*32+32)
		v2 = Vector2D.From(x+40,y-h*32+40)
		s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
		all_sectors[s_ind].tag = t+4
		all_sectors[s_ind].brightness = DARK_VALUE
		all_sectors[s_ind].floortex = FLAT_CENTER
		all_sectors[s_ind].effect = 8
	end
	-- apply flats / tags to border sectors
	v1 = Vector2D.From(x,y)
	v2 = Vector2D.From(x+8,y-8)
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
	all_sectors[s_ind].tag = t+5
	all_sectors[s_ind].brightness = DARK_VALUE
	all_sectors[s_ind].floortex = FLAT_RED_HORZ
	all_sectors[s_ind].effect = 8
	v1 = Vector2D.From(x+w*32,y)
	v2 = Vector2D.From(x+w*32-8,y-8)
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
	all_sectors[s_ind].tag = t+5
	all_sectors[s_ind].brightness = DARK_VALUE
	all_sectors[s_ind].floortex = FLAT_RED_VERT
	all_sectors[s_ind].effect = 8
	v1 = Vector2D.From(x+w*32,y-h*32)
	v2 = Vector2D.From(x+w*32-8,y-h*32+8)
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
	all_sectors[s_ind].tag = t+5
	all_sectors[s_ind].brightness = DARK_VALUE
	all_sectors[s_ind].floortex = FLAT_RED_HORZ
	all_sectors[s_ind].effect = 8
	v1 = Vector2D.From(x,y-h*32)
	v2 = Vector2D.From(x+8,y-h*32+8)
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
	all_sectors[s_ind].tag = t+5
	all_sectors[s_ind].brightness = DARK_VALUE
	all_sectors[s_ind].floortex = FLAT_RED_VERT
	all_sectors[s_ind].effect = 8
	--
	v1 = Vector2D.From(x+8,y-8)
	v2 = Vector2D.From(x+16,y-16)
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
	all_sectors[s_ind].tag = t+5
	all_sectors[s_ind].brightness = 255
	all_sectors[s_ind].floortex = FLAT_COL_HORZ[color_ind]
	all_sectors[s_ind].effect = 0
	v1 = Vector2D.From(x+w*32-8,y-8)
	v2 = Vector2D.From(x+w*32-16,y-16)
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
	all_sectors[s_ind].tag = t+5
	all_sectors[s_ind].brightness = 255
	all_sectors[s_ind].floortex = FLAT_COL_VERT[color_ind]
	all_sectors[s_ind].effect = 0
	v1 = Vector2D.From(x+w*32-8,y-h*32+8)
	v2 = Vector2D.From(x+w*32-16,y-h*32+16)
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
	all_sectors[s_ind].tag = t+5
	all_sectors[s_ind].brightness = 255
	all_sectors[s_ind].floortex = FLAT_COL_HORZ[color_ind]
	all_sectors[s_ind].effect = 0
	v1 = Vector2D.From(x+8,y-h*32+8)
	v2 = Vector2D.From(x+16,y-h*32+16)
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
	all_sectors[s_ind].tag = t+5
	all_sectors[s_ind].brightness = 255
	all_sectors[s_ind].floortex = FLAT_COL_VERT[color_ind]
	all_sectors[s_ind].effect = 0
	--
	v1 = Vector2D.From(x+16,y-16)
	v2 = Vector2D.From(x+24,y-24)
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
	all_sectors[s_ind].tag = t+1
	all_sectors[s_ind].brightness = 255
	all_sectors[s_ind].floortex = FLAT_COL_HORZ[color_ind]
	all_sectors[s_ind].effect = 0
	v1 = Vector2D.From(x+w*32-16,y-16)
	v2 = Vector2D.From(x+w*32-24,y-24)
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
	all_sectors[s_ind].tag = t+2
	all_sectors[s_ind].brightness = 255
	all_sectors[s_ind].floortex = FLAT_COL_VERT[color_ind]
	all_sectors[s_ind].effect = 0
	v1 = Vector2D.From(x+w*32-16,y-h*32+16)
	v2 = Vector2D.From(x+w*32-24,y-h*32+24)
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
	all_sectors[s_ind].tag = t+3
	all_sectors[s_ind].brightness = 255
	all_sectors[s_ind].floortex = FLAT_COL_HORZ[color_ind]
	all_sectors[s_ind].effect = 0
	v1 = Vector2D.From(x+16,y-h*32+16)
	v2 = Vector2D.From(x+24,y-h*32+24)
	s_ind = get_sector_index_from_linedef_coords(all_sectors, all_linedefs, v1, v2)
	all_sectors[s_ind].tag = t+4
	all_sectors[s_ind].brightness = 255
	all_sectors[s_ind].floortex = FLAT_COL_VERT[color_ind]
	all_sectors[s_ind].effect = 0
	-- mirror floortex onto ceiltex for entire tile
	local sectors_to_ceil = {}
	for i=1, #all_sectors do
		se, sw, sn, ss = get_sector_bounding_box(all_sectors[i])
		if se <= x+32*w+4 and sw >= x-4 and sn <= y+4 and ss >= y-32*h-4 then
			sectors_to_ceil[#sectors_to_ceil+1] = all_sectors[i]
		end
	end
	for i=1, #sectors_to_ceil do
		sectors_to_ceil[i].floorheight = 0
		sectors_to_ceil[i].ceilheight = 128
		sectors_to_ceil[i].ceiltex = sectors_to_ceil[i].floortex
	end
end

-- by default suggest that we build control sectors at position where the user clicked to start the script
p = Pen.FromClick()
p.snaptogrid = true
default_x = p.position.x
default_y = p.position.y

-- by default suggest that we start at the highest tag + 1
max_tag = 0
sectors = Map.GetSectors()
for i=1, #sectors do
	if sectors[i].tag > max_tag then
		max_tag = sectors[i].tag
	end
end
linedefs = Map.GetLinedefs()
for i=1, #linedefs do
	if linedefs[i].tag > max_tag then
		max_tag = linedefs[i].tag
	end
end

-- get parameters
UI.AddParameter("ob_string",  "obstacle string", "")
UI.AddParameter("x_offset",   "control sector coords (x)", default_x)
UI.AddParameter("y_offset",   "control sector coords (y)", default_y)
UI.AddParameter("tag_offset", "starting tag #", tostring(max_tag+1))
UI.AddParameter("fail_tag",   "tag of return teleporter", 12345)
UI.AddParameter("snd_tag1",   "global sound tag 1", 1)
UI.AddParameter("snd_tag2",   "global sound tag 2", 2)
UI.AddParameter("snd_tag3",   "global sound tag 3", 3)
UI.AddParameter("snd_tag4",   "global sound tag 4", 4)
UI.AddParameter("draw_snd",   "draw global sound closets", 0)
UI.AddParameter("only_voodoo","only draw voodoo closet", 0)
parameters = UI.AskForParameters()
control_x    = tonumber(parameters.x_offset)
control_y    = tonumber(parameters.y_offset)
starting_tag = tonumber(parameters.tag_offset)
fail_tag     = tonumber(parameters.fail_tag)
--
global_snd_tag1 = tonumber(parameters.snd_tag1)
global_snd_tag2 = tonumber(parameters.snd_tag2)
global_snd_tag3 = tonumber(parameters.snd_tag3)
global_snd_tag4 = tonumber(parameters.snd_tag4)
--
DRAW_SOUND_CLOSETS = tonumber(parameters.draw_snd)
ONLY_DRAW_VOODOO   = tonumber(parameters.only_voodoo)
--
--s = "t1=(0,0,4,8,1);t2=(0,256,5,8,2);t3=(0,512,6,8,3);e1=[t2,t3];w1=160;e2=[t1,t3];w2=160;e3=[t1,t2];w3=320;"
s = tostring(parameters.ob_string)

TELE_Y_PER_TILE = 256
CONT_Y_PER_TILE = 96
MIN_FINAL_DURATION = 64
MIN_OB_DURATION = 128

---
--- READ INPUT STRING
---
print("parsing input string...")
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
			print("valid tile:", tonumber(t3[1]), tonumber(t3[2]), tonumber(t3[3]), tonumber(t3[4]), tonumber(t3[5]))
			ob_tiles[tonumber(t2[1].sub(t2[1],2))] = {tonumber(t3[1]), tonumber(t3[2]), tonumber(t3[3]), tonumber(t3[4]), tonumber(t3[5])}
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

if ob_duration < MIN_OB_DURATION then
	UI.LogLine("TOTAL OB TIME TOO SHORT: " .. tostring(ob_duration) .. " < " .. tostring(MIN_OB_DURATION))
end

if ob_waits[#ob_waits] < MIN_FINAL_DURATION then
	UI.LogLine("FINAL WAIT TOO SHORT: " .. tostring(ob_waits[#ob_waits]) .. " < " .. tostring(MIN_FINAL_DURATION))
end

---
--- DRAW TILES
---
tile_2_tag = {}
current_tag = starting_tag
current_tele_x = control_x
current_tele_y = control_y
current_cont_x = control_x + 256
current_cont_y = control_y
for k, v in spairs(ob_tiles) do
	if ONLY_DRAW_VOODOO <= 0 then
		print("creating tile " .. k .. ": (" .. tostring(v[1]) .. ", " .. tostring(v[2]) .. "), tag: " .. tostring(current_tag))
		draw_tile(v[1], v[2], v[3], v[4], v[5], current_tag)
		draw_tele_closet(current_tele_x, current_tele_y, current_tag, fail_tag)
		draw_dummies(current_cont_x, current_cont_y, current_tag)
	end
	tile_2_tag[k] = current_tag
	current_tele_y = current_tele_y - TELE_Y_PER_TILE
	current_cont_y = current_cont_y - CONT_Y_PER_TILE
	current_tag   = current_tag + TAGS_PER_TILE
end

---
--- DRAW VOODOO
---
num_tiles = #tile_2_tag
voodoo_x = control_x + 576
voodoo_y = control_y
closet_x = control_x + 576 + (num_tiles * 64) + 64
closet_y = control_y
print("drawing voodoo closet...")
draw_voodoo_frame(voodoo_x, voodoo_y, starting_tag, num_tiles, ob_duration, ONLY_DRAW_VOODOO)
--
current_exp_x = voodoo_x + 16
current_exp_y = voodoo_y - 64
snd_tags      = {global_snd_tag1, global_snd_tag2, global_snd_tag3, global_snd_tag4}
snd_ind       = 1
if DRAW_SOUND_CLOSETS > 0 then
	for i=1, #snd_tags do
		draw_sound_closet(closet_x+(i-1)*128, closet_y, snd_tags[i])
	end
end
for k, v in spairs(ob_expls) do
	current_snd_t = snd_tags[snd_ind]
	print('w:',ob_waits[k], current_exp_y, current_snd_t)
	for k2, v2 in spairs(v) do
		exp_number = tonumber(v2.sub(v2,2))
		print('e:',exp_number,k2,v2)
		explosion_linedefs(current_exp_x+(exp_number-1)*64, current_exp_y, starting_tag+(exp_number-1)*TAGS_PER_TILE, current_snd_t)
	end
	current_exp_y = current_exp_y - ob_waits[k]
	snd_ind = snd_ind + 1
	if snd_ind > #snd_tags then
		snd_ind = 1
	end
end

UI.LogLine("Success!")
