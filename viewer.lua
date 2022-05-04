




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
if str=="Password:" then S:writeln(host.password.."\n") end
return true
end

return false
end


function VNCLaunchPasswordFile(host)
local str, path, S

path=process.homeDir().."/.vncpasswd.tmp"
str=AppFind("vncpasswd")
if strutil.strlen(str) > 0
then
S=stream.STREAM("cmd:".. str.. " -f >"..path,  "rw pty")
process.usleep(10000)
S:writeln(host.password.."\n")
S:close()
end
return path
end


function VNCLaunch(url, viewers, host)
local S, params, str
local viewer

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

if strutil.strlen(viewer.autopass_arg) > 0 then str=str .. " " .. viewer.autopass_arg end
if strutil.strlen(viewer.pwfile_arg) > 0 then str=str .. " " ..viewer.pwfile_arg .. " " .. VNCLaunchPasswordFile(host) end

print(str)
viewer.stream=stream.STREAM("cmd: "..str, "rw pty")
viewer.process=VNCProcess
if strutil.strlen(viewer.autopass_arg) > 0 then viewer.stream:writeln(host.password.."\n") end
end
 
return viewer
end


