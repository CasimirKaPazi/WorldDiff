local minetest = minetest --local copy of global

-- Local copy of worldedits serialization.
-- The worlddiff.serialize funtion saves all nodes in the given area, including air. 
-- Notice that the functions are called worlddiff.* instead of worldedit.* to avoid conflicts.

--	loads the nodes represented by string `value` at position `originpos`, returning the number of nodes deserialized
--	contains code based on [table.save/table.load](http://lua-users.org/wiki/SaveTableToFile) by ChillCode, available under the MIT license (GPL compatible)
sort_pos = function(pos1, pos2)
	pos1 = {x=pos1.x, y=pos1.y, z=pos1.z}
	pos2 = {x=pos2.x, y=pos2.y, z=pos2.z}
	if pos1.x > pos2.x then
		pos2.x, pos1.x = pos1.x, pos2.x
	end
	if pos1.y > pos2.y then
		pos2.y, pos1.y = pos1.y, pos2.y
	end
	if pos1.z > pos2.z then
		pos2.z, pos1.z = pos1.z, pos2.z
	end
	return pos1, pos2
end

worlddiff.serialize = function(pos1, pos2)
	--make area stay loaded
	local manip = minetest.get_voxel_manip()
	manip:read_from_map(pos1, pos2)

	local pos1, pos2 = sort_pos(pos1, pos2)
	local pos = {x=pos1.x, y=0, z=0}
	local count = 0
	local result = {}
	local get_node, get_meta = minetest.get_node, minetest.get_meta
	while pos.x <= pos2.x do
		pos.y = pos1.y
		while pos.y <= pos2.y do
			pos.z = pos1.z
			while pos.z <= pos2.z do
				local node = get_node(pos)
				-- Note that "air" gets safed
				if node.name ~= "ignore" then
					count = count + 1
					local meta = get_meta(pos):to_table()

					--convert metadata itemstacks to itemstrings
					for name, inventory in pairs(meta.inventory) do
						for index, stack in ipairs(inventory) do
							inventory[index] = stack.to_string and stack:to_string() or stack
						end
					end

					result[count] = {
						x = pos.x - pos1.x,
						y = pos.y - pos1.y,
						z = pos.z - pos1.z,
						name = node.name,
						param1 = node.param1,
						param2 = node.param2,
						meta = meta,
					}
				end
				pos.z = pos.z + 1
			end
			pos.y = pos.y + 1
		end
		pos.x = pos.x + 1
	end
	result = minetest.serialize(result) --convert entries to a string
	return result, count
end

worlddiff.deserialize = function(originpos, value, clear)
	--	make area stay loaded
	local SEG = worlddiff.segment
	local pos1 = originpos
	local pos2 = {x=pos1.x+SEG, y=pos1.y+SEG, z=pos1.z+SEG}
	local manip = minetest.get_voxel_manip()
	manip:read_from_map(pos1, pos2)

	local originx, originy, originz = originpos.x, originpos.y, originpos.z
	local count = 0
	local add_node, get_meta = minetest.add_node, minetest.get_meta

	--	wip: this is a filthy hack that works surprisingly well
	value = value:gsub("return%s*{", "", 1):gsub("}%s*$", "", 1)
	local escaped = value:gsub("\\\\", "@@"):gsub("\\\"", "@@"):gsub("(\"[^\"]*\")", function(s) return string.rep("@", #s) end)
	local startpos, startpos1, endpos = 1, 1
	local nodes = {}

	while true do
		startpos, endpos = escaped:find("},%s*{", startpos)
		if not startpos then
			break
		end
		local current = value:sub(startpos1, startpos)
		table.insert(nodes, minetest.deserialize("return " .. current))
		startpos, startpos1 = endpos, endpos
	end
	table.insert(nodes, minetest.deserialize("return " .. value:sub(startpos1)))

	--	load the nodes
	count = #nodes
	for index = 1, count do
		local entry = nodes[index]
		entry.x, entry.y, entry.z = originx + entry.x, originy + entry.y, originz + entry.z
		add_node(entry, entry) --entry acts both as position and as node
	end

	--	load the metadata
	for index = 1, count do
		local entry = nodes[index]
		get_meta(entry):from_table(entry.meta)
	end
return count
end
