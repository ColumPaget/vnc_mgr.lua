




function VNCReadLine(S)
local byte, char
local line

byte=S:readbyte()
while byte > 0
do
char=string.char(byte)
if line==nil then line=char
else line=line..char end

if char == ':' then break end
if char == '\n' then break end
byte=S:readbyte()
end

return line
end


function VNCProcess(S, host)
local str

str=VNCReadLine(S)
if str ~= nil
then
print("["..str.."]  ")
if str=="Password:" then 
print("SEND: ["..host.password.."]")
S:writeln(host.password.."\n") end
return true
end

return false
end


function VNCLaunch(url, viewers, host)
local S, params
local viewer

print("URL: ".. url)

if url ~= nil
then
viewer=ViewersFind(viewers, settings:get("viewer"))
viewer.display="0"

viewer.close=function(self)
self.stream:close()
end


params=URLtoVNCParams(url)
print("PARAMS: ["..params.display.."]  "..url)

str=viewer.cmd.." " .. params.host .. ":" 
if viewer.display_or_port == "port" then str=str..params.port
else str=str ..params.display end

if strutil.strlen(viewer.password_arg) > 0 then str=str.." "..viewer.password_arg.." "..config.password end

if host.view_only == true and strutil.strlen(viewer.viewonly_arg) > 0 then str=str.. " " .. viewer.viewonly_arg end
if host.single_viewer == true and strutil.strlen(viewer.noshare_arg) > 0 then str=str.. " " .. viewer.noshare_arg end
if host.fullscreen == true and strutil.strlen(viewer.fullscreen_arg) > 0 then str=str.. " " .. viewer.fullscreen_arg end

if viewer.autopass == true then str=str.." -autopass" end

print(str)
viewer.stream=stream.STREAM("cmd: "..str, "rw pty")
viewer.process=VNCProcess
if viewer.autopass == true then viewer.stream:writeln(host.password.."\n") end
end
 
return viewer
end


