pico-8 cartridge // http://www.pico-8.com
version 33
__lua__
-- fox quest
-- by ssm24

-- initialization

-- todo:
-- - figure out actor/spawner
--   relation better

function _init()
	-- disable button repeating
	poke(0x5f5c, 255)
	load_room(1)
end

room_info = {
	[1] = {
		id = 1,
		x = 0,
		y = 0,
		w = 16*4,
		h = 16
	}
}

function load_room(num)
 -- reset state
 actors = {}
 spawners = {}
	room = room_info[num]
	-- find spawners
	local left = room.x
	local right = room.w - room.x
	local top = room.y
	local bottom = room.h - room.y
 for y = top, bottom do
 	for x = left, right do
 		local sprite = mget(x, y)
 		if fget(sprite, 0x7) then
 			local spawner = 
 				create_spawner(x, y, sprite)
 			add(spawners, spawner)
 		end
 	end
 end
 -- spawn initial actors
 for sp in all(spawners) do
 	if sp.x >= left - 2
		and sp.x <= right + 2
		and sp.y >= top - 2
		and sp.y <= bottom + 2
 	then
 		local actor = sp:spawn()
 		add(actors, actor)
 	end
 end
end
-->8
-- rendering

function _draw()
	cls(1)
	camera_x = clamp(
		pl.x - 60,
		room.x * 8,
		room.x * 8 + room.w * 8 - 128
	)
	camera_y = clamp(
		pl.y - 60,
		room.y * 8,
		room.y * 8 + room.h * 8 - 128
	)
	camera(camera_x, camera_y)
	draw_level()
	for actor in all(actors) do
		actor:draw()
	end
	camera()
	-- hud stuff goes here
end

--counter = 1
--timer = 0
function draw_level()
	--[[clrs = {6,8,12,14,15}
	if timer == 60 then
		timer = 0
		counter = (counter % #clrs) + 1
	end
	timer += 1]]
	--rectfill(0, 0, 128, 128, 1)
	map(
		room.x, room.y,
		0, 0,
		room.w, room.h,
		0x01)
end


-->8
-- update loop

function _update60()
	for actor in all(actors) do
		if actor.update != nil then
			actor:update()
		end
	end
end

-- will be fancier later?
function pressed(button)
	return btnp(button)
end
-->8
-- helper functions

function approach(val, target, rate)
	if val > target then
		return max(val - rate, target)
	elseif val < target then
		return min(val + rate, target)
	else
		return target
	end
end

function between(val, _min, _max)
	return val >= _min
		and val <= _max
end

function clamp(val, _min, _max)
	return
		max(min(val, _max), _min)
end

function is_in_solid(x, y)
	local mx = flr(x/8)
	local my = flr(y/8)
	local in_bounds = 
		between(mx, room.x, room.w-1)
		and between(my, room.y, room.h-1)
	-- flag 1 means solid
	return in_bounds
		and fget(mget(mx, my), 1)
end

buttons = {
	[0]="⬅️",
	[1]="➡️",
	[2]="⬆️",
	[3]="⬇️",
	[4]="🅾️",
	[5]="❎",
}

--[[
function spr_outline(n,x,y,w,h,flip_x,flip_y)
	for i = 1,15 do pal(i,0) end
	pal(0,1)
	palt(1,false)
	for i = 0,0.75,0.25 do
		offsetx = cos(i)
		offsety = sin(i)
		spr(n,x+offsetx,y+offsety,w,h,flip_x,flip_y)
	end
	pal()
	palt()
end
--]]
-->8
-- actors and spawners

function create_spawner(x, y, id)
	local spawner = {
		x = x,
		y = y,
		id = id,
		enabled = true,
		actor_alive = false,
		spawn = function(self)
			return create_actor(
				self.x * 8,
				self.y * 8,
				self.id,
				self)
		end
	}
	return spawner
end

actormeta = {
	__concat = function(orig, new)
		for k,v in pairs(new) do
			orig[k] = v
		end
		return orig
	end
}

function create_actor(x, y, id, spawner)
 actor_creators = {
		[1] = create_player,
	}
	if actor_creators[id] != nil then
		return actor_creators[id](x, y)
	end
	local actor = {
		-- movement state
		x = x,
		y = y,
		realx = x,
		realy = y,
		speedx = 0,
		speedy = 0,
		-- hitboxes
		-- solid hitbox
		sol_hitbox = 
			new_hitbox(8, 8, 0, 0),
		-- hitbox to player
		pl_hitbox = 
			new_hitbox(6, 6, 1, 1),
		-- hitbox to shots
		sh_hitbox = 
			new_hitbox(10, 10, -1, -1),
		-- spawn state
		spawner = spawner,
		-- sprite
		sprite = 0,
		flipx = false,
		flipy = false,
		offsetx = 0,
		offsety = 0,
		-- methods
		-- collision detection
		check_collision = function(self)
			local hitbox = self.sol_hitbox
			local left = 
				self.x + hitbox.left
			local right =
				self.x + hitbox.right
			local top = 
				self.y + hitbox.top
			local bottom =
				self.y + hitbox.bottom
			
			return is_in_solid(left, top)
				or is_in_solid(left, bottom)
				or is_in_solid(right, top)
				or is_in_solid(right, bottom)
		end,
		on_ground = function(self)
			if (self.speedy < 0) return false
			local hitbox = self.sol_hitbox
			local left = 
				self.x + hitbox.left
			local right =
				self.x + hitbox.right
			local bottom =
				self.y + hitbox.bottom
			return is_in_solid(left, bottom+1)
				or is_in_solid(right, bottom+1)
		end,
		-- movement
		move_x = function(self, x)
			self.realx += x
			while abs(self.realx - self.x) > 1 do
				-- one pixel at a time
				self.x += sgn(self.realx - self.x)
				if self:check_collision() then
					-- undo last step
					self.x -= sgn(self.realx - self.x)
					self.realx = self.x
					if self.on_col_x != nil then
						self:on_col_x()
					else -- default
						self.speedx = 0
					end
				end
			end
		end,
		move_y = function(self, y)
			self.realy += y
			while abs(self.realy - self.y) > 1 do
				-- one pixel at a time
				self.y += sgn(self.realy - self.y)
				if self:check_collision() then
					-- undo last step
					self.y -= sgn(self.realy - self.y)
					self.realy = self.y
					if self.on_col_y != nil then
						self:on_col_y()
					else -- default
						self.speedy = 0
					end
				end
			end
		end
	}
	setmetatable(actor, actormeta)
	return actor
end

hitbox_meta = {
	__index = function(self, key)
		if key == "left" then
			return self.x
		elseif key == "right" then
			return self.x + self.w - 1
		elseif key == "top" then
			return self.y
		elseif key == "bottom" then
			return self.y + self.h - 1
		end
	end
}

function new_hitbox(w,h,x,y)
	local hitbox = {
		w=w,
		h=h,
		x=x,
		y=y
	}
	setmetatable(
		hitbox, hitbox_meta)
	return hitbox
end

-->8
-- player definition

function create_player(x, y)
	pl = create_actor(x, y)	
	pl = pl .. {
		crouching = false,
		lookingup = false,
		-- jumping state
		has_jump2 = true,
		grace_time = 10,
		grace = 0,
		-- hitboxes
		sol_hitbox = 
			new_hitbox(6, 6, 1, 2),
		pl_hitbox = nil,
		sh_hitbox = nil,
		-- animation state
		sprite = 1,
		runtimer = 0,
		-- constants
		walkspeed = 1.4,
		walkaccel = 0.28,
		airspeed = 1.25,
		airaccel = 0.25,
		jumpspeed = -2.85,
		jump2speed = -2.5,
		gravity = 0.140,
		fallspeed = 2.8,
		run_animrate = 9,
		sprites = {
			stand = 1,
			walk1 = 1,
			walk2 = 2,
			jump = 3,
			fall = 4,
			crouch = 5,
			lookup = 6
		},
		-- update methods
		update = function(self)
			-- horizontal inputs
			local on_ground = 
				self:on_ground()
			local accel = on_ground
				and self.walkaccel
				or self.airaccel
			local maxspeed = on_ground
				and self.walkspeed
				or self.airspeed
			if btn(⬅️) == btn(➡️) then
				self.speedx = 
					approach(self.speedx, 0, accel)
			elseif btn(⬅️) then
				self.speedx = 
					approach(self.speedx, -maxspeed, accel)
				if (self.speedx <= 0) self.flipx = true
			elseif btn(➡️) then
				self.speedx = 
					approach(self.speedx, maxspeed, accel)
				if (self.speedx >= 0) self.flipx = false
			end
			-- vertical inputs
			self.crouching = false
			self.lookingup = false
			if (self.speedx == 0) then
				if btn(⬇️) != btn(⬆️) then
					if (btn(⬇️)) self.crouching = true
					if (btn(⬆️)) self.lookingup = true
				end
			end
			-- vertical movement
			if on_ground then
				self.has_jump2 = true
				self.grace = self.grace_time
			else
				self.grace =
					max(self.grace - 1, 0)
			end
			if pressed(🅾️) then
				if self:on_ground()
						or self.grace > 0 then
					self:jump(1)
				elseif self.has_jump2 then
					self.has_jump2 = false
					self:jump(2)
				end
			end
			
			if self.speedy < 0 and not btn(🅾️) then
				self.speedy += self.gravity * 4
			else
				self.speedy += self.gravity
			end
			self.speedy = min(self.speedy, self.fallspeed)
			
			self:move_x(self.speedx)
			self:move_y(self.speedy)
			
			self:enforce_bounds()
			
			if self.y > room.y*8 + room.h*8 + 4 then
				load_room(room.id)
			end
		end,
		
		jump = function(self, num)
			self.grace = 0
			if num == 1 then
				sfx(0)
				self.speedy = self.jumpspeed
			elseif num == 2 then
				sfx(1)
				self.speedy = self.jump2speed
			end
		end,
		
		on_col_y = function(self)
			if (self.speedy < 0) then 
				sfx(2)
			end
			self.speedy = 0
		end,
		
		enforce_bounds = function(self)
			local left = room.x*8
			local right =
				room.x*8 + room.w*8 - 8
			if self.x < left then
				self.x = left
				self.realx = self.x
				self.speedx =
					max(self.speedx, -0.01)
			elseif self.x > right then
				self.x = right
				self.realx = self.x
				self.speedx =
					min(self.speedx, 0.01)
			end
		end,
		
		-- rendering code
		draw = function(self)
			if not self:on_ground() then
				-- in the air
				self.sprite = self.speedy < 0
					and self.sprites.jump 
					or self.sprites.fall
				self.runtimer = 0
				self.yoffset = 0
			elseif self.speedx == 0 then
				-- standing still
				if self.crouching then
					self.sprite = self.sprites.crouch
				elseif self.lookingup then
					self.sprite = self.sprites.lookup
				else
					self.sprite = self.sprites.stand
				end
				--self.sprite = self.crouching and 3 or 1
				self.runtimer = 0
				self.yoffset = 0
			else
				-- running
				self.runtimer += 1 / self.run_animrate
				if flr(self.runtimer) % 2 == 0 then
					self.sprite = self.sprites.walk1
					self.yoffset = 0
				else
					self.sprite = self.sprites.walk2
					self.yoffset = -1
				end
			end
			
			--pal({[9]=12,[3]=2})
			--spr_outline(self.sprite, self.x, self.y + self.yoffset, 1, 1, self.flip_x)
			spr(self.sprite, self.x, self.y + self.yoffset, 1, 1, self.flipx)
			
			--pal()
		end
	}
	return pl
end
__gfx__
00000000000900900009009000900900000900900000000000900900000000000000000000000000000000000000000000000000000000000000000000000000
00000000000999900009999000093930700999900009009000093930008888000000000000000000000000000000000000000000000000000000000000000000
00700700790939307909393000099995790939300009999000099995088888800088880000000000000000000000000000000000000000000000000000000000
00077000790999957909999509099990090999950009393079099990808088880888888000000000000000000000000000000000000000000000000000000000
00077000009999900099999079999900009999907909999579999900808088888080888800000000000000000000000000000000000000000000000000000000
00700700009999000099990070999900009999007999999000999900888888888080888800000000000000000000000000000000000000000000000000000000
00000000009009000090090000900900009009000099990000900900888888888888888800000000000000000000000000000000000000000000000000000000
00000000007007000700007007007000070000700070070000700700088888800888888000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbb4444444444444444bbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbb4444444444444444bbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bb4444444444444444bb444444bb4444bb000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bb4444444444444444bb444444bb4444bb000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bb4444444444444444bb444444bb4444bb000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bb4444444444444444bb444444bb4444bb000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bb444444bbbb444444bbbbbbbbbb4444bb000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bb444444bbbb444444bbbbbbbbbb4444bb000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bb444444bbbb444444bb4444bbbbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bb444444bbbb444444bb4444bbbbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bb4444444444444444bb4444bb444444bb000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bb4444444444444444bb4444bb444444bb000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bb4444444444444444bb4444bb444444bb000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bb4444444444444444bb4444bb444444bb000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bb4444444444444444bbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bb4444444444444444bbbbbbbbbbbbbbbb000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bbbbbbbbbbbbbbbbbbbb4444bb00000000000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bbbbbbbbbbbbbbbbbbbb4444bb00000000000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bbbb4444bb44444444bb4444bb00000000000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bbbb4444bb44444444bb4444bb00000000000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bbbb4444bb44444444bb4444bb00000000000000000000000000000000000000000000000000000000000000000000000000000000
bb44444444444444444444bbbb4444bb44444444bb4444bb00000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb4444bb00000000000000000000000000000000000000000000000000000000000000000000000000000000
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb4444bb00000000000000000000000000000000000000000000000000000000000000000000000000000000
00400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00488880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00488800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00488000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00480000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0180010101010101010101010101010103030303030303010101010101010101030303030303030101010101010101010303030303030101010101010101010100010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000153434342600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000033000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000003300000000003300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000152600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000101100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000003300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010242100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000001526000000000000000000000000000000000000000000000000000000000000000000000000000000000000001024212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000033000000000000000000000000000000000000000000000000000000000000000000000000000000000010120000000000000000000000102421212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001024220000000000000000000010242121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000102421220000000000000000001024212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000101111120000000000000000000000000000000000000000000000000010242121220000000000000000102421212121212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000001011242121231200000000000000000000000000000000000000000000001024212121220000000000000000303131313114212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000010000000000000000102421212121212311120000000000000000000000000000000000000000102421212121231200000000000000000000000020212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1111111111111111111111242121212121212121231111111111111112000000000000001011111111242121212121212311111111111111111111111124212100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0001000015050190501a0501b0501d0501e0401f03021030220302303025030270202a0202b0202b0102c0102c0102d0102d0102e0102e0102e0002e0002e0002f0002e0002e0002e0002e0002e0002e0002e000
000100001e05020050210502205023050230402303024030250302603028030290202a0202b0202b0102c0102c0102d0102d0102e0102e0102e0002e0002e0002f0002e0002e0002e0002e0002e0002e0002e000
000100001a740147401274011740107400f7400b7400a730097200972008720067100571004710017000070000700007000070000700000000000000000000000000000000000000000000000000000000000000
