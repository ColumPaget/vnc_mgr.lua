
function SettingsInit()
settings={}

settings.items={}

function settings.set(self, key, value)
self.items[key]=value
end

function settings.get(self, key)
if settings.items[key] ~= nil then return settings.items[key] end
return ""
end

settings.load=function(self)
local S, str, toks

S=stream.STREAM(process.homeDir().."/.config/vnc_mgr/settings.conf", "r")
if S ~= nil
then
	str=S:readln()
 	while str ~= nil
	do
	str=strutil.trim(str)
	toks=strutil.TOKENIZER(str, "=")
	self:set(toks:next(), toks:remaining())
	str=S:readln()
	end
	S:close()
end
end


settings.save=function(self)
local S, key, value

S=stream.STREAM(process.homeDir().."/.config/vnc_mgr/settings.conf", "w")
if S ~= nil
then
for key,value in pairs(self.items)
do
	S:writeln(key.."="..value.."\n")
end
S:close()
end
end

settings:set("version", "1.0")
settings:load()
return settings
end
