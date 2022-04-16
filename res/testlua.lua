function initialize()
	print("hello")
end



function loadResources()
	local dir = sys.get_save_file("mpcreator", "directory.dir")
	print(dir)
	local file = io.open(dir, "w")
	file:flush()
	file:close()
	

	local baka = sys.get_save_file("mpcreator", "arrow.png")
	print(baka)
	local f = io.open(baka, "rb")
	local bytes = f:read("*all")
	f:close()

	local data = sys.load_resource("/res/arrow.png")

	print(bytes)
	local image_resource = imageloader.load{
		data = bytes,
		no_vertical_flip = true
	}
	local sd = image.load(bytes, true)
	pprint(image_resource)
	resource.set_texture(go.get('#sprite', 'texture0'), image_resource.header, image_resource.buffer)
end