local util = require("util")

local default_color = {r = 0.35, g = 0.25, b = 0.25}
local colorUnpack = util.colorUnpack

local function getFieldUIData(rect, ui_data, field_data, gap_size)
	local cells = {w = #field_data[1], h = #field_data}
	local real_rect = {x=rect.x, y=rect.y, offset = {x=0, y=0}, w=math.min(math.min(rect.w/cells.w, rect.h/cells.h), ui_data.cell_props.max_size)*cells.w+(cells.w-1)*gap_size, h=math.min(math.min(rect.w/cells.w, rect.h/cells.h), ui_data.cell_props.max_size)*cells.h+(cells.h-1)*gap_size}
	real_rect.offset.x = math.floor((rect.w-real_rect.w)/2)
	real_rect.offset.y = math.floor((rect.h-real_rect.h)/2)
	local cell_size = {w = (real_rect.w-(cells.w-1)*gap_size)/cells.w, h = (real_rect.h-(cells.h-1)*gap_size)/cells.h}
	return cells, real_rect, cell_size
end

local function drawCell(x, y, real_rect, field_data, ui_data, cell_size, gap_size)
	love.graphics.setColor(colorUnpack( (ui_data.cells[field_data[y][x]] and ui_data.cells[field_data[y][x]].color or default_color) ))
	love.graphics.rectangle("fill", real_rect.x+real_rect.offset.x+(x-1)*(cell_size.w+gap_size), real_rect.y+real_rect.offset.y+(y-1)*(cell_size.h+gap_size), cell_size.w, cell_size.h)
end

local function drawMovingCell(x, y, real_rect, field_data, ui_data, cell_size, gap_size, dx, dy)
	love.graphics.setColor(colorUnpack( (ui_data.cells[field_data[y][x]] and ui_data.cells[field_data[y][x]].color or default_color) ))
	love.graphics.rectangle("fill", real_rect.x+real_rect.offset.x+(x-1)*(cell_size.w+gap_size)+dx, real_rect.y+real_rect.offset.y+(y-1)*(cell_size.h+gap_size)+dy, cell_size.w, cell_size.h)
end

local function drawHarvestingCell(x, y, real_rect, field_data, ui_data, cell_size, gap_size, progress)
	love.graphics.setColor(colorUnpack( (ui_data.cells[field_data[y][x]] and ui_data.cells[field_data[y][x]].color or default_color) ))
	local dx,dy = cell_size.w*progress/2, cell_size.h*progress/2
	love.graphics.rectangle("fill", real_rect.x+real_rect.offset.x+(x-1)*(cell_size.w+gap_size)+dx, real_rect.y+real_rect.offset.y+(y-1)*(cell_size.h+gap_size)+dy, cell_size.w*(1-progress), cell_size.h*(1-progress))
end

local function drawField(rect, ui_data, field_data)
	local gap_size = 3
	local cells, real_rect, cell_size = getFieldUIData(rect, ui_data, field_data, gap_size)
	love.graphics.setColor(colorUnpack(ui_data.field_background.color or default_color))
	love.graphics.rectangle("fill", real_rect.x+real_rect.offset.x, real_rect.y+real_rect.offset.y, real_rect.w, real_rect.h)
	for x = 1,cells.w do 
		for y = 1,cells.h do
			drawCell(x, y, real_rect, field_data, ui_data, cell_size, gap_size)
		end
	end
end 

local function drawDebugField(rect, ui_data, field_data)
	local gap_size = 3
	local cells, real_rect, cell_size = getFieldUIData(rect, ui_data, field_data, gap_size)
	love.graphics.setColor(0, 0, 0)
	for i = 1,cells.w do 
		for j = 1,cells.h do
			love.graphics.print(field_data[j][i], real_rect.x+real_rect.offset.x+(i-1)*(cell_size.w+gap_size)+5, real_rect.y+real_rect.offset.y+(j-1)*(cell_size.h+gap_size)+10)
		end
	end
end 

local function drawScoreCell(cell_x, cell_y, ui_data, cell_key, cell_value, cell_size, text_size)
	love.graphics.setColor(colorUnpack(ui_data.cells[cell_key].color or default_color))
	love.graphics.rectangle("fill", cell_x, cell_y, cell_size, cell_size)
	love.graphics.setColor(colorUnpack(ui_data.text_color or default_color))
	love.graphics.printf(tostring(cell_value.value), cell_x+cell_size+10, cell_y+math.floor((cell_size-love.graphics.getFont():getHeight())/2), text_size-10, "left")
end

local function drawScore(rect, ui_data, data)
	love.graphics.setColor(colorUnpack(ui_data.score_background.color))
	love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
	local cell_size = 40
	local text_size = 80
	local margin_size = 5
	local gap_size = 10
	local n_elements = 0
	for k,v in pairs(data) do
		n_elements = n_elements + 1
	end
	local width = (n_elements-1)*gap_size+n_elements*(cell_size+text_size)
	local height = cell_size
	local x = rect.x+math.max(0, margin_size+math.floor((rect.w-width)/2))
	local y = rect.y+math.max(margin_size, math.floor((rect.h-height)/2) )
	for k,v in pairs(data) do
		drawScoreCell(x+(ui_data.cells[k].order-1)*(text_size+cell_size+gap_size), y, ui_data, k, v, cell_size, text_size)
	end
end 

-- transform mouse' x,y to field coords by drawing function' rules
local function getXY(rect, ui_data, field_data, x, y)
	local gap_size = 3
	local cells, real_rect, cell_size = getFieldUIData(rect, ui_data, field_data, gap_size)
	local field_x = x-real_rect.x-real_rect.offset.x
	local field_y = y-real_rect.y-real_rect.offset.y
	if not (field_x>=0 and field_x<((cell_size.w+gap_size)*cells.w-gap_size) and field_y>=0 and field_y<((cell_size.h+gap_size)*cells.h-gap_size)) then
		return nil
	end
	return math.ceil((field_x+1)/(cell_size.w+gap_size)), math.ceil((field_y+1)/(cell_size.h+gap_size))
end

local function drawCursorFrame(rect, ui_data, field_data, cursor_x, cursor_y)
	local gap_size = 3
	local cells, real_rect, cell_size = getFieldUIData(rect, ui_data, field_data, gap_size)
	love.graphics.setColor(colorUnpack(ui_data.cursor.color or default_color))
	local l_width = love.graphics.getLineWidth()
	local frame_width = 2
	love.graphics.setLineWidth(frame_width)
	love.graphics.rectangle("line", real_rect.x+real_rect.offset.x+(cursor_x-1)*(cell_size.w+gap_size)-frame_width, real_rect.y+real_rect.offset.y+(cursor_y-1)*(cell_size.h+gap_size)-frame_width, cell_size.w+frame_width*2, cell_size.h+frame_width*2)
	love.graphics.setLineWidth(l_width)
end

local function getDrawDataSwapCells(field_data, x1, y1, x2, y2)
	local ret = {
		static_cells = {}, 
		move_cells = {}
	}
	for y, line in ipairs(field_data) do
		ret.static_cells[y] = {}
		for x, cell in ipairs(line) do
			if (x1==x and y1==y) or (x2==x and y2==y) then
				ret.static_cells[y][x] = 0
			else
				ret.static_cells[y][x] = 1
			end
		end
	end
	table.insert(ret.move_cells, {x=x1, y=y1})
	table.insert(ret.move_cells, {x=x2, y=y2})
	return ret
end

local function getDrawDataHarvestCells(field_data, cells)
	local ret = {
		harvest_state = {},
	}
	for y, line in ipairs(field_data) do
		ret.harvest_state[y] = {}
		for x, cell in ipairs(line) do
			ret.harvest_state[y][x] = 0
		end
	end
	local width = #field_data[1]
	for el,list in pairs(cells) do
		for key, v in pairs(list) do
			local x1,y1 = util.getXYfromKey(key, width)
			ret.harvest_state[y1][x1] = 1
		end
	end
	return ret
end

local function getDrawDataRefillCells(field_prev, field_current)
	local ret = {
		static_cells = {},
		move_data = {},
	}
	for y, line in ipairs(field_current) do
		ret.static_cells[y] = {}
		for x, cell in ipairs(line) do
			ret.static_cells[y][x] = 0
		end
	end

	local width = #field_prev[1]
	local height = #field_prev
	for x = 1,width do
		local y1 = height
		for y = height,1,-1 do
			if field_prev[y][x]~=0 then
				ret.static_cells[y][x] = 1
				y1 = y1 - 1
			else
				break
			end
		end
		if y1>0 then
			local dy = 0
			for y = y1,1,-1 do
				if field_prev[y][x]~=0 then
					table.insert(ret.move_data, {x=x, y1=y, y2=y1, val = field_current[y1][x]})
					dy = dy + 1
					y1 = y1 - 1
				end
			end
			if y1>0 then
				for y=y1, 1, -1 do
					table.insert(ret.move_data, {x=x, y1=y-y1, y2=y, val = field_current[y][x]})
				end
			end
		end
	end
	ret.max_dy = 0
	for _,v in ipairs(ret.move_data) do
		if v.y2-v.y1 > ret.max_dy then
			ret.max_dy = v.y2-v.y1
		end
	end

	return ret
end

local function drawFieldAnimated_RefillCells(rect, ui_data, field_data, current_animation_time, total_animation_time, refill_move_cells)
	local gap_size = 3
	local cells, real_rect, cell_size = getFieldUIData(rect, ui_data, field_data, gap_size)
	love.graphics.setScissor(real_rect.x+real_rect.offset.x, real_rect.y+real_rect.offset.y, real_rect.w, real_rect.h)
	love.graphics.setColor(colorUnpack(ui_data.field_background.color or default_color))
	love.graphics.rectangle("fill", real_rect.x+real_rect.offset.x, real_rect.y+real_rect.offset.y, real_rect.w, real_rect.h)
	local animation_progress = current_animation_time/total_animation_time
	for x = 1,cells.w do 
		for y = 1,cells.h do
			if refill_move_cells.static_cells[y][x]==1 then
				drawCell(x, y, real_rect, field_data, ui_data, cell_size, gap_size)
			end
		end
	end
	local speed = refill_move_cells.max_dy/total_animation_time*cell_size.h
	local dy = speed*current_animation_time
	for _,data in ipairs(refill_move_cells.move_data) do
		local max_local_dy = (data.y2-data.y1)*cell_size.h
		if max_local_dy > dy then
			drawMovingCell(data.x, data.y2, real_rect, field_data, ui_data, cell_size, gap_size, 0, dy-max_local_dy)
		else
			drawCell(data.x, data.y2, real_rect, field_data, ui_data, cell_size, gap_size)
		end
	end
	love.graphics.setScissor()
end

local function drawFieldAnimated_SwapCells(rect, ui_data, field_data, current_animation_time, total_animation_time, swap_move_cells)
	local gap_size = 3
	local cells, real_rect, cell_size = getFieldUIData(rect, ui_data, field_data, gap_size)
	love.graphics.setColor(colorUnpack(ui_data.field_background.color or default_color))
	love.graphics.rectangle("fill", real_rect.x+real_rect.offset.x, real_rect.y+real_rect.offset.y, real_rect.w, real_rect.h)
	for x = 1,cells.w do 
		for y = 1,cells.h do
			if swap_move_cells.static_cells[y][x]==1 then
				drawCell(x, y, real_rect, field_data, ui_data, cell_size, gap_size)
			end
		end
	end
	local animation_progress = current_animation_time/total_animation_time
	drawMovingCell(swap_move_cells.move_cells[1].x, swap_move_cells.move_cells[1].y, real_rect, field_data, ui_data, cell_size, gap_size, (swap_move_cells.move_cells[2].x-swap_move_cells.move_cells[1].x)*animation_progress*(cell_size.w+gap_size), (swap_move_cells.move_cells[2].y-swap_move_cells.move_cells[1].y)*animation_progress*(cell_size.w+gap_size))
	drawMovingCell(swap_move_cells.move_cells[2].x, swap_move_cells.move_cells[2].y, real_rect, field_data, ui_data, cell_size, gap_size, (swap_move_cells.move_cells[1].x-swap_move_cells.move_cells[2].x)*animation_progress*(cell_size.w+gap_size), (swap_move_cells.move_cells[1].y-swap_move_cells.move_cells[2].y)*animation_progress*(cell_size.w+gap_size))
end

local function drawFieldAnimated_HarvestCells(rect, ui_data, field_data, current_animation_time, total_animation_time, harvest_move_cells)
	local gap_size = 3
	local cells, real_rect, cell_size = getFieldUIData(rect, ui_data, field_data, gap_size)
	love.graphics.setColor(colorUnpack(ui_data.field_background.color or default_color))
	love.graphics.rectangle("fill", real_rect.x+real_rect.offset.x, real_rect.y+real_rect.offset.y, real_rect.w, real_rect.h)
	local animation_progress = current_animation_time/total_animation_time
	for x = 1,cells.w do 
		for y = 1,cells.h do
			if harvest_move_cells.harvest_state[y][x]==0 then
				drawCell(x, y, real_rect, field_data, ui_data, cell_size, gap_size)
			else
				drawHarvestingCell(x, y, real_rect, field_data, ui_data, cell_size, gap_size, animation_progress)
			end
		end
	end
end


return {
	init = nil, -- set draw model, maybe later or another implements
	drawField = drawField,
	drawDebugField = drawDebugField,
	drawScore = drawScore,
	drawCursorFrame = drawCursorFrame,
	drawFieldAnimated_SwapCells = drawFieldAnimated_SwapCells,
	drawFieldAnimated_HarvestCells = drawFieldAnimated_HarvestCells,
	drawFieldAnimated_RefillCells = drawFieldAnimated_RefillCells,

	getXYfromMouseCoord = getXY,
	getDrawDataSwapCells = getDrawDataSwapCells,
	getDrawDataRefillCells = getDrawDataRefillCells,
	getDrawDataHarvestCells = getDrawDataHarvestCells,
}