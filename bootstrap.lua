local LOADER_URL = (getgenv and getgenv().HMZ_LOADER_URL)
	or "https://raw.githubusercontent.com/hmzqlf/rbx_script/main/loader.lua"

local token = getgenv and getgenv().HMZ_GITHUB_TOKEN
local reqFn = (syn and syn.request) or (http and http.request) or (fluxus and fluxus.request) or request

local src
if readfile and isfile and isfile("loader.lua") then
	src = readfile("loader.lua")
elseif token and reqFn then
	local res = reqFn({
		Url = LOADER_URL,
		Method = "GET",
		Headers = {
			Authorization = "token " .. token,
			Accept = "application/vnd.github.raw",
		},
	})
	src = res and (res.Body or res.body)
else
	error("[HMZ Hub] Repo privé: set getgenv().HMZ_GITHUB_TOKEN ou loadstring(readfile('loader.lua'))()")
end

if not src or #src == 0 or src:sub(1, 3) == "404" then
	error("[HMZ Hub] loader.lua introuvable (token invalide ?)")
end

loadstring(src)()
