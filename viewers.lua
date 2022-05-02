function ViewerAdd(viewers, path, platform, cmd, toks)
local str
local viewer={}


viewer.autopass=false
viewer.password_arg=""

str=toks:next()
while str ~= nil
do
if str=="port" then viewer.display_or_port="port" 
elseif str=="autopass" then viewer.autopass=true
elseif string.sub(str, 1, 7) == "pw_arg=" then viewer.password_arg=string.sub(str, 8)
elseif string.sub(str, 1, 13) == "viewonly_arg=" then viewer.viewonly_arg=string.sub(str, 14)
elseif string.sub(str, 1, 12) == "noshare_arg=" then viewer.noshare_arg=string.sub(str, 13)
elseif string.sub(str, 1, 15) == "fullscreen_arg=" then viewer.fullscreen_arg=string.sub(str, 16)
end
str=toks:next()
end

viewer.name=filesys.basename(path)
viewer.path=path
viewer.platform=platform
viewer.cmd=cmd 

table.insert(viewers, viewer)

end


function ViewerConsider(viewers, path, toks)
local S, cmd, str

str=filesys.extn(path)

if str==".jar" 
then
	 if AppFind("java") ~= nil then ViewerAdd(viewers, path, "java", "java -jar "..path, toks) end
else
S=stream.STREAM(path, "r")
if S ~= nil
then
	if S:readch() == "M" and S:readch() == "Z"
	then
	 if AppFind("wine") ~= nil then ViewerAdd(viewers, path, "windows", "wine "..path, toks) end
	else 
	 ViewerAdd(viewers, path, "native", path, toks)
	end
	S:close()
end
end

end


function ViewersFind(viewers, name)
local i,viewer

for i,viewer in pairs(viewers)
do
	if name == viewer.name then return viewer end
end

return viewers[1]
end



function ViewersInit()
local viewer_configs={"vncviewer.exe:noshare_arg=/noshared:fullscreen_arg=/fullscreen:viewonly_arg=/viewonly", "ultravnc.exe:pw_arg=/password", "ultravncviewer.exe:pw_arg=/password", "tightvnc:autopass:noshare_arg=-noshared:fullscreen_arg=-fullscreen:viewonly_arg=-viewonly", "tightvncviewer:autopass:noshare_arg=-noshared:fullscreen_arg=-fullscreen:viewonly_arg=-viewonly", "ultravnc", "tightvnc-jviewer.jar:port:pw_arg=-password", "turbovncviewer.exe:display", "tigervnc", "tigervncviewer", "vncviewer","tightvnc:autopass","vncviewer.jar"}
local viewers={}
local str, i, config

	for i,config in ipairs(viewer_configs)
	do
		toks=strutil.TOKENIZER(config, ":")
		str=AppFind(toks:next())
		if strutil.strlen(str) > 0 then ViewerConsider(viewers, str, toks) end
	end

return(viewers)
end

