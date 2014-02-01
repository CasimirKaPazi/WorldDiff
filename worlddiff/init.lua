-- TODO: Support for external paths.

worlddiff = {}
local buffer = {}
local timer = 0

-- Don't change the segment size. Otherwise your output becomes incompatible.
local SEG = 16
local INVERVAL = 200

--
-- Functions
--

-- Add paths that you want to exclude here.
function worlddiff.sanepath(path)
	if path == "/"
	or path == "/etc/"
	then
		return false
	end
	return true
end

function worlddiff.addsave(pos)
	-- Define the segment that includes the given position.
	-- A segment is a cube with the dimensions of SEG*SEG*SEG nodes.
	local pos1 = {x=math.floor(pos.x/SEG), y=math.floor(pos.y/SEG), z=math.floor(pos.z/SEG)}
	pos1 = {x=pos1.x*SEG, y=pos1.y*SEG, z=pos1.z*SEG}
	for _,p in pairs(buffer) do
		if p.x == pos1.x and p.y == pos1.y and p.z == pos1.z then return end
	end
	table.insert(buffer, pos1)
end

minetest.register_globalstep(function(dtime)
	-- Don't check all the time.
	timer = timer + dtime
	if timer < 5 then return end
	timer = 0
	
	for i,pos1 in pairs(buffer) do
		worlddiff.save(pos1)
		table.remove(buffer, i)
	end
end)

function worlddiff.save(pos1, path)
--	p = {x=math.floor(pos.x/SEG), y=math.floor(pos.y/SEG), z=math.floor(pos.z/SEG)}
--	local pos1 = {x=p.x*SEG, y=p.y*SEG, z=p.z*SEG}
	local pos2 = {x=pos1.x+SEG, y=pos1.y+SEG, z=pos1.z+SEG}
	if pos1 == nil or pos2 == nil then
		print("[worlddiff] no region selected")
		return
	end
	-- Name of the files. Format is "segment size_lower position_(time)_(used)"
	-- "time" might be added in the future.
	local param = SEG .."_x".. pos1.x .."y".. pos1.y .."z".. pos1.z ..""
	local result, count = worldedit.serialize(pos1, pos2)
	-- Allow custom path for external mods.
	if not path then
		path = minetest.get_worldpath() .. "/wd_output"
	else
		if not worlddiff.sanepath(path) then
			print("[worlddiff] Path is invalid.")
			return
		end
	end
	local filename = path .. "/" .. param .. ".we"
	if not io.open(path, rb) then
		os.execute("mkdir \"" .. path .. "\"") -- Create directory if it does not already exist
	end
	local file, err = io.open(filename, "wb")
	if err ~= nil then
		print("[worlddiff] could not save file to \"" .. filename .. "\"")
		return
	end
	file:write(result)
	file:flush()
	file:close()
	print("[worlddiff] ".. count .. " nodes saved")
end

function worlddiff.load(pos, path)
	if pos == nil then
		print("[worlddiff] no region selected")
		return
	end
	p = {x=math.floor(pos.x/SEG), y=math.floor(pos.y/SEG), z=math.floor(pos.z/SEG)}
	local pos1 = {x=p.x*SEG, y=p.y*SEG, z=p.z*SEG}
	-- Name of the files. Format is "SEGsize, lower position, (date), (used)"
	local param = "SEGx".. pos1.x .."y".. pos1.y .."z".. pos1.z ..""
	-- Allow custom path for external mods.
	if not path then
		path = minetest.get_worldpath() .. "/wd_input"
	else
		if not worlddiff.sanepath(path) then
			print("[worlddiff] Path is invalid.")
			return
		end
	end
	-- Find the file in the given path.
	local testpaths = {
		path .. "/" .. param,
		path .. "/" .. param .. ".we",
		path .. "/" .. param .. ".wem",
	}
	local file, err
	for index, path in ipairs(testpaths) do
		file, err = io.open(path, "rb")
		if not err then
			break
		end
	end
	if err then
--		print("[worlddiff] could not open file \"" .. param .. "\"")
		return
	end
	-- Clear area before loading.
	worldedit.set(pos1, {x=pos.x+SEG, y=pos.y+SEG, z=pos.z+SEG}, "air")
	local value = file:read("*a")
	file:close()
		if worldedit.valueversion(value) == 0 then -- Unknown version
		print("[worlddiff] invalid file: file is invalid or created with newer version of WorldEdit")
		return
	end
	-- Rename, so the file does not get used again.
	os.rename((path .. "/" .. param .. ".we"), (path .. "/" .. param .. "_used.we"))
	local count = worldedit.deserialize(pos1, value)
	print("[worlddiff] ".. count .. " nodes loaded")
end