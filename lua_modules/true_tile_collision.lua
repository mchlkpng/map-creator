--Functions by NeZvers
local TIME_MULT		= 1											--For slow motion NOT IMPLEMENTED YET
local DT_MULT		= 60										--Delta time multiplier for px/frame values
local TILE_SIZE		= 16										--default size
local TILE_ROUND	= -TILE_SIZE + 1							--in case of bitwise calculations
local VIEW_SCALE	= 4											--hardcoded for prototyping
local JUMP_BUFFER	= 20										--buffer after player loses ground
local SLOPE_SPD1	= vmath.normalize(vmath.vector3(1,1,0))		--Multiplier for walking slopes
local SLOPE_SPD2	= vmath.normalize(vmath.vector3(1,0.5,0))	--Multiplier for walking slopes

--COLISION TILES
local solid1	= 1		--solid block
local solid2	= 2		--slope 45 righ
local solid3	= 3		--slope 45 left
local solid4	= 4		--slope 22.5 right 1/2
local solid5	= 5		--slope 22.5 right 2/2
local solid6	= 6		--slope 22.5 left 1/2
local solid7	= 7		--slope 22.5 left 2/2
local plat		= 8		--Jumpthrough platform

--Will be used as bitmasks to check buttons
local up		= 1
local down		= 2
local left		= 4
local right		= 8
local jump		= 16
local dash		= 32
local start		= 64

function debug_on(peakTrue)
	timer.delay(1, false, function()
		profiler.enable_ui(true)
		profiler.set_ui_mode(profiler.MODE_RECORD)
		if peakTrue then
			profiler.set_ui_mode(profiler.MODE_SHOW_PEAK_FRAME) -- comment this line to not show peak only
		end
	end)
end

function clamp(v, min, max)
	if v < min then v = min 
	elseif v > max then v = max end
	return v
end

function approach(start, ending, ammount)
	local result = nil
	if start > ending then 
		if start - ammount < ending then result = ending
		else result = start - ammount end
	elseif start < ending then
		if start + ammount > ending then result = ending
		else result = start + ammount end
	else result = ending end
	return result
end

function approach_alt(start, ending, ammount)
	local result = nil
	if start < ending then
		result = math.min(start + ammount, ending)
	else result = math.max(start - ammount, ending) end
	return result
end

function sign(v)
	if v > 0 then return 1
	elseif v < 0 then return -1
	else return 0 end
end

function div(a,b)
	return (a - a % b) / b
end

function round(v)
	return v + 0.5 - (v + 0.5) % 1
end

function round_n(val, multiple)
	return round(val/multiple)*multiple;
end

function round_2d(val)
	val.x = round(val.x)
	val.y = round(val.y)
	return val
end

function round_2d_n(val, multiple)
	val.x = round_n(val.x, multiple)
	val.y = round_n(val.y, multiple)
	return val
end

function lerp(from, to, ammount)
	return from+(to - from) *ammount
end

local ceil	= math.ceil																--Save floor function for simplicity
local floor	= math.floor															--save ceil function for simplicity
local mod	= math.mod																--Save mod function
local band	= bit.band																--Save bitwise AND
local bor	= bit.bor																--Save bitwise OR
local sin	= math.sin																--Save sinus function
local cos	= math.cos																--Save cosinus function
local rad	= math.rad																--Save radian function
function dsin(degree)																--Sinus in degrees
	return sin(rad(degree))
end
function dcos(degree)																--Cosinus in degrees
	return cos(rad(degree))
end

--INIT
--function init_physics(inst, id, url, solidMap, solidLayer, tile_size, run_maxspeed, jump_speed, gravity)
function init_physics(inst, url, solidMap, solidLayer, tile_size, run_maxspeed, jump_speed, gravity)
	TILE_SIZE         		= tile_size
	TILE_ROUND		  		= -TILE_SIZE + 1
	inst.URL		  		= url
	inst.POS		  		= go.get_position(url)
	inst.START_POS	  		= go.get_position(url)
	inst.WORLD_POS	  		= vmath.vector3(0,0,0)
	inst.SOLIDMAP     		= solidMap
	inst.SOLIDLAYER   		= solidLayer
	inst.GRAVITY      		= -gravity

	inst.START_JUMP   		= jump_speed
	inst.RELEASE_JUMP 		= ceil(jump_speed / 3)
	inst.RUNACC          	= run_maxspeed / 10			--Running accelerate
	--inst.WALKACC         	= run_maxspeed / 30			--Walk accelerate
	inst.RUNMAX         	= run_maxspeed				--max run speed
	--inst.WALKMAX         	= run_maxspeed  * 25 / 64	--Max walk speed
	inst.DEACCELERATE       = run_maxspeed * 9 / 64		--deaccelerate when no input
	--inst.RUNAIR          	= run_maxspeed * 2 / 64		--Air run acceleration speed
	--inst.WALKAIR         	= run_maxspeed * 1 / 128	--Air walk acceleration speed
	--inst.AIRS         	= run_maxspeed * 2 / 64 	--air stopping speed
	--inst.DRAG         	= run_maxspeed * 9 / 64		--deaccelerate when no input
	inst.MAX_DOWN     		= -jump_speed				--max fall speed
	inst.MAX_UP       		= jump_speed				--max up speed just in case
	inst.WALLSPEED	  		= -ceil(jump_speed/5)		--wallsliding speed
	inst.DASHSPEED			= run_maxspeed *2.5			--dashing speed
	inst.DASHTIME			= 0.2						--time in dashing state (seconds)
	inst.HURTTIME			= 0.3						--time in hurt state (seconds)

	inst.spd          		= vmath.vector3(0,0,0)		--store movement speed
	inst.kickback			= vmath.vector3(0,0,0)		--Speed for hurt state (set in got_hurt())

	inst.buttons	  		= 0							--All pressed buttons stored with bitwise
	inst.xinput		  		= 0							--for platformer
	inst.dir_input	  		= vmath.vector3(0, 0, 0)	--for top-down
	inst.xflip				= 1							--May be useful for flipping sprite or hurt kickback (1 or -1)
	inst.yflip				= 1							--May be useful for flipping sprite or hurt kickback (1 or -1)
	inst.jmp_buf_tmr  		= 0
	inst.last_wall    		= 0							--Tracks latched walls (to the right = 1/ to the left = -1) and disable possiblility to latch to the same side more than once
	inst.last_ledge	  		= 0							--Needed to check if still hanging
	inst.hurttimer    		= 0
	inst.dashtimer			= 0
	inst.doublejump_count	= 0							--double jump counter
	inst.doublejump_max		= 1							--how many double jumps allowed

	--ABILITIES
	inst.can_input			= true
	inst.can_doublejump		= true
	inst.can_wallslide		= true
	inst.can_ledgegrab		= true
	inst.can_dash			= false						--Set this to true each time to allow use dash

	--STATES	
	inst.is_grounded	  	= false
	inst.is_jumping	  		= false
	inst.is_dashing	  		= false						
	inst.is_wallsliding  	= false
	inst.is_on_ledge	  	= false
	inst.is_hurt		  	= false
	inst.is_ledge_climbing  = false						--not included

	--TRIGGERS											--Useful for triggering animations or states
	inst.trig_landed		= false						--True when happens collision with ground
	inst.trig_doublejump	= false 					--True when used doublejump
	inst.trig_ledge   		= false						--True for first frame ledge is grabbed
	inst.trig_wallslide 	= false						--True for first frame wallslide is triggered
	inst.trig_wall	  		= false						--True when wall collision is triggered			(useful for enemy to turn around)
	inst.trig_wall_x  		= false						--Top-down variation
	inst.trig_wall_y  		= false						--Top-down variation
	inst.trig_ceiling		= false
	inst.trig_cliff	  		= false						--True when cliff edge collision is triggered	(useful for enemy to turn around)
	inst.trig_fast_fall		= false						--True if falling is at max speed

	--HITBOX											--Need to be initiated with set_hitbox()
	inst.hitbox_l	  		= 0
	inst.hitbox_r	  		= 0
	inst.hitbox_t	  		= 0
	inst.hitbox_b	  		= 0
	inst.hitbox_hc    		= 0
	inst.hitbox_vc    		= 0
	inst.hitbox_ledge 		= 0							--vertical distance from origin of ledge grab (default set in set_hitbox)
end

function set_hitbox(inst, hitbox_r, hitbox_l, hitbox_t, hitbox_b)
	inst.hitbox_l  = hitbox_l
	inst.hitbox_r  = hitbox_r
	inst.hitbox_t  = hitbox_t
	inst.hitbox_b  = hitbox_b
	inst.hitbox_hc = math.ceil((inst.hitbox_r + inst.hitbox_l)/2)
	inst.hitbox_vc = math.ceil((inst.hitbox_t + inst.hitbox_b)/2)
	inst.hitbox_ledge = inst.hitbox_t +1
end

function set_tiles(tile1, tile2, tile3, tile4, tile5, tile6, tile7, tile8)
	solid1	= tile1		--solid block
	solid2	= tile2		--slope 45 righ
	solid3	= tile3		--slope 45 left
	solid4	= tile4		--slope 22.5 right 1/2
	solid5	= tile5		--slope 22.5 right 2/2
	solid6	= tile6		--slope 22.5 left 1/2
	solid7	= tile7		--slope 22.5 left 2/2
	plat	= tile8		--Jumpthrough platform
end

function button_up(inst)		if	inst.can_input	then	inst.buttons = bor(inst.buttons, up)	end	end
function button_down(inst)		if	inst.can_input	then	inst.buttons = bor(inst.buttons, down)	end	end
function button_left(inst)		if	inst.can_input	then	inst.buttons = bor(inst.buttons, left)	end	end
function button_right(inst)		if	inst.can_input	then	inst.buttons = bor(inst.buttons, right)	end	end
function button_jump(inst)		if	inst.can_input	then	inst.buttons = bor(inst.buttons, jump)	end	end
function button_dash(inst)		if	inst.can_input	then	inst.buttons = bor(inst.buttons, dash)	end	end
function button_start(inst)		if	inst.can_input	then	inst.buttons = bor(inst.buttons, start)	end	end

function get_xinput(inst)
	local hin = 0
	if (bit.band(inst.buttons, right)==right) then										--bitmasking for right button
		hin = hin + 1
	end
	if (bit.band(inst.buttons, left)==left) then										--bitmasking for left button
		hin = hin - 1
	end
	inst.xinput = hin
	if hin~=0 then
		inst.xflip = hin
	end
end

function get_dir_input(inst)
	local hin = 0
	if (bit.band(inst.buttons, right)==right) then										--bitmasking for right button
		hin = hin + 1
	end
	if (bit.band(inst.buttons, left)==left) then										--bitmasking for left button
		hin = hin - 1
	end
	if hin~=0 then
		inst.xflip = hin
	end

	local vin = 0
	if (bit.band(inst.buttons, up)==up) then											--bitmasking for right button
		vin = vin + 1
	end
	if (bit.band(inst.buttons, down)==down) then										--bitmasking for left button
		vin = vin - 1
	end
	if vin~=0 then
		inst.yflip = vin
	end

	inst.dir_input.x = hin
	inst.dir_input.y = vin

	if hin~=0 and vin~=0 then															--Diagonal direction input
		inst.dir_input = vmath.normalize(inst.dir_input)								--To get right value for diagonal movement
	end
end

--Get Tile ID from tilesource
function tile_id(inst, x, y)
	x = ceil(x)
	y = ceil(y)
	return tilemap.get_tile(inst.SOLIDMAP, inst.SOLIDLAYER, math.ceil(x/TILE_SIZE), math.ceil(y/TILE_SIZE))
end

--Get y one pixel above the tile
function tile_height(inst, tile_id, x, y)
	x = ceil(x)
	y = ceil(y)
	if tile_id == solid1 then																							--Block tile
		return ceil(y/TILE_SIZE) * TILE_SIZE + 1
	elseif tile_id == solid2 then																						--45 /
		return floor((y-1)/TILE_SIZE) * TILE_SIZE +1 +((x-1) % TILE_SIZE)
	elseif tile_id == solid3 then																						--45 \
		return floor((y-1)/TILE_SIZE) * TILE_SIZE +TILE_SIZE -((x-1) % TILE_SIZE)
	elseif tile_id == solid4 then																						--22.5 / low
		return floor((y-1)/TILE_SIZE) * TILE_SIZE + floor((x -1 - div(x-1, TILE_SIZE)*TILE_SIZE)/2) +1
	elseif tile_id == solid5 then																						--22.5 / high
		return floor((y-1)/TILE_SIZE) * TILE_SIZE + floor((x-1 - div(x-1, TILE_SIZE)*TILE_SIZE)/2) +floor(TILE_SIZE/2) +1
	elseif tile_id == solid6 then																						--22.5 \ low
		return floor((y-1)/TILE_SIZE) * TILE_SIZE +floor(TILE_SIZE/2) - floor((x -1 - div(x-1, TILE_SIZE)*TILE_SIZE)/2)
	elseif tile_id == solid7 then																						--22.5 \ high
		return floor((y-1)/TILE_SIZE) * TILE_SIZE +TILE_SIZE - floor((x -1 - div(x-1, TILE_SIZE)*TILE_SIZE)/2)
	elseif tile_id == 0  then																							--Empty
		return y
	elseif tile_id == nil  then																							--Out of map
		return y
	end
end

--Set hurt kickback
function got_hurt(inst, xspeed, yspeed)
	if not inst.is_hurt then						--disable possibility to trigger more than once at the time
		inst.is_hurt	= true
		inst.kickback	= vmath.vector3(xspeed, yspeed, 0)
	end
end

--HORIZONTAL MOVEMENT
function h_move_blocks(inst, dt)
	if inst.can_dash and band(inst.buttons, dash)==dash and not inst.is_dashing and not inst.is_hurt then						--Switch on dashing state
		inst.is_dashing = true
		inst.spd.x = inst.xinput * inst.DASHSPEED
	end

	if inst.is_dashing then
		if inst.spd.x~=0 and inst.dashtimer<inst.DASHTIME then
			inst.dashtimer = inst.dashtimer + dt /DT_MULT							--count dash time
		else
			inst.is_dashing	= false
			inst.dashtimer	= 0
			inst.can_dash	= false													--set to true to allow use of dash
		end
	end

	if inst.is_hurt then
		if inst.hurttimer == 0 then
			inst.spd.y = inst.kickback.y
			inst.can_input = false											--set kickback jump
		elseif inst.hurttimer >= inst.HURTTIME then
			inst.is_hurt = false
			inst.can_input = true
			inst.hurttimer = 0
		end
		if inst.is_hurt then
			inst.hurttimer = inst.hurttimer + dt /DT_MULT						--increase time in hurt state
			inst.spd.x = inst.kickback.x											--set kickback horizontal speed
		end
	elseif inst.is_wallsliding then													--Wallslide
		--
	elseif inst.is_on_ledge then
		--
	elseif not inst.is_dashing then
		local hin = inst.xinput														--xinput set in get_xinput()
		local hsp = inst.spd.x /dt
		if hin ~= 0 then															--Move
			hsp = hsp + hin * (inst.RUNACC * dt)
			hsp = clamp(hsp, -inst.RUNMAX, inst.RUNMAX)
		else																		--deaccelerate
			hsp = approach(hsp, 0, inst.DEACCELERATE *dt)							--(value, goal, ammount)
			hsp = clamp(hsp, -inst.RUNMAX, inst.RUNMAX)
		end
		inst.spd.x = hsp *dt
	end
end

function h_move_slopes(inst, dt)
	if band(inst.buttons, dash)==dash and inst.can_dash and not inst.is_dashing then						--Switch on dashing state
		inst.is_dashing = true
		inst.spd.x = inst.xinput * inst.DASHSPEED
	end

	if inst.is_dashing then
		if inst.spd.x~=0 and inst.dashtimer<inst.DASHTIME then
			inst.dashtimer = inst.dashtimer + dt/DT_MULT								--count dash time
		else
			inst.is_dashing	= false
			inst.dashtimer	= 0
			inst.can_dash	= false													--set to true to allow use of dash
		end
	end

	if inst.is_hurt then
		if inst.hurttimer == 0 then
			inst.spd.y = inst.kickback.y
			inst.can_input = false											--set kickback jump
		elseif inst.hurttimer >= inst.HURTTIME then
			inst.is_hurt = false
			inst.can_input = true
			inst.hurttimer = 0
		end
		if inst.is_hurt then
			inst.hurttimer = inst.hurttimer + dt /DT_MULT						--increase time in hurt state
			inst.spd.x = inst.kickback.x											--set kickback horizontal speed
		end
	elseif inst.is_wallsliding then														--Wallslide
		--
	elseif inst.is_on_ledge then
		--
	elseif not inst.is_dashing then
		local move_mult = 1															--Reduce speed if on slopes
		local M = tile_id(inst, inst.POS.x+inst.hitbox_hc, inst.POS.y+inst.hitbox_b)
		if M==solid2 or M==solid3 then
			move_mult = SLOPE_SPD1.x
		elseif M==solid4 or M==solid5 or M==solid6 or M==solid7 then
			move_mult = SLOPE_SPD2.x
		end
		local hin = inst.xinput														--xinput set in get_xinput()
		local hsp = inst.spd.x /dt
		if hin ~= 0 then															--Move
			hsp = hsp + hin * (inst.RUNACC * dt *move_mult)
			hsp = clamp(hsp, -inst.RUNMAX*move_mult, inst.RUNMAX*move_mult)
		else																		--deaccelerate
			hsp = approach(hsp, 0, inst.DEACCELERATE *dt *move_mult)										--(value, goal, ammount)
			hsp = clamp(hsp, -inst.RUNMAX*move_mult, inst.RUNMAX*move_mult)
		end
		inst.spd.x = hsp *dt
	end
end

function h_move_topdown(inst, dt)
	if band(inst.buttons, dash)==dash and inst.can_dash and not inst.is_dashing then						--Switch on dashing state
		inst.is_dashing = true
		inst.spd.x = inst.dir_input.x * inst.DASHSPEED
		inst.spd.y = inst.dir_input.y * inst.DASHSPEED
	end

	if inst.is_dashing then
		if (inst.spd.x~=0 or inst.spd.y~=0) and inst.dashtimer<inst.DASHTIME then
			inst.dashtimer = inst.dashtimer + dt/DT_MULT								--count dash time
		else
			inst.is_dashing	= false
			inst.dashtimer	= 0
			inst.can_dash	= false													--set to true to allow use of dash
		end
	end

	if inst.is_hurt then
		if inst.hurttimer == 0 then
			inst.can_input = false
		elseif inst.hurttimer >= inst.HURTTIME then
			inst.is_hurt = false
			inst.can_input = true
			inst.hurttimer = 0
		end
		if inst.is_hurt then
			inst.hurttimer = inst.hurttimer + dt /DT_MULT						--increase time in hurt state
			inst.spd.x = inst.kickback.x											--set kickback horizontal speed
			inst.spd.y = inst.kickback.y											--set kickback jump
		end
	elseif not inst.is_dashing then
		local hin = inst.dir_input.x												--xinput set in get_xinput()
		local hsp = inst.spd.x /dt
		if hin ~= 0 then															--Move
			hsp = hsp + hin * (inst.RUNACC * dt)
			hsp = clamp(hsp, -inst.RUNMAX, inst.RUNMAX)
		else																		--deaccelerate
			hsp = approach(hsp, 0, inst.DEACCELERATE *dt)							--(value, goal, ammount)
			hsp = clamp(hsp, -inst.RUNMAX, inst.RUNMAX)
		end
		inst.spd.x = hsp *dt
	end
end

--VERTICAL MOVEMENT
function v_move_platformer(inst, dt)
	if inst.trig_doublejump then inst.trig_doublejump = false end		--reset trigger
	local vsp = inst.spd.y /dt
	if inst.is_hurt then												--in hurt state
		if inst.is_grounded then
			vsp = 0
		else
			vsp = vsp + inst.GRAVITY *dt
		end
	elseif inst.is_grounded then										--On ground
		inst.doublejump_count	= 0
		inst.last_wall = 0												--Reset Last wall (for allowing walljump from same wall once in a row)
		inst.jmp_buf_tmr = 0											--Reset jump buffer
		if inst.is_jumping and bit.band(inst.buttons, jump)==0 then		--Release jump button
			inst.is_jumping = false
		end
		if inst.is_wallsliding then										--disable wallsliding
			inst.is_wallsliding = false
		end

		if band(inst.buttons, jump)==jump and not inst.is_jumping and band(inst.buttons, down)~=down then --New jump executed
			vsp = inst.START_JUMP
			inst.is_grounded = false
			inst.is_jumping = true
		end
		if inst.trig_fast_fall then inst.trig_fast_fall = false end		--Not fast falling
	else 																--Not on the ground
		if not inst.is_on_ledge then
			vsp = vsp + inst.GRAVITY *dt								--Apply gravity
		end
		if vsp>0 then													--Going up
			if inst.jmp_buf_tmr~=JUMP_BUFFER then						--Disable jump buffer
				inst.jmp_buf_tmr = JUMP_BUFFER
			end
		else															--Going down
			if can_wallslide(inst, inst.xinput) then					--Check wallsliding
				inst.is_wallsliding = true
			elseif inst.is_wallsliding then
				inst.is_wallsliding = false
			end
			if inst.is_wallsliding then
				if bit.band(inst.buttons, jump)==jump and not inst.is_jumping then --New jump executed
					vsp = inst.START_JUMP
					inst.is_jumping = true
					inst.is_wallsliding = false
					if inst.xinput == -inst.last_wall then						--Presing away from wall
						inst.spd.x = inst.xinput * inst.RUNMAX*dt					--Jump afay from wall with full speed
					end
				end
				if vsp < inst.WALLSPEED then vsp = inst.WALLSPEED end	--Limit wallslide speed
			else
				if vsp < inst.MAX_DOWN then								--Limit fall speed
					vsp = inst.MAX_DOWN
					inst.trig_fast_fall = true								--Fast falling
				else
					if inst.trig_fast_fall then inst.trig_fast_fall = false end	--Not fast falling
				end		
			end
			if inst.jmp_buf_tmr < JUMP_BUFFER then						--Count jump buffer timer
				inst.jmp_buf_tmr = inst.jmp_buf_tmr +1*dt
			end
		end

		if band(inst.buttons, jump)~=jump then							--Released jump button
			if vsp > inst.RELEASE_JUMP then								--Cut down jump speed
				vsp = inst.RELEASE_JUMP
			end
			inst.is_jumping = false
		else															--Holding jump button
			if not inst.is_jumping and inst.jmp_buf_tmr < JUMP_BUFFER and band(inst.buttons, down)~=down then
				vsp = inst.START_JUMP
				inst.is_jumping = true
			elseif inst.can_doublejump and band(inst.buttons,down)~=down and not inst.is_jumping and (inst.doublejump_count < inst.doublejump_max) then			--If released jump and allowed to doublejump
				vsp = inst.START_JUMP
				inst.is_jumping = true
				inst.doublejump_count = inst.doublejump_count +1															--increase doublejump counter
				inst.trig_doublejump = true
			end
		end
	end
	inst.spd.y = vsp*dt										--Save vertical speed
end

function v_move_topdown(inst, dt)
	if not inst.is_hurt and not inst.is_dashing then
		local vin = inst.dir_input.y												--xinput set in get_xinput()
		local vsp = inst.spd.y /dt
		if vin ~= 0 then															--Move
			vsp = vsp + vin * (inst.RUNACC * dt)
			vsp = clamp(vsp, -inst.RUNMAX, inst.RUNMAX)
		else																		--deaccelerate
			vsp = approach(vsp, 0, inst.DEACCELERATE *dt)									--(value, goal, ammount)
			vsp = clamp(vsp, -inst.RUNMAX, inst.RUNMAX)
		end
		inst.spd.y = vsp *dt
	end
end

--COLLISIONS
function ground_check_blocks(inst)
	inst.is_grounded = false
	if inst.spd.y <= 0 then															--Bypass in case going up
		local x = ceil(inst.POS.x)
		local y = ceil(inst.POS.y)
		local bottom = inst.hitbox_b
		local L = tile_id(inst, x+inst.hitbox_l+1,	y+bottom)
		local M = tile_id(inst, x+inst.hitbox_hc,	y+bottom)
		local R = tile_id(inst, x+inst.hitbox_r,	y+bottom)

		if (L~=0 and L~=plat) or (M~=0 and M~=plat) or (R~=0 and R~=plat) then --Not empty and not jumpthrough
			inst.is_grounded = true
		elseif L==plat or M==plat or R==plat then								--Jumpthrough
			L = tile_id(inst, x+inst.hitbox_l+1, y+bottom +1)
			C = tile_id(inst, x+inst.hitbox_hc, y+bottom +1)
			R = tile_id(inst, x+inst.hitbox_r, y+bottom +1)
			if L==0 and C==0 and R==0 then												--Above platform or in free tile
				inst.is_grounded = true
			end
			if band(inst.buttons, down)==down and band(inst.buttons,jump)==jump then
				inst.is_grounded = false
			end
		end
	else
		inst.is_grounded = false
	end
end

function ground_check_slopes(inst)
	inst.is_grounded = false															--Default to false
	if inst.spd.y <= 0 then															--Bypass if going up
		local x = ceil(inst.POS.x)
		local y = ceil(inst.POS.y)

		local M = tile_id(inst, x+inst.hitbox_hc, y+inst.hitbox_b)					--Get tile id
		local L = tile_id(inst, x+inst.hitbox_l+1, y+inst.hitbox_b)
		local R = tile_id(inst, x+inst.hitbox_r, y+inst.hitbox_b)
		if M~=nil and M~=0 and M~=plat then														--Center bottom is inside solid tile
			local h = tile_height(inst, M, x+inst.hitbox_hc, y+inst.hitbox_b)
			if y+inst.hitbox_b < h then												--If feet is on or below tile height
				inst.is_grounded = true
			end
		end
		if inst.is_grounded == false then												--If middle isn't on ground
		if L~=nil and L~=0 and L~=plat then
			local h = tile_height(inst, L, x+inst.hitbox_l+1, y+inst.hitbox_b)
			if y+inst.hitbox_b < h then
				inst.is_grounded = true
			end
		end
		if not inst.is_grounded and R~=nil and R~=0 and R~=plat then
			local h = tile_height(inst, R, x+inst.hitbox_r, y+inst.hitbox_b)
			if y+inst.hitbox_b < h then
				inst.is_grounded = true
			end
		end
	end
	if not inst.is_grounded and (L==plat or M==plat or R==plat) then								--Jumpthrough
		L = tile_id(inst, x+inst.hitbox_l+1, y+bottom +1)
		C = tile_id(inst, x+inst.hitbox_hc, y+bottom +1)
		R = tile_id(inst, x+inst.hitbox_r, y+bottom +1)
		if L==0 and C==0 and R==0 then												--Above platform or in free tile
			inst.is_grounded = true
		end
		if band(inst.buttons, down)==down and band(inst.buttons,jump)==jump then
			inst.is_grounded = false
		end
	end
end
end

function ground_check_moving_platforms(inst)
if not inst.is_grounded then
	local mp = collision_check_play2plat(inst,inst.POS+vmath.vector3(0,-1,0))
	if mp~=nil then
		inst.is_grounded = true
	end
end
end

function ledge_collision(inst, dt)
if inst.can_ledgegrab and inst.spd.y <= 0 and band(inst.buttons, down)~=down then                       --Going down
	if not inst.is_on_ledge then                                                   --NOT ON LEDGE
		if inst.xinput~=0 then                                                  --HAVE DIRECTION
			local x = inst.POS.x
			local y = inst.POS.y
			local vsp = inst.spd.y
			local side = nil
			if inst.xinput > 0 then
				side = inst.hitbox_r+1
			else
				side = inst.hitbox_l
			end
			local ledge = inst.hitbox_ledge
			local tnow = tile_id(inst, x+side, y+ledge)
			if tnow==0 or tnow==nil then                                        --ISN'T AGAINST A BLOCK
			local tnext = tile_id(inst, x+side, y+ledge+vsp)
			local tfeet = tile_id(inst, x+inst.hitbox_hc, y+inst.hitbox_b+1+vsp)	--check if free below feet
			if tnext == solid1 and (tfeet==0 or tfeet==nil) then
				local h = tile_height(inst, tnext, x+side, y+ledge+vsp)
				if h>= y+ledge+vsp then                                     --Was going below ledge
					inst.is_on_ledge = true
					inst.POS.y = h-ledge
				else                                                        --Bellow ledge to catch it
					inst.is_on_ledge = false
				end
			else                                                            --Next tile is not solid block
				inst.is_on_ledge = false
			end
		else                                                                --is presing against a block
			local h = tile_height(inst, tnow, x+side, y+ledge)
			if h== y+ledge then                                             --On the right height for latching to a ledge
				inst.is_on_ledge = true
				inst.POS.y = h-ledge
			else                                                            --Bellow ledge to catch it
				inst.is_on_ledge = false
			end
		end
	else                                                                    --No direction
		inst.is_on_ledge = false
	end
else                                                                        --WAS ON LEDGE
	if band(inst.buttons, jump)==jump and not inst.is_jumping then
		inst.is_on_ledge = false
		inst.spd.y = inst.START_JUMP*dt
		inst.is_jumping = true
	end
end
else                                                                            --Going up
inst.is_on_ledge = false
end

if inst.is_on_ledge then
if inst.last_ledge == 0 then
	inst.last_ledge = inst.xinput
	inst.trig_ledge = true
else
	inst.trig_ledge = false
end
inst.spd.y = 0
--RESET WALLSLIDE VARIABLES
inst.is_wallsliding = false
inst.trig_wallslide = false
inst.last_wall = 0
else
inst.last_ledge = 0
end
end

function cliff_collision(inst)														--Useful for enemies not to run over a cliff
if inst.trig_cliff then																--Reset trigger flag
inst.trig_cliff = false
end
if inst.is_grounded then
local hsp = inst.spd.x
if hsp~=0 then
	local x = inst.POS.x
	local y = inst.POS.y + inst.hitbox_b +1
	y = floor(y/TILE_SIZE) * TILE_SIZE +1
	local side = nil
	if hsp > 0 then
		side = inst.hitbox_r
	else
		side = inst.hitbox_l
	end
	local tile = tile_id(inst, x+side+hsp, y-1)
	if tile==0 or tile==nil then												--Cliff is there
		if hsp > 0 then															--Moving to the right
			x = math.ceil((x+side+hsp)/TILE_SIZE) * TILE_SIZE -TILE_SIZE -side	--Snap to the tiles left side
		else																	-- Moving to the left or idle
			x = math.ceil((x+side+hsp)/TILE_SIZE) * TILE_SIZE -side				--Snap to the tiles right side
		end
		--COLLIDE
		inst.POS.x = x
		inst.spd.x = 0
		inst.trig_cliff = true
	end
end
end
end

function can_wallslide(inst, h_dir)													--Check if can wallslide
if inst.can_wallslide then
if band(inst.buttons, down)~=down and not inst.is_on_ledge then
	if not inst.is_wallsliding then													--Not attached
		if h_dir==0 then															--Not pressing any direction
			if inst.trig_wallslide then												--Remove trigger frag
				inst.trig_wallslide = false
			end
			return false
		else
			if inst.last_wall == inst.xinput then									--Have latched to wall this direction (simple solution to disable same wall)
				if inst.trig_wallslide then											--Remove trigger frag
					inst.trig_wallslide = false
				end
				return false
			else
				local side = nil
				if h_dir>0 then
					side = inst.hitbox_r+1
				elseif h_dir<0 then
					side = inst.hitbox_l
				end
				local x = inst.POS.x
				local T = tile_id(inst, inst.POS.x+side, inst.POS.y+inst.hitbox_t)
				if T==solid1 then													--If tile is solid block
					if h_dir>0 then													--Save this direction for same wall latch disabling
						inst.last_wall = 1
					elseif h_dir<0 then
						inst.last_wall = -1
					end
					inst.trig_wallslide = true										--Trigger flag
					return true
				else
					if inst.trig_wallslide then										--Remove trigger frag
						inst.trig_wallslide = false
					end
					return false
				end
			end
		end
	else																			--Already latched to the wall
		if inst.trig_wallslide then													--Remove trigger frag
			inst.trig_wallslide = false
		end
		local side = nil
		if inst.last_wall>0 then
			side = inst.hitbox_r+1
		elseif inst.last_wall<0 then
			side = inst.hitbox_l
		end
		local x = inst.POS.x
		local T = tile_id(inst, inst.POS.x+side, inst.POS.y+inst.hitbox_t)	--Check tile ID
		if T==solid1 then															--Tile is solid block
			return true
		else																		--Tile is not solid block
			if inst.trig_wallslide then												--Remove trigger frag
				inst.trig_wallslide = false
			end
			return false
		end
	end
else
	if inst.trig_wallslide then														--Remove trigger frag
		inst.trig_wallslide = false
	end
	return false
end
end
end

--horizontal collisions
function h_collide_blocks(inst)
local hsp  = inst.spd.x
if inst.trig_wall then inst.trig_wall = false end
if hsp ~= 0 then																--Decouple code if not needed
local x = inst.POS.x
local y = inst.POS.y
local side = nil
if hsp > 0 then
	side = inst.hitbox_r
else
	side = inst.hitbox_l
end
local T = tile_id(inst, x+side+hsp,		y+inst.hitbox_t)					--check top corner
local M = tile_id(inst, x+side+hsp,		y+inst.hitbox_vc)					--check midle of the side
local B = tile_id(inst, x+side+hsp,		y+inst.hitbox_b+1)					--check bottom corner

if B==solid1 or M==solid1 or T==solid1 then
	if hsp > 0 then															--Moving to the right
		x = math.ceil((x+side+hsp)/TILE_SIZE) * TILE_SIZE -TILE_SIZE -side	--Snap to the tiles left side
	else																	-- Moving to the left or idle
		x = math.ceil((x+side+hsp)/TILE_SIZE) * TILE_SIZE -side				--Snap to the tiles right side
	end
	hsp  = 0 																--reset speed after collision
	inst.trig_wall = true													--Trigger wall collision flag
end

inst.POS.x = x + hsp 														--Update coordinates variable
inst.spd.x = hsp															--Update speed variable
end
end

function h_collide_slope(inst)
local hsp  = inst.spd.x
if inst.trig_wall then inst.trig_wall = false end
if hsp ~= 0 then																--Decouple code if not needed
local x = inst.POS.x
local y = inst.POS.y
local side = nil
if hsp > 0 then
	side = inst.hitbox_r
else
	side = inst.hitbox_l
end
local T = tile_id(inst, x+side+hsp,		y+inst.hitbox_t)					--check top corner
local M = 0																	--check midle of the side
local B = 0																	--check bottom corner
local S = tile_id(inst, x+inst.hitbox_hc,y+inst.hitbox_b)					--check below center
if S==0 or S==nil then														--If not on ground enable checks
	B = tile_id(inst, x+side+hsp,		y+inst.hitbox_b+1)
	M = tile_id(inst, x+side+hsp,		y+inst.hitbox_vc)
end
if B==solid1 or M==solid1 or T==solid1 then
	if hsp > 0 then															--Moving to the right
		x = math.ceil((x+side+hsp)/TILE_SIZE) * TILE_SIZE -TILE_SIZE -side	--Snap to the tiles left side
	else																	-- Moving to the left or idle
		x = math.ceil((x+side+hsp)/TILE_SIZE) * TILE_SIZE -side				--Snap to the tiles right side
	end
	hsp  = 0 																--reset speed after collision
	inst.trig_wall = true													--Trigger wall collision flag
end

inst.POS.x = x + hsp 													--Update coordinates variable
inst.spd.x = hsp															--Update speed variable
end
end

function h_collide_topdown(inst)
local hsp  = inst.spd.x
if inst.trig_wall_x then inst.trig_wall_x = false end
if hsp ~= 0 then																--Decouple code if not needed
local x = inst.POS.x
local y = inst.POS.y
local side = nil
if hsp > 0 then
	side = inst.hitbox_r
else
	side = inst.hitbox_l
end
local T = tile_id(inst, x+side+hsp,		y+inst.hitbox_t)					--check top corner
local M = tile_id(inst, x+side+hsp,		y+inst.hitbox_vc)					--check midle of the side
local B = tile_id(inst, x+side+hsp,		y+inst.hitbox_b+1)					--check bottom corner

if B==solid1 or M==solid1 or T==solid1 then
	if hsp > 0 then															--Moving to the right
		x = math.ceil((x+side+hsp)/TILE_SIZE) * TILE_SIZE -TILE_SIZE -side	--Snap to the tiles left side
	else																	-- Moving to the left or idle
		x = math.ceil((x+side+hsp)/TILE_SIZE) * TILE_SIZE -side				--Snap to the tiles right side
	end
	hsp  = 0 																--reset speed after collision
	inst.trig_wall_x = true													--Trigger wall collision flag
end

inst.POS.x = x + hsp 														--Update coordinates variable
inst.spd.x = hsp															--Update speed variable
end
end

--vertical collisions
function v_collide_blocks(inst)														--Simple block tile collision
if inst.trig_landed then inst.trig_landed = false end
if inst.trig_ceiling then inst.trig_ceiling = false end

local vsp  = inst.spd.y
if vsp ~= 0 then																--Decouple code if not needed
local x = inst.POS.x
local y = inst.POS.y
local side = nil
if vsp > 0 then
	side = inst.hitbox_t
else
	side = inst.hitbox_b
end
local R = tile_id(inst, x+inst.hitbox_r,		y+side+vsp)					--check top corner
local M = tile_id(inst, x+inst.hitbox_hc,		y+side+vsp)					--check midle of the side
local L = tile_id(inst, x+inst.hitbox_l+1,		y+side+vsp)					--check bottom corner

if R==solid1 or M==solid1 or L==solid1 then
	if vsp > 0 then															--Moving to the right
		y = math.ceil((y+side+vsp)/TILE_SIZE) * TILE_SIZE -TILE_SIZE -side	--Snap to the tiles left side
		inst.trig_ceiling = true
	else																	-- Moving to the left or idle
		y = math.ceil((y+side+vsp)/TILE_SIZE) * TILE_SIZE -side				--Snap to the tiles right side
		inst.trig_landed = true
	end
	vsp  = 0			--reset speed after collision
end

inst.POS.y = y + vsp	--Update coordinates variable
inst.spd.y = vsp		--Update speed variable
end
end

function v_collide_slopes(inst)														--Simple block tile collision
if inst.trig_landed then inst.trig_landed = false end
if inst.trig_ceiling then inst.trig_ceiling = false end

local x = inst.POS.x
local y = inst.POS.y
local vsp  = inst.spd.y

if vsp ~= 0 then																	--Decouple code if not moving
if vsp > 0 then																	--Going up
	local side = inst.hitbox_t
	local R = tile_id(inst, x+inst.hitbox_r,		y+side+vsp)					--check right corner
	local M = tile_id(inst, x+inst.hitbox_hc,		y+side+vsp)					--check midle of the side
	local L = tile_id(inst, x+inst.hitbox_l+1,		y+side+vsp)					--check left corner

	if R==solid1 or M==solid1 or L==solid1 then
		y = math.ceil((y+side+vsp)/TILE_SIZE) * TILE_SIZE -TILE_SIZE -side		--Snap to the tiles bottom side
		inst.trig_ceiling = true
		vsp  = 0 																--reset speed after collision
	end
else																			--Going down
	local side = inst.hitbox_b+1
	local C = tile_id(inst, x+inst.hitbox_hc, y+side+vsp)
	if C~=plat then
		if C==0 or C==nil then
			local R = tile_id(inst, x+inst.hitbox_r,		y+side+vsp)				--check top corner
			local M = tile_id(inst, x+inst.hitbox_hc,		y+side+vsp)				--check midle of the side
			local L = tile_id(inst, x+inst.hitbox_l+1,		y+side+vsp)				--check bottom corner

			if R==solid1 or M==solid1 or L==solid1 then
				y = math.ceil((y+side+vsp)/TILE_SIZE) * TILE_SIZE -side	+1			--Snap to the tiles top side
				vsp  = 0															--reset speed after collision
			end
		elseif C==solid1 then
			y = ceil((y+side+vsp)/TILE_SIZE) * TILE_SIZE -side	+1					--Snap to the tiles top side
			vsp  = 0																--reset speed after collision
		elseif C~=solid1 then
			local h = tile_height(inst, C, x+inst.hitbox_hc, y+inst.hitbox_b+1+vsp)
			if (y+inst.hitbox_b+1+vsp)<=h then
				y = h-(inst.hitbox_b+1)
				vsp  = 0
			end
		end
		if vsp == 0 then inst.trig_landed=true end										--Trigger landing flag
	end
end
end

if inst.is_grounded then
local yy = 1
local M = tile_id(inst, x+inst.hitbox_hc, y+inst.hitbox_b+yy)
if M==0 or M==nil then
	yy = 0
	M = tile_id(inst, x+inst.hitbox_hc, y+inst.hitbox_b+yy)
end
if M==0 or M==nil then
	yy = TILE_SIZE
	M = tile_id(inst, x+inst.hitbox_hc, y+inst.hitbox_b+yy)
end
if M~=0 and M~=nil and M~=plat then
	local h = tile_height(inst, M, x+inst.hitbox_hc, y+inst.hitbox_b+yy)
	y = h -(inst.hitbox_b+1)
	vsp = 0
end
end
inst.POS.y = y + vsp --Update position variable
inst.spd.y = vsp	--Update speed variable
end

function v_collide_topdown(inst)
local vsp  = inst.spd.y
if inst.trig_wall_y then inst.trig_wall_y = false end
if vsp ~= 0 then																--Decouple code if not needed
local x = inst.POS.x
local y = inst.POS.y
local side = nil
if vsp > 0 then
	side = inst.hitbox_t
else
	side = inst.hitbox_b
end
local R = tile_id(inst, x+inst.hitbox_r,		y+side+vsp)					--check top corner
local M = tile_id(inst, x+inst.hitbox_hc,		y+side+vsp)					--check midle of the side
local L = tile_id(inst, x+inst.hitbox_l+1,		y+side+vsp)					--check bottom corner

if L==solid1 or M==solid1 or R==solid1 then
	if vsp > 0 then															--Moving to the right
		y = math.ceil((y+side+vsp)/TILE_SIZE) * TILE_SIZE -TILE_SIZE -side	--Snap to the tiles left side
	else																	-- Moving to the left or idle
		y = math.ceil((y+side+vsp)/TILE_SIZE) * TILE_SIZE -side				--Snap to the tiles right side
	end
	vsp  = 0 																--reset speed after collision
	inst.trig_wall_y = true													--Trigger wall collision flag
end

inst.POS.y = y + vsp 														--Update coordinates variable
inst.spd.y = vsp															--Update speed variable
end
end

function jumpthrough_collision(inst)												--Jumpthrough platform
local vsp = inst.spd.y
if vsp<=0 and inst.is_grounded==false then
if not (band(inst.buttons, down)==down and band(inst.buttons, jump)==jump) then
	local x = inst.POS.x
	local y = inst.POS.y
	local bottom = inst.hitbox_b
	local L = tile_id(inst, x+inst.hitbox_l+1, y+bottom +1)
	local C = tile_id(inst, x+inst.hitbox_hc, y+bottom +1)
	local R = tile_id(inst, x+inst.hitbox_r, y+bottom +1)
	if L==0 and C==0 and R==0 then												--Above platform or in free tile
		L = tile_id(inst, x+inst.hitbox_l+1, y+bottom +vsp)
		C = tile_id(inst, x+inst.hitbox_hc, y+bottom +vsp)
		R = tile_id(inst, x+inst.hitbox_r, y+bottom +vsp)
		if L==plat or C==plat or R==plat then
			y = math.ceil((y+bottom+vsp)/TILE_SIZE) * TILE_SIZE -bottom
			inst.trig_landed = true
			inst.is_grounded = true
			inst.POS.y = y
			inst.spd.y = 0
		end
	end
end
end
end

--PHYSICS UPDATES
function physics_update_topdown(inst, dt)
dt = dt*TIME_MULT*DT_MULT															--I like to have speed variables to be px/frame (60fps) so dt*60
get_dir_input(inst)
h_move_topdown(inst, dt)
h_collide_topdown(inst)
v_move_topdown(inst, dt)
v_collide_topdown(inst)
go.set_position(inst.POS, inst.URL)

--Reset buttons
inst.buttons = 0
end

function physics_update_platformer_block(inst, dt)
dt = dt*TIME_MULT*DT_MULT															--I like to have speed variables to be px/frame (60fps) so dt*60
get_xinput(inst)
h_move_blocks(inst, dt)
h_collide_blocks(inst)
ground_check_blocks(inst)
v_move_platformer(inst, dt)
jumpthrough_collision(inst)
ledge_collision(inst, dt)
v_collide_blocks(inst)
go.set_position(inst.POS, inst.URL)

--Reset buttons
inst.buttons = 0
end

function physics_update_platformer_slopes(inst, dt)
dt = dt*TIME_MULT*DT_MULT															--I like to have speed variables to be px/frame (60fps) so dt*60
get_xinput(inst)
h_move_slopes(inst, dt)
h_collide_slope(inst)
ground_check_slopes(inst)
v_move_platformer(inst, dt)
jumpthrough_collision(inst)
ledge_collision(inst, dt)
v_collide_slopes(inst)
go.set_position(inst.POS, inst.URL)

--Reset buttons
inst.buttons = 0
end

--ENEMIES
function physics_update_walker(inst, dt)											--Enemy physics include cliff collision
dt = dt*TIME_MULT*DT_MULT															--I like to have speed variables to be px/frame (60fps) so dt*60
get_xinput(inst)
h_move_slopes(inst, dt)
h_collide_slope(inst)
cliff_collision(inst)
ground_check_slopes(inst)
v_move_platformer(inst, dt)
jumpthrough_collision(inst)
ledge_collision(inst, dt)
v_collide_slopes(inst)
go.set_position(inst.POS, inst.URL)

--Reset buttons
inst.buttons = 0
end