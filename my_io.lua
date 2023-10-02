local inited = false

local function init(name)
	if type(name)~="string" then
		error("name expected, got wrong value")
	end
	love.filesystem.setIdentity(name)
	inited = true
end

local function inspect(t, init)
	init = init or ""
	local char = ", "
	local retstr = ""
	if type(t) == "string" then
		if string.find(t,"'", 1, true) or string.find(t,'"', 1, true) then
			return string.format(" [[%s]] ", t)
		else
			return string.format("'%s'", t)
		end
	elseif type(t) ~= "table" then
		return tostring(t or "nil")
	else
		retstr=retstr.."{\n"
		for k,v in pairs(t) do
			if v~=nil then
				retstr=retstr..(init.."  ").."["..inspect(k).."] = "..inspect(v, init.."  ")..char.."\n"
			end
		end
		retstr = retstr..init.."}"
	end
	return retstr
end

local function dump(t)
	return print(inspect(t))
end

local function serialize(t)
	local char = ","
	local retstr = ""
	if type(t)=="string" then
		if string.find(t,"[", 1, true) then
			t = string.gsub(t, "[([)]", "\\[")
		end
		if string.find(t,"]", 1, true) then
			t = string.gsub(t, "]", "\\]")
		end
		if string.find(t,"'", 1, true) then
			return string.format("'%s'", string.gsub(t, "(')", "\\'"))
		else 
			return string.format("'%s'", t)
		end
	elseif type(t)=="boolean" then
		return t and "true" or "false"
	elseif type(t)~="table" then
		return tostring(t)
	else
		retstr=retstr.."{"
		for k,v in pairs(t) do
			if v~=nil then
				retstr=retstr.."["..(serialize(k)).."]="..(serialize(v))..char..""
			end
		end
		retstr = retstr.."}"
	end
	return retstr
end

local function get(where, path)
	if type(path)~="table" then
		return 
	else
		local ret = where
		for i=1,#path do
			ret=ret[path[i]]
		end
		return ret
	end
end

local function load(path)
	if not inited then
		error("not initialized, cannot load")
	end
	local l = loadstring or load
	local file = love.filesystem.load(path or "save")
	if not file then
		return {}
	end
	return file() or {} --ret
end

local function save(db, path)
	if not inited then
		error("not initialized, cannot save")
	end
	local file = pcall(love.filesystem.load,path)
	if not file then
		local f = love.filesystem.newFile(path or "save", "w")
		f:close()
	end
	love.filesystem.write(path, "return "..serialize(db or {}))
end

return {
	save = save,
	load = load,
	dump = dump,
	inspect = inspect,
	get = get,
	serialize = serialize,
	init = init,
}