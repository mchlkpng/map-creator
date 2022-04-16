
function setCollision(self, negX, x, negY, y, COLLISION_TABLE)
	local negx, negy, xs,ys
	if COLLISION_TABLE then
		local tb = COLLISION_TABLE
		negx = tb[1]; xs = tb[2]; negy = tb[3]; ys = tb[4]
	else
		negx = negX; negy = negY; xs = x; ys = y
	end
	self.colboxes = {}
	local position = go.get_position()
	local scale = getProp("scale")
	negx = negx*scale.x; negy = negy*scale.y; xs = xs*scale.x; ys = ys*scale.y
	local numb = 45
	for i = 0-negx, xs do
		local xx
		if i % numb == 0 then
			if i - numb/2 < 0-negx then
				--xx = (position.x + i) - ((position.x + i - numb/2) + (position.x + negx))
				xx = i - ((i - numb/2) + negx)
			elseif i + numb/2 > xs then
				xx = i - ((i + numb/2) - xs)
			else
				xx = i
			end

			for j = 0-negy*scale.y, ys*scale.y do
				local yy
				if j % numb == 0 then

					if j - numb/2 < 0-negy then
						yy = j - ((j - numb/2) + negy)
					elseif j + numb/2 > ys then
						yy = j - ((j + numb/2) - ys)
					else
						yy = j
					end
					--print("amogus: ", position.x + xx, position.y + yy)
					self.colboxes[xx .. "," .. yy] = factory.create("#collisionfactory", vmath.vector3(position.x + xx, position.y + yy, position.z))
					--print("sus: " .. go.get_position(self.colboxes[i .. j]))
				end
			end
		end
	end
end

--[[function encrypt(str, sn)
math.randomseed(sn)
local fin = ""
for i = 1, string.len(str) do
	print(i)
	local ran = math.floor(math.random() * 10)
	local v = string.sub(str, i, i)
	local byte = string.byte(str, i)
	local cnt = 0
	local num = i
	while num ~= 1 do
		cnt = cnt + 1
		if num % 2 == 0 then
			num = num/2
		else
			num = num*3 + 1
		end
	end
	local doit
	if (cnt + i) % 2 == 0 then
		doit = 1
	else
		doit = -1
	end
	local char = string.char(string.byte(v) + doit * ran)
	fin = fin .. char
end
local ran2 = math.floor(math.random()*10)
print("rwaoif0uieojwejoiwjoirijo", ran2)
fin = string.char(sn + ran2) .. fin
return fin
end

function decrypt(str)
local first = str:sub(1,1)
print("oaods", string.byte(first))
local stri = str:sub(2, #str)
print("stri is " .. stri)
for i = 1, stri:len() do
	print(i)
	math.random()
end
local ran2 = math.floor(math.random()*10)
local se = string.byte(first) - ran2
print("ranw2", ran2)
math.randomseed(se)
local fin = ""
for i = 1, string.len(stri) do
	local ran = math.floor(math.random()*10)
	local v = string.sub(stri, i, i)
	local byte = string.byte(stri, i)
	local cnt = 0
	local num = i
	while num ~= 1 do
		cnt = cnt + 1
		if num % 2 == 0 then
			num = num/2
		else
			num = num*3 + 1
		end
	end
	if (cnt + i) % 2 == 0 then
		doit = 1
	else
		doit = -1
	end
	local char = string.char(string.byte(v) - doit * ran)
	fin = fin .. char
end
return fin
end]]
