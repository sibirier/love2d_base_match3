local scenes = {}
local popups = {}
local opened_popups = {}
local has_opened_popup = false
local inited = false
local current_scene

local function validateSceneOrPopup(s)
	if not s.draw or not (s.mousePressed or s.mouseReleased or s.keyPressed) then
		error("scene must be drawable and interactive")
	end
end

local function init(scenes, popups)
	if inited then
		error("function init can call only once")
	end
	if not s or not next(s) then
		error()
	end
	for k,v in pairs(s) do
		validateSceneOrPopup(v)
	end
	for k,v in pairs(s) do
		scenes[k] = v
	end
	inited = true
end

local function addScene(name, s)
	validateSceneOrPopup(s)
	if scenes[name] then
		error("scene '"..name.."' already exist")
	end
	scenes[name] = s
end

local function addPopup(name, s)
	validateSceneOrPopup(s)
	if popups[name] then
		error("popup '"..name.."' already exist")
	end
	popups[name] = s
end

local function removeScene(name)
	if not scenes[name] then
		error("scene '"..name.."' not found")
	end
	scenes[name] = nil
end

local function removePopup(name)
	if not popups[name] then
		error("popup '"..name.."' not found")
	end
	popups[name] = nil
end

local function getSceneNames()
	local ret = {}
	for k,v in pairs(scenes) do
		ret[k] = k
	end
	return ret
end

local function getPopupNames()
	local ret = {}
	for k,v in pairs(popups) do
		ret[k] = k
	end
	return ret
end

local function gotoScene(name)
	if not scenes[name] then
		error("has no scene with name '"..name.."'")
	end
	current_scene = name
end

local function openPopup(name)
	if not popups[name] then
		error("popup '"..name.."' not found")
	end
	has_opened_popup = true
	opened_popups[name] = popups[name]
	if popups[name].init then
		popups[name]:init()
	end
end

local function closePopup(name)
	if not popups[name] then
		error("popup '"..name.."' not found")
	end
	local ret = opened_popups[name] and true or false
	local ret_value = opened_popups[name] and opened_popups[name].close and opened_popups[name]:close() or nil
	opened_popups[name] = nil
	if not next(opened_popups) then
		has_opened_popup = false
	end
	return ret, ret_value
end

local function closeAllPopups()
	for name,v in pairs(opened_popups) do
		if opened_popups[name].close then
			opened_popups[name]:close()
		end
		opened_popups[name] = nil
	end
	has_opened_popup = false
end

local function genCallback(name)
	return function(...)
		if scenes[current_scene][name] then
			scenes[current_scene][name](scenes[current_scene][name], ...)
		end
		if has_opened_popup then
			for k in pairs(opened_popups) do
				if popups[k][name] then
					popups[k][name](popups[k][name], ...)
				end
			end
		end
	end
end

local callback_names = {
	mousePressed = "mousepressed",
	mouseReleased = "mousereleased",
	keyPressed = "keypressed",
	keyReleased = "keyreleased",
	mouseMoved = "mousemoved",
	draw = "draw",
	update = "update",
}

local callbacks = {}
for v in pairs(callback_names) do
	callbacks[v] = genCallback(v)
end

local function fillStandartCallbacks()
	if not love then
		return
	end
	for k,v in pairs(callback_names) do
		love[v] = callbacks[k]
	end
end

local ret = {
	init = init,
	fillStandartCallbacks = fillStandartCallbacks,
	getScenesList = getScenesList,
	gotoScene = gotoScene,
	addScene = addScene,
	addPopup = addPopup,
	removeScene = removeScene,
	removePopup = removePopup,
	getSceneNames = getSceneNames,
	getPopupNames = getPopupNames,
	openPopup = openPopup,
	closePopup = closePopup,
	closeAllPopups = closeAllPopups,
}

for k,v in pairs(callbacks) do
	if ret[k] then
		error(k.." yet added to scenes API")
	end
	ret[k] = v
end

return ret