-- TODO: Support for external paths.

worlddiff = {}
worlddiff.buffer = {}
local timer = 0
local worldpath = minetest.get_worldpath()

-- Don't change the segment size. Otherwise your output becomes incompatible.
local SEG = 16
local INTERVAL = 5
if type(minetest.setting_get("wd_interval")) == "number" then
	INTERVAL = minetest.setting_get("wd_interval")
end

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
	for _,p in pairs(worlddiff.buffer) do
		if p.x == pos1.x and p.y == pos1.y and p.z == pos1.z then return end
	end
	table.insert(worlddiff.buffer, pos1)
end

minetest.register_globalstep(function(dtime)
	-- Don't check all the time.
	timer = timer + dtime
	if timer < INTERVAL then return end
	timer = 0
	
	for i,pos1 in pairs(worlddiff.buffer) do
		worlddiff.save(pos1)
		table.remove(worlddiff.buffer, i)
	end
end)

function worlddiff.save(pos1, path)
	if pos1 == nil then
		print("[worlddiff] no region selected")
		return
	end
	-- pos1 is the bottom of the segment, pos2 on the upper opposite side.
	local pos2 = {x=pos1.x+SEG, y=pos1.y+SEG, z=pos1.z+SEG}
	-- Name of the files. Format is "segment size_lower position_(time)_(used)"
	-- "time" might be added in the future.
	local param = SEG .."_x".. pos1.x .."y".. pos1.y .."z".. pos1.z ..""
	local result, count = worldedit.serialize(pos1, pos2)
	-- Allow custom path for external mods.
	if not path then
		if not io.open((worldpath .. "/wd"), rb) then
			os.execute("mkdir \"" .. worldpath .. "/wd\"")
		end
		path = worldpath .. "/wd/output"
	else
		if not worlddiff.sanepath(path) then
			print("[worlddiff] Path is invalid.")
			return
		end
	end
	-- Create directory if it does not already exist
	if not io.open(path, rb) then
		os.execute("mkdir \"" .. path .. "\"")
	end
	local filename = path .. "/" .. param .. ".we"
	local filename_create = path .. "/" .. param .. "_create.we"
	local file, err = io.open(filename_create, "wb")
	if err ~= nil then
		print("[worlddiff] could not save file to \"" .. filename .. "\"")
		return
	end
	file:write(result)
	file:flush()
	file:close()
	-- Using different names here to prevent simultaneous read and write.
	os.rename(filename_create, filename)
	print("[worlddiff] ".. count .. " nodes saved")
end

function worlddiff.load(pos, path)
	if pos == nil then
		print("[worlddiff] no region selected")
		return
	end
	p = {x=math.floor(pos.x/SEG), y=math.floor(pos.y/SEG), z=math.floor(pos.z/SEG)}
	local pos1 = {x=p.x*SEG, y=p.y*SEG, z=p.z*SEG}
	-- Name of the files. Format is "(used), SEGsize, lower position"
	local param = SEG .."_x".. pos1.x .."y".. pos1.y .."z".. pos1.z ..""
	-- Allow custom path for external mods.
	if not path then
		path = worldpath .. "/wd/input"
	else
		if not worlddiff.sanepath(path) then
			print("[worlddiff] Path is invalid.")
			return
		end
	end
	local file, err = io.open((path .. "/" .. param .. ".we"), "rb")
	-- Check if there is a file for the given segment.
	if err then
		return
	end
	-- Rename, so the file does not get used again.
	os.rename((path .. "/" .. param .. ".we"), (path .. "/used_" .. param .. ".we"))
	-- Clear area before loading.
	worldedit.set(pos1, {x=pos.x+SEG, y=pos.y+SEG, z=pos.z+SEG}, "air")
	local value = file:read("*a")
	file:close()
		if worldedit.valueversion(value) == 0 then -- Unknown version
		print("[worlddiff] invalid file: file is invalid or created with newer version of WorldEdit")
		return
	end
	local count = worldedit.deserialize(pos1, value)
	print("[worlddiff] ".. count .. " nodes loaded")
end

print("[worlddiff] loaded")
