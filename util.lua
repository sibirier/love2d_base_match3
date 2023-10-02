local function onArea(dot_x, dot_y, x,y,w,h)
	return dot_x>=x and dot_x<x+w and dot_y>=y and dot_y<y+h
end

local function putNumberByKeyOrInc(t, key, value)
	if not t[key] then
		t[key] = value
		return 1
	end
	t[key] = t[key] + value
	return 1
end

local function getOrCreate(t, key)
	if not t[key] then
		t[key] = {}
	end
	return t[key]
end

local function getCell(field, x, y, w, h)
	if x>=1 and x<=(w or #field[1]) and y>=1 and y<=(h or #field) and field[y][x]~=-1 then
		return field[y][x]
	end
	return nil
end

local function getXYfromKey(key, w)
	return (key-1)%w+1, math.ceil(key/w)
end

local hex_to_value = {
	['0']=0, ['1']=1, ['2']=2, ['3']=3,
	['4']=4, ['5']=5, ['6']=6, ['7']=7,
	['8']=8, ['9']=9, ['a']=10, ['b']=11,
	['c']=12, ['d']=13, ['e']=14, ['f']=15,
	['A']=10, ['B']=11,
	['C']=12, ['D']=13, ['E']=14, ['F']=15,
}
local function colorRGBFromHex(hex)
	if hex:sub(1,1)=='#' then
		hex = hex:sub(2,-1)
	end
	local t = {}
	for c in hex:gmatch(".") do
		table.insert(t, hex_to_value[c])
	end
	if #t==3 then
		return {r=t[1]/16, g=t[2]/16, b=t[3]/16 }
	end
	if #t==6 then
		return {r=(t[1]*16+t[2])/255, g=(t[3]*16+t[4])/255, b=(t[5]*16+t[6])/255 }
	end
	return {r=1, g=1, b=1}
end

local function copy(t)
	if type(t)=="table" then
		local t1 = {}
		for k,v in pairs(t) do
			t1[k] = copy(v)
		end
		return t1
	end
	return t
end

local function colorUnpack(c) 
	if not c then
		error("no data to unpack: color table is nil")
	end
	return c.r, c.g, c.b
end

return {
	onArea = onArea,
	colorRGBFromHex = colorRGBFromHex,
	copy = copy,
	putNumberByKeyOrInc = putNumberByKeyOrInc,
	getOrCreate = getOrCreate,
	getCell = getCell,
	getXYfromKey = getXYfromKey,
	colorUnpack = colorUnpack,
}