local paths = { "loader.lua", "rbx_script/loader.lua" }
local src
if readfile and isfile then
	for _, p in ipairs(paths) do
		if isfile(p) then
			src = readfile(p)
			break
		end
	end
end
if not src then
	src = game:HttpGet("https://raw.githubusercontent.com/hmzqlf/rbx_script/main/loader.lua")
end
loadstring(src)()
