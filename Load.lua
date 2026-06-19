getgenv().HmzHub_Executed = nil
local url = "https://raw.githubusercontent.com/hmzqlf/rbx_script/dacf8105118218d92afe45590049dbd0f4ee33c7/HmzHub.lua"
local src = game:HttpGet(url)
if not src or #src < 10000 then
	warn("[HMZ Hub] Download failed (" .. tostring(#src) .. " bytes). Update Load.lua")
	return
end
if src:byte(1) == 239 and src:byte(2) == 187 and src:byte(3) == 191 then
	src = src:sub(4)
end
local fn, err = loadstring(src)
if not fn then
	warn("[HMZ Hub] " .. tostring(err))
	return
end
fn()