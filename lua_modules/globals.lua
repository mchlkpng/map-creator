local globals = {}
local hn = "http://localhost"
local con = sys.get_ifaddrs()

function globals.setHost(host)
	hn = host
end

--less gooo
function globals.directory()
	return sys.get_save_file("mpcreator", "directory.dir"):gsub("directory.dir", "")
end

function globals.sysinfo()
	return sys.get_sys_info()
end

function globals.on_mobile()
	if globals.sysinfo().system_name == "Android" or "iPhoneOS" then
		globals.ON_MOBILE = true
	else
		globals.ON_MOBILE = false
	end
	return globals.ON_MOBILE
end



function globals.clearVector(v)
	local hasZ = false
	local hasW = false
	v.x = 0
	v.y = 0
	local worked = pcall(function() local a = v.z end)
	if worked then v.z = 0 end
	worked = pcall(function() local a = v.w end)
	if worked then v.w = 0 end
end

function globals.encrypt(str, sn)
	local laconta = 0
	math.randomseed(sn)
	local fin = ""
	for i = 1, str:len() do
		laconta = laconta + 1
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

		if string.byte(v) < 10 then
			doit = 1
		elseif string.byte(v) > 245 then
			doit = -1
		elseif (cnt + i) % 2 == 0 then
			doit = 1
		else
			doit = -1
		end
		local char = string.char(string.byte(v) + doit * ran)
		fin = fin .. char
	end
	local ran2 = math.floor(math.random()*10)
	fin = string.char(sn) .. fin
	return fin
end

function globals.hash_to_string(h)
	local str = string.gsub(tostring(h), "hash: %[", "")
	str = string.gsub(str, "%]", "")
	return str
end

function globals.decrypt(str)
	local first = str:sub(1,1)
	local stri = str:sub(2, #str)
	local laconta = 0

	math.randomseed(string.byte(first))
	local fin = ""
	for i = 1, string.len(stri) do
		laconta = laconta + 1
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
		if string.byte(v) < 10 then
			doit = -1
			if string.byte(v) - doit*ran < 10 then
				doit = 1
			end
		elseif string.byte(v) > 245 then
			doit = 1
			if string.byte(v) - doit*ran > 245 then
				doit = -1
			end
		elseif (cnt + i) % 2 == 0 then
			doit = 1
		else
			doit = -1
		end
		
		local char = ''
		if string.byte(v) - doit * ran >= 0 then char = string.char(string.byte(v) - doit * ran) end
		fin = fin .. char
	end
	
	return fin
end

function globals.tablelen(T, has_integer_keys)
	local count = 0
	if has_integer_keys then
		for i, v in ipairs(T) do
			count = count + 1
		end
		return count
	else
		for i, v in pairs(T) do
			count = count + 1
		end
		return count
	end
end

function globals.on_html5()
	if globals.sysinfo().system_name == "HTML5" then
		globals.ON_HTML5 = true
	else
		globals.ON_HTML5 = false
	end
	return globals.ON_HTML5
end

function globals.hostname(withPort)
	local hostname = hn
	if withPort then 
		return hostname .. ":" .. 2567
	else 
		return hostname 
	end
end 

globals.collisions = {}
globals.collisionGroups = {}

function globals.collidingWith(self, url, mypos, theirpos)
	local colboxinfo
	local colboxes
	--URL should be the URL of the script that contains the 'collision' property
	
	local tx, ty
	local mycol = self.collision
	local theircol = go.get(url, "collision")
	if not mycol then
		error("This object '" .. msg.url() .. "' doesn't contain the 'collision' property! This property should be a vmath.vector4().")
	end
	if not theircol then
		error(url .. " doesn't contain the 'collision' property! This property should be a vmath.vector4().")
	end

	for i = mycol.x, mycol.y do
		for j = theircol.x, theircol.x do
			print("x ", mypos.x + i, theirpos.x + j)
			if mypos.x + i == theirpos.x + j then
				tx = i
				break
			end
		end
		if tx then break end
	end

	for i = mycol.z, mycol.w do
		for j = theircol.z, theircol.w do
			print("y ", mypos.y + i, theirpos.y + j)
			if mypos.y + i == mypos.y + j then
				ty = i
				break
			end
		end
		if ty then break end
	end

	if tx and ty then
		return true, tx, ty
	else
		return false
	end
end
local ddMods = {}
function globals.getEncrypted(mod, fromHTTP, server, callback)
	if ddMods[mod] then
		print("its already there")
		callback("sus", {status = 200, response = "urmom"}, ddMods[mod])
		return ddMods[mod]
	end

	local serv
	if server:sub(-1) ~= "/" then
		serv = server .. "/"
	else
		serv = server
	end

	if fromHTTP then
		http.request(serv .. "mods/" .. mod .. "/" .. mod .. ".encr", "GET", function(self, id, response)
			if response.status == 200 or response.status == 304 then
				local tb = sys.deserialize(response.response)
				local decTb = {}
				for i, v in pairs(tb) do
					if i:find(".png") or i:find(".jpg") then
						decTb[i] = v
					else
						decTb[i] = globals.decrypt(v)
					end
				end

				ddMods[mod] = decTb
				callback(id, response, decTb)
			else
				callback(id, response, decTb)
				print("Couldn't get encr file of '" .. mod .. "' mod. Error Code: " .. response.status)
			end
		end)
	else
		local file = io.open(globals.directory() .. "/mods/" .. mod .. "/" .. mod .. ".encr", "rb")
		local inf = file:read("*a")
		file:close()
		local tb = sys.deserialize(inf)
		local decTb = {}
		for i, v in pairs(tb) do
			print("asusgus")
			if i:find(".png") or i:find(".jpg") then
				decTb[i] = v
			else
				decTb[i] = globals.decrypt(v)
			end
		end
		ddMods[mod] = decTb
		return decTb
	end
end

function globals.setCollision(self,COLLISION, negX, x, negY, y)
	local negx, negy, xs,ys
	if COLLISION then
		if type(COLLISION) == "table" then
			local tb = COLLISION
			negx = tb[1]; xs = tb[2]; negy = tb[3]; ys = tb[4]
		else
			local tb = COLLISION
			negx = tb.x; xs = tb.y; negy = tb.z; ys = tb.w
		end
	else
		negx = negX; negy = negY; xs = x; ys = y
	end
	if (negx or negy or xs or ys) == nil then
		error("There was a problem making collisions: negx: ".. tostring(negx) ..", negy: " .. tostring(negy) .. ", x: " .. tostring(xs) .. ", y: ".. tostring(ys))
	end

	local colboxes = {}
	local colboxinfo = {}
	local position = go.get_position() 
	local scale = go.get(".", "scale")
	if self.type == "platform" or self.type == "spawn" then
		--
	else
		negx = negx*scale.x; negy = negy*scale.y; xs = xs*scale.x; ys = ys*scale.y
	end
	local numb = 45
	local numb2 = 45
	
	local escale = vmath.vector3(1)
	if math.abs(xs) + math.abs(negx) < numb then
		escale.x = (math.abs(xs) + math.abs(negx))/numb
	else
		escale.x = 1
	end

	if math.abs(ys) + math.abs(negy) < numb then
		escale.y = (math.abs(ys) + math.abs(negy))/numb
	else
		escale.y = 1
	end
	numb = math.floor(numb*escale.x)
	numb2 = math.floor(numb2*escale.y)
	if numb > numb2 then numb = numb2 else numb2 = numb end
	
	for i = 0-negx, xs do
		if i % numb == 0  then
			local xx
			if i - numb/2 < 0-negx then
				xx = i - ((i - numb/2) + negx)
			elseif i + numb/2 > xs then
				xx = i - ((i + numb/2) - xs)
			else
				xx = i
			end

			for j = 0-negy, ys do
				if j % numb2 == 0 then
					local yy
						if j - numb/2 < 0-negy then
							yy = j - ((j - numb/2) + negy)
						elseif j + numb/2 > ys then
							yy = j - ((j + numb/2) - ys)
						else
							yy = j
						end
					colboxinfo[xx .. "," .. yy] = {
						localPos = vmath.vector3(xx, yy, position.z),
						pos = vmath.vector3(position.x + xx, position.y + yy, position.z),
						scale = escale
					}
					colboxes[xx .. "," .. yy] = factory.create("#collisionfactory", vmath.vector3(position.x + xx, position.y + yy , 0), nil, nil, escale)
					msg.post(colboxes[xx .. "," .. yy], "relpos", {relpos = vmath.vector3(xx, yy, position.z), parId = go.get_id()})
					--go.set_parent(".", colboxes[xx .. "," .. yy])
				end
			end
		end
	end
	return colboxes, colboxinfo
end

return globals

--[[function globals.setCollision(url, collision, collisionGroups, collisionMasks)
	globals.collisions[url] = {group = collisionGroups, mask = collisionMasks, collision = collision}

	for i, v in ipairs(collisionGroups) do
		local sus = false
		for j, w in ipairs(globals.collisionGroups) do
			if v == w then
				table.insert(glthen
				table.insert(gl]]