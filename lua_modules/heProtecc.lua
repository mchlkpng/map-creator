local t = {
	"string.rep", "setmetatable", "getmetatable", "collectgarbage", "dofile", "_G", ";load(", "\nload(", "loadstring", "rawget", "rawset", "rawequal", "module", "require", "string.dump",
	"math.randomseed", --[["print",]] ":rep", ":dump", "os.execute", "os.exit", "os.getenv", "os.remove", "os.rename", "os.setlocale", "os.tmpname", "= os", " = io", "=os", "=io", "=load", "= load"
}
local allowedOs = {

	"os.clock()", "os.difftime", "os.time"
}

-- * string.rep: can be used to allocate millions of bytes in 1 operation
-- * {set|get}metatable: can be used to modify the metatable of global objects (strings, integers)
-- * collectgarbage: can affect performance of other systems
-- * dofile: can access the server filesystem
-- * _G: It has access to everything. It can be mocked to other things though.
-- * load{file|string}: All unsafe because they can grant acces to global env
-- * raw{get|set|equal}: Potentially unsafe
-- * module|require|module: Can modify the host settings
-- * string.dump: Can display confidential server info (implementation of functions)
-- * math.randomseed: Can affect the host sytem
-- * io.*, os.*: Most stuff there is unsafe, see below for exceptions


local checkit = {}

function checkit.check(script)
	if type(script) ~= "string" then
		error("script must be string")
		return false
	end
	if script:byte(1) == 27 then
		error("no bitcode allowed")
		return false
	end


	if string.find(script, "io%p%l") then
		print("oof")
		local words = script:sub(1, string.find(script, "io%p%l"))
		local line = select(2, words:gsub("\n", "\n"))
		line = line + 1
		return false, "io.", line
	end
	
	for i, v in ipairs(t) do
		if script:find(v) then
			local words = script:sub(1, script:find(v))
			local line = select(2, words:gsub("\n", "\n"))
			line = line + 1
			return false, v, line
		end
	end
	return true
end

return checkit

	