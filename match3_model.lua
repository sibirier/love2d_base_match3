local util = require("util")
local getCell = util.getCell

local playable_templates = {
	hor = {
		{{-2,0},{-1,-1}}, 	-- _-_
		{{-2,0},{-1,1}}, 	-- -_-
		{{-2,-1},{-1,-1}}, 	-- --_
		{{-2,1},{-1,1}}, 	-- __-
		{{-3,0},{-2,0}}, 	-- -- -
		{{-3,0},{-1,0}}, 	-- - --
	},
	ver = {
		{{0,-2},{-1,-1}}, 	-- (
		{{0,-2},{1,-1}}, 	-- )
		{{-1,-2},{-1,-1}}, 	-- =_
		{{1,-2},{1,-1}}, 	-- _=
		{{0,-3},{0,-2}}, 	-- -- -
		{{0,-3},{0,-1}}, 	-- - --
	},
}


local function checkHorTemplates(field, x, y)
	local val = getCell(field, x, y)
	if not val then
		return false
	end
	for i=1,#playable_templates.hor do
		local cells = playable_templates.hor[i]
		local c1, c2 = getCell(field, x+cells[1][1], y+cells[1][2]), getCell(field, x+cells[2][1], y+cells[2][2])
		if c1 and c2 and c1==c2 and c1==val then
			return true
		end
	end
	return false
end

local function checkVerTemplates(field, x, y)
	local val = getCell(field, x, y)
	if not val then
		return false
	end
	for i=1,#playable_templates.ver do
		local cells = playable_templates.ver[i]
		local c1, c2 = getCell(field, x+cells[1][1], y+cells[1][2]), getCell(field, x+cells[2][1], y+cells[2][2])
		if c1 and c2 and c1==c2 and c1==val then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------

local function swapCells(field_data, c1_x, c1_y, c2_x, c2_y)
	local c1 = getCell(field_data, c1_x, c1_y)
	local c2 = getCell(field_data, c2_x, c2_y)
	if not c1 or not c2 then
		return false
	end
	field_data[c1_y][c1_x], field_data[c2_y][c2_x] = field_data[c2_y][c2_x], field_data[c1_y][c1_x]
	return true
end

local function checkNear(cursor_x, cursor_y, target_x, target_y)
	return 	target_x==cursor_x and target_y==cursor_y-1 or 
			target_x==cursor_x and target_y==cursor_y+1 or 
			target_x==cursor_x-1 and target_y==cursor_y or 
			target_x==cursor_x+1 and target_y==cursor_y
end

local function checkPlayable(field_data)
	-- templates, for all, for each non-null cell. getCell fn returns nil if its out of field
	for y=1,#field_data do
		for x=1,#field_data[1] do
			if x>2 and checkHorTemplates(field_data, x,y) then
				return true
			end
			if y>2 and checkVerTemplates(field_data, x,y) then
				return true
			end
		end
	end
	return false
end


local function checkLines(field_data)
	-- after swap check lines availability at field and return bool, cell positions & count of each type
	local height = #field_data
	local width = #field_data[1]
	local cells = {}
	local totals = {}
	for y=1,height do
		for x = 1,width do
			local val = getCell(field_data, x, y, width, height)
			if val~=0 and x>2 and val==getCell(field_data, x-1, y, width, height) and val==getCell(field_data, x-2, y, width, height) then
				util.putNumberByKeyOrInc(totals, val, util.putNumberByKeyOrInc(util.getOrCreate(cells, val), (y-1)*width+x, 1))
				util.putNumberByKeyOrInc(totals, val, util.putNumberByKeyOrInc(util.getOrCreate(cells, val), (y-1)*width+x-1, 1))
				util.putNumberByKeyOrInc(totals, val, util.putNumberByKeyOrInc(util.getOrCreate(cells, val), (y-1)*width+x-2, 1))
			end
			if val~=0 and y>2 and val==getCell(field_data, x, y-1, width, height) and val==getCell(field_data, x, y-2, width, height) then
				util.putNumberByKeyOrInc(totals, val, util.putNumberByKeyOrInc(util.getOrCreate(cells, val), (y-1)*width+x, 1))
				util.putNumberByKeyOrInc(totals, val, util.putNumberByKeyOrInc(util.getOrCreate(cells, val), (y-2)*width+x, 1))
				util.putNumberByKeyOrInc(totals, val, util.putNumberByKeyOrInc(util.getOrCreate(cells, val), (y-3)*width+x, 1))
			end
		end
	end
	local total = 0
	for k,v in pairs(totals) do
		total = total + v
	end
	if total>0 then
		return true, cells, totals
	else
		return false
	end
end

local function extractCells(lines_cells, cells)
	for k,v in pairs(lines_cells) do
		for k1, v1 in pairs(v) do
			util.putNumberByKeyOrInc(cells, k1, v1)
		end
	end
end

-- delete united lines, move cells top down and refill it
local function harvestLines(field_data, cells) -- positions can be nil
	if not cells then
		local _, c = checkLines(field_data)
		cells = {}
		extractCells(c, cells)
	end
	local field_width = #field_data[1]
	for k,v in pairs(cells) do
		local x,y = util.getXYfromKey(k, field_width)
		-- print("slkdhfkld: ",x,y, k, field_width)
		field_data[y][x] = 0
	end
end

local function refillCells(field_data, elements)
	local field_width = #field_data[1]

	local len = #elements
	for x=1,field_width do
		local col = {}
		for y=1,#field_data do
			if field_data[y][x]~=0 then
				table.insert(col, field_data[y][x])
			end
		end
		if #col<#field_data then
			for i=1,#field_data-#col do
				table.insert(col, 1, elements[math.random(1, len)].type)
			end
			for y=1,#field_data do
				field_data[y][x] = col[y]
			end
		end
	end
end

-- return ready to use field
local function genField(w, h, elements)
	local ret = {}
	local len = #elements
	for y = 1,h do
		ret[y] = {}
		for x = 1,w do
			ret[y][x] = elements[math.random(1, len)].type
		end
	end

	local i,j=0,0
	repeat
		i=i+1
		local hasLines, lines_cells = checkLines(ret)
		while hasLines do
			local cells = {}
			extractCells(lines_cells, cells)
			j=j+1
			harvestLines(ret, cells)
			refillCells(ret, elements)
			hasLines, lines_cells = checkLines(ret)
			-- if j>30 then
			-- 	break
			-- end
		end
		-- if i>30 then
		-- 	break
		-- end

	until checkPlayable(ret)

	return ret
end

local function checkPosInCells(field_data, x, y, lines_cells)
	if not lines_cells then
		_, lines_cells = checkLines(field_data)
		if not lines_cells then
			return false
		end
	end
	local key = (y-1)*#field_data[1]+x
	for k,v in pairs(lines_cells) do
		if v[key] then
			return true
		end
	end
	return false
end

return {
	genField = genField,
	checkLines = checkLines,
	extractCells = extractCells,
	harvestLines = harvestLines,
	refillCells = refillCells,
	checkPlayable = checkPlayable,
	checkNear = checkNear,
	swapCells = swapCells,
	checkPosInCells = checkPosInCells,
}