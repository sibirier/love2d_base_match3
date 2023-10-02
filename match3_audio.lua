local volume_normalizer = 0.4
local sounds = {
	stones = love.audio.newSource("res/audio/stones.mp3", "static"),
	keys = love.audio.newSource("res/audio/keys.mp3", "static"),
	fall = love.audio.newSource("res/audio/fall.mp3", "static"),
}

local sound_state = {
	next_map = {
		stones = "keys",
		keys = "fall",
		fall = "stones",
	},
	mute = false,
	current = "stones",
}


local function mute()
	sound_state.mute = true
end

local function unmute()
	sound_state.mute = false
end

local function setVolume(value)
	if value>0 then
		unmute()
	end
	for k,v in pairs(sounds) do
		v:setVolume(volume_normalizer*value)
	end
end

setVolume(1)

return {
	setVolume = setVolume,
	mute = mute,
	unmute = unmute,
	playable = {
		stones = function()
			if sound_state.mute then
				return
			end
			sounds.stones:stop()
			sounds.stones:play()
		end,
		fall = function()
			if sound_state.mute then
				return
			end
			sounds.fall:stop()
			sounds.fall:play()
		end,
	},
}