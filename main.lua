local util = require("util")
local drawer = require("match3_drawer")
local model = require("match3_model")
local audio = require("match3_audio")
local my_io = require("my_io")
local scenes = require("scenes")

local window_data = {
	offset = {x=0, y=0},
	origin_data = {w = 1200, h = 800, format = {w=4, h=3}},
	current_data = {w=1200, h = 800},
	scale = 1.0,
	fullscreen = false,
	window_rect = {w=1200, h=800, x=0, y=0},
}

local window_mode = {fullscreen=window_data.fullscreen, resizable = true, minwidth = window_data.origin_data.w, minheight = window_data.origin_data.h}
local debug_print_active = false

local has_unharvested_lines = false
local playable = true

local elements = {
	{["type"] = 1, color = util.colorRGBFromHex("C763DB"), value = 1, order = 1},
	{["type"] = 2, color = util.colorRGBFromHex("E88F23"), value = 1, order = 2},
	{["type"] = 3, color = util.colorRGBFromHex("49AB1F"), value = 1, order = 3},
	{["type"] = 4, color = util.colorRGBFromHex("C72015"), value = 1, order = 4},
	{["type"] = 5, color = util.colorRGBFromHex("374DDB"), value = 1, order = 5},
	-- {["type"] = 6, color = util.colorRGBFromHex("171D9B"), value = 1, order = 6},
}

local ui_data = {
	cells = {},
	text_color = util.colorRGBFromHex("ffc"),
	field_background = {color = util.colorRGBFromHex("454")},
	score_background = {color = {r=0.25, g=0.22, b=0.2}},
	cursor = {color = {r=0.85, g=0.9, b=0.4}},
	cell_props = {
		max_size = 50,
	}
}

local game_data = {
	field_size = {
		w = 12,
		h = 9,
	},
	field = {
		current = nil,
		prev = nil,
	},
	cursor = {
		coord = {x=1, y=1},
		enable = false,
	},
	score = {
		total = 0,
		elements = {},
	},
	game_state = {
		state = "play",
		started = false,
		field_locked = false,
		combo_state = false,
		swap_target = {0,0,},
	},
	service_data = {
		lines_cells = nil,
		swap_move_cells = nil,
		harvest_move_cells = nil,
		refill_move_cells = nil,
		next_state_after_delay = nil,
	},
	sound_data = {
		volume = 0.2,
		mute = false,
	}
}

for k,v in ipairs(elements) do
	ui_data.cells[v.type] = {color = v.color, order = v.order,}
	game_data.score.elements[v.type] = {value = 0}
end

local draw_rect_field = {x=window_data.offset.x+30, y=window_data.offset.y+90, w=window_data.current_data.w-window_data.offset.x*2-60, h=window_data.current_data.h-window_data.offset.y*2-(90+30)}
local draw_rect_score = {x=0, y=0, w=window_data.current_data.w, h=60}

local changeState

local function lockField()
	game_data.game_state.field_locked = true
end

local function unlockField()
	game_data.game_state.field_locked = false
end

local function backupField()
	for y,line in ipairs(game_data.field.current) do
		for x,v in ipairs(line) do
			game_data.field.prev[y][x] = v
		end
	end
end

local function updateAnimationState(total_anim_time)
	game_data.game_state.animation_time_current = 0
	game_data.game_state.animation_time_total = total_anim_time
end

local game_states = {
	play = {
		data = {
			onStart = function()
				unlockField()
				game_data.service_data.next_state_after_delay = nil
				game_data.game_state.combo_state = false
				if not model.checkPlayable(game_data.field.current) then
					changeState("rebuild")
				end
			end
		},
		draw_data = {
			draw = function()
				drawer.drawField(draw_rect_field, ui_data, game_data.field.current)
			end
		},
	},
	swap_cells = {
		data = {
			onStart = function()
				-- backupField()
				game_data.service_data.swap_move_cells = drawer.getDrawDataSwapCells(game_data.field.current, game_data.cursor.coord.x, game_data.cursor.coord.y, game_data.game_state.swap_target.x, game_data.game_state.swap_target.y)
				updateAnimationState(0.15)
				model.swapCells(game_data.field.current, game_data.cursor.coord.x, game_data.cursor.coord.y, game_data.game_state.swap_target.x, game_data.game_state.swap_target.y)
			end,
			update = function(dt)
				game_data.game_state.animation_time_current = game_data.game_state.animation_time_current + dt
				return game_data.game_state.animation_time_current>=game_data.game_state.animation_time_total -- fire onEnd
			end,
			onEnd = function()
				game_data.service_data.swap_move_cells = nil
				has_unharvested_lines, game_data.service_data.lines_cells = model.checkLines(game_data.field.current)
				if has_unharvested_lines and (
					model.checkPosInCells(game_data.field.current, game_data.game_state.swap_target.x, game_data.game_state.swap_target.y, game_data.service_data.lines_cells) 
					or model.checkPosInCells(game_data.field.current, game_data.cursor.coord.x, game_data.cursor.coord.y, game_data.service_data.lines_cells)
				) then
					backupField()
					changeState("harvest")
				else
					changeState("back_swap_cells")
				end
			end,
		},
		draw_data = {
			draw = function()
				if game_data.service_data.swap_move_cells then
					drawer.drawFieldAnimated_SwapCells(draw_rect_field, ui_data, game_data.field.current, game_data.game_state.animation_time_current, game_data.game_state.animation_time_total, game_data.service_data.swap_move_cells)
				else
					drawer.drawField(draw_rect_field, ui_data, game_data.field.current)
				end
			end
		},
	},
	back_swap_cells = {
		data = {
			onStart = function()
				-- backupField()
				game_data.service_data.swap_move_cells = drawer.getDrawDataSwapCells(game_data.field.current, game_data.cursor.coord.x, game_data.cursor.coord.y, game_data.game_state.swap_target.x, game_data.game_state.swap_target.y)
				updateAnimationState(0.15)
				model.swapCells(game_data.field.current, game_data.cursor.coord.x, game_data.cursor.coord.y, game_data.game_state.swap_target.x, game_data.game_state.swap_target.y)
			end,
			update = function(dt)
				game_data.game_state.animation_time_current = game_data.game_state.animation_time_current + dt
				return game_data.game_state.animation_time_current>=game_data.game_state.animation_time_total -- fire onEnd
			end,
			onEnd = function()
				game_data.service_data.swap_move_cells = nil
				changeState("play")
			end
		},
		draw_data = {
			draw = function()
				if game_data.service_data.swap_move_cells then
					drawer.drawFieldAnimated_SwapCells(draw_rect_field, ui_data, game_data.field.current, game_data.game_state.animation_time_current, game_data.game_state.animation_time_total, game_data.service_data.swap_move_cells)
				else
					drawer.drawField(draw_rect_field, ui_data, game_data.field.current)
				end
			end
		},
	},
	harvest = {
		data = {
			onStart = function()
				if has_unharvested_lines then
					game_data.service_data.harvest_move_cells = drawer.getDrawDataHarvestCells(game_data.field.current, game_data.service_data.lines_cells)
					updateAnimationState(0.2)
					for k,v in pairs(game_data.service_data.lines_cells) do
						for k1, v1 in pairs(v) do
							game_data.score.elements[k].value = game_data.score.elements[k].value + v1
						end
					end
					local cells = {}
					model.extractCells(game_data.service_data.lines_cells, cells)
					backupField()
					model.harvestLines(game_data.field.current, cells)
					
					if game_data.game_state.combo_state then
						audio.playable.stones()
					else
						audio.playable.fall()
					end
				end
			end,
			update = function(dt)
				game_data.game_state.animation_time_current = game_data.game_state.animation_time_current + dt
				return game_data.game_state.animation_time_current>=game_data.game_state.animation_time_total -- fire onEnd
			end,
			onEnd = function()
				game_data.service_data.harvest_move_cells = nil
				backupField()
				changeState("refill")
			end
		},
		draw_data = {
			draw = function()
				if game_data.service_data.harvest_move_cells then
					drawer.drawFieldAnimated_HarvestCells(draw_rect_field, ui_data, game_data.field.prev, game_data.game_state.animation_time_current, game_data.game_state.animation_time_total, game_data.service_data.harvest_move_cells)
				else
					drawer.drawField(draw_rect_field, ui_data, game_data.field.prev)
				end
			end
		},
	},
	refill = {
		data = {
			onStart = function()	
				backupField()
				updateAnimationState(0.2)
				model.refillCells(game_data.field.current, elements)
				game_data.service_data.refill_move_cells = drawer.getDrawDataRefillCells(game_data.field.prev, game_data.field.current)
			end,
			update = function(dt)
				game_data.game_state.animation_time_current = game_data.game_state.animation_time_current + dt
				return game_data.game_state.animation_time_current>=game_data.game_state.animation_time_total -- fire onEnd
			end,
			onEnd = function()
				has_unharvested_lines, game_data.service_data.lines_cells = model.checkLines(game_data.field.current)
				game_data.service_data.refill_move_cells = nil
				if has_unharvested_lines then
					backupField()
					game_data.service_data.next_state_after_delay = "harvest"
					changeState("delay")
					game_data.game_state.combo_state = true
				else
					playable = model.checkPlayable(game_data.field.current)
					changeState("play")
				end
			end
		},
		draw_data = {
			draw = function()
				if game_data.service_data.refill_move_cells then
					drawer.drawFieldAnimated_RefillCells(draw_rect_field, ui_data, game_data.field.current, game_data.game_state.animation_time_current, game_data.game_state.animation_time_total, game_data.service_data.refill_move_cells)
				else
					drawer.drawField(draw_rect_field, ui_data, game_data.field.prev)
				end
			end
		},
	},
	delay = {
		data = {
			onStart= function()
				updateAnimationState(0.15)
			end,
			update = function(dt)
				game_data.game_state.animation_time_current = game_data.game_state.animation_time_current + dt
				return game_data.game_state.animation_time_current>=game_data.game_state.animation_time_total -- fire onEnd
			end,
			onEnd = function()
				changeState(game_data.service_data.next_state_after_delay or "harvest")
			end
		}
	},
	rebuild = {
		data = {
			onStart= function()
				-- show popup "has no moves, field will rebuild!"
				game_data.field.current = model.genField(game_data.field.w, game_data.field.h, elements)
			end,
			update = function(dt)
				return true
			end,
			onEnd = function()

			end
		}
	},

	-- later
	skill_use = {
		data = {
			onStart = function()
				
			end,
			update = function(dt)
				return true
			end,
			onEnd = function()
				
			end
		}
	},
	over = {
		data = {
		}
	},
}

local function recalcUIData()
	draw_rect_field.x = window_data.offset.x+30
	draw_rect_field.y = window_data.offset.y+90
	draw_rect_field.w = window_data.current_data.w-window_data.offset.x*2-60
	draw_rect_field.h = window_data.current_data.h-window_data.offset.y*2-(90+30)
	draw_rect_score.w = window_data.current_data.w
end

local function _load()
	local a = my_io.load("save")
	if not a or not next(a) or not a.field or not a.settings or not next(a.settings) or not a.score or not next(a.score) then
		game_data.field.current = model.genField(game_data.field_size.w, game_data.field_size.h, elements)
		game_data.field.prev = util.copy(game_data.field.current)

		audio.setVolume(0.2)
		return false
	else
		game_data.field.current = a.field
		game_data.field.prev = util.copy(game_data.field.current)
		game_data.score = a.score
		window_mode.fullscreen = a.settings.fullscreen
		window_data.fullscreen = a.settings.fullscreen
		window_data.current_data.w = a.settings.width
		window_data.current_data.h = a.settings.height
		if a.settings.sound then
			game_data.sound_data = a.settings.sound
			audio.setVolume(a.settings.sound.volume)
			if a.settings.sound.mute then
				audio.mute()
			end
		end
		return true
	end
end

local function _save()
	my_io.save(
		{
			field = game_data.field.current, 
			settings = {
				fullscreen = window_mode.fullscreen, 
				width = window_data.current_data.w, 
				height = window_data.current_data.h,
				sound = game_data.sound_data,
			},
			score = game_data.score,
		},
	"save")
end


-----------------------------  functions  -----------------------------------

changeState = function(state)
	if not game_states[state] then
		error("has not game state "..tostring(state))
	end
	game_data.game_state.state = state
	game_data.game_state.started = false
end

local function checkFieldGameState(field_x, field_y)
	if game_data.game_state.field_locked then
		return 
	end
	local check_near = model.checkNear(game_data.cursor.coord.x, game_data.cursor.coord.y, field_x, field_y)
	if not game_data.cursor.enable or not check_near then
		game_data.cursor.enable = true
		game_data.cursor.coord.x = field_x
		game_data.cursor.coord.y = field_y
	else
		if check_near and game_data.cursor.enable then
			game_data.game_state.swap_target.x = field_x
			game_data.game_state.swap_target.y = field_y

			lockField()
			changeState("swap_cells")
		end
		game_data.cursor.enable = false
	end
end

------------------------------  callbacks  ------------------------------------

function love.load(args, unfilteredArgs)
	my_io.init("match3_test")

	math.randomseed(os.time())
	
	love.window.setTitle("Match 3")
	love.graphics.setNewFont(16)
	love.graphics.setBackgroundColor(0.3, 0.25, 0.22)
	_load()
	recalcUIData()

	love.window.setMode(window_data.current_data.w, window_data.current_data.h, window_mode)
end

function love.update(dt)
	if not game_data.game_state.started and game_states[game_data.game_state.state].data.onStart then
		game_data.game_state.started = true
		game_states[game_data.game_state.state].data.onStart()
	end
	if game_states[game_data.game_state.state].data.update then
		if game_states[game_data.game_state.state].data.update(dt) and game_states[game_data.game_state.state].data.onEnd then
			game_states[game_data.game_state.state].data.onEnd()
		end
	end
end

function love.draw()
	drawer.drawScore(draw_rect_score, ui_data, game_data.score.elements)
	if game_states[game_data.game_state.state].draw_data and  game_states[game_data.game_state.state].draw_data.draw then
		game_states[game_data.game_state.state].draw_data.draw()
	else
		game_states.play.draw_data.draw()
	end

	if game_data.cursor.enable then
		drawer.drawCursorFrame(draw_rect_field, ui_data, game_data.field.current, game_data.cursor.coord.x, game_data.cursor.coord.y)
	end
	if debug_print_active then
		love.graphics.setColor(0.91,0.85,0.6)
		love.graphics.print(string.format("offset: x=%i, y=%i, scale=%i%%", window_data.offset.x, window_data.offset.y, window_data.scale*100), 10, 10)
		love.graphics.print(string.format("cur: w=%i, h=%i", window_data.current_data.w, window_data.current_data.h), 10, 28)
		love.graphics.print(string.format("pos: x=%i, y=%i", window_data.window_rect.x, window_data.window_rect.y), 10, 44)
		love.graphics.print(string.format("cursor: x=%i, y=%i, enable: %s", game_data.cursor.coord.x, game_data.cursor.coord.y, game_data.cursor.enable and "true" or "false"), 10, 144)
		love.graphics.print(string.format("\tcell value: %s", game_data.cursor.enable and tostring(game_data.field.current[game_data.cursor.coord.y][game_data.cursor.coord.x]) or "none"), 10, 162)
		love.graphics.print(string.format("has_unharvested_lines: %s", has_unharvested_lines and "true" or "false"), 10, 192)
		love.graphics.print(string.format("playable: %s", playable and "true" or "false"), 10, 212)
		love.graphics.print(string.format("game state: %s", game_data.game_state.state), 10, 232)
		drawer.drawDebugField(draw_rect_field, ui_data, game_data.field.current)
	end
end

function love.resize(w, h)
	window_data.current_data.w = w
	window_data.current_data.h = h
	if not window_data.fullscreen then
		window_data.window_rect.w = w
		window_data.window_rect.h = h
	end	

	if w/window_data.origin_data.format.w<h/window_data.origin_data.format.h then
		-- ver offset
		local h_origin = h
		h = (w*window_data.origin_data.format.h)/window_data.origin_data.format.w
		window_data.scale = w/window_data.origin_data.w
		window_data.offset.x = 0
		window_data.offset.y = math.floor((h_origin-h)/2)
	else
		-- hor offset
		local w_origin = w
		w = (h*window_data.origin_data.format.w)/window_data.origin_data.format.h
		window_data.scale = h/window_data.origin_data.h
		window_data.offset.x = math.floor((w_origin-w)/2)
		window_data.offset.y = 0
	end
	recalcUIData()
end

function love.mousemoved(x, y, dx, dy, istouch)
	if game_data.cursor.enable and love.mouse.isDown(1) then
		local field_x, field_y = drawer.getXYfromMouseCoord(draw_rect_field, ui_data, game_data.field.current, x, y)
		if field_x then
			checkFieldGameState(field_x, field_y)
		end
	end
end

function love.mousepressed(x, y, button, istouch, presses)
	if button == 1 then
		local field_x, field_y = drawer.getXYfromMouseCoord(draw_rect_field, ui_data, game_data.field.current, x, y)
		if field_x then
			checkFieldGameState(field_x, field_y)
		else
			game_data.cursor.enable = false
		end
	elseif button == 2 then
		if game_data.cursor.enable then
			game_data.cursor.enable = false
		end
	end
end

function love.keypressed(key, scancode, isrepeat)
	if love.keyboard.isDown("lctrl") and key=="q" or key=="escape" then
		love.event.quit()
	end
	if key=="m" then
		game_data.sound_data.mute = not game_data.sound_data.mute
		if game_data.sound_data.mute then
			audio.mute()
		else
			audio.unmute()
		end
	end
	if key=="f3" and love.keyboard.isDown("lalt") then
		debug_print_active = not debug_print_active
	end
	if key=="f11" then
		if not window_data.fullscreen then
			window_data.window_rect.x, window_data.window_rect.y, window_mode.display = love.window.getPosition()
		end
		window_data.fullscreen = not window_data.fullscreen
		window_mode.fullscreen = window_data.fullscreen
		love.window.setFullscreen(window_data.fullscreen)
		if not window_data.fullscreen then
			love.window.setMode(window_data.window_rect.w, window_data.window_rect.h, window_mode)
			love.window.setPosition(window_data.window_rect.x, window_data.window_rect.y, window_mode.display)
			love.resize(window_data.window_rect.w, window_data.window_rect.h)
		end
	end
end

function love.quit()
	_save()
end