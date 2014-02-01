local timer = 0

--
-- Load WE files near by the player.
--

if not minetest.setting_getbool("wd_no_load") then
minetest.register_globalstep(function(dtime)
	-- Don't check all the time.
	timer = timer + dtime
	if timer < 5 then return end
	timer = 0
	
	for _,player in ipairs(minetest.get_connected_players()) do
		local pos = player:getpos()
		
		worlddiff.load(pos)
		worlddiff.load({x=pos.x-16, y=pos.y, z=pos.z})
		worlddiff.load({x=pos.x, y=pos.y-16, z=pos.z})
		worlddiff.load({x=pos.x, y=pos.y, z=pos.z-16})
		worlddiff.load({x=pos.x+16, y=pos.y, z=pos.z})
		worlddiff.load({x=pos.x, y=pos.y+16, z=pos.z})
		worlddiff.load({x=pos.x, y=pos.y, z=pos.z+16})
	end
end)
end

--
-- Save WE files when something has been changed.
--

if not minetest.setting_getbool("wd_no_save") then
minetest.register_on_dignode(function(pos, oldnode, digger)
	worlddiff.addsave(pos)
end)

minetest.register_on_placenode(function(pos, node, placer)
	worlddiff.addsave(pos)
end)
end
