


function AskConnection()
local target, config, act

act,config=dialogs:top_level() 
if config==nil then return config end

if config ~= nil
then
	target=config.host
	connector=SetupConnector(config) 
end


return target,config,connector
end



settings=SettingsInit()
hosts=HostsInit()
viewers=ViewersInit()
dialogs=DialogsInit()

if strutil.strlen(settings:get("viewer")) == 0 then settings:set("viewer", viewers[1].name) end

url,config,connector=AskConnection()
if config ~= nil
then

poll=stream.POLL_IO()

if connector ~= nil then url=connector.local_url end
print("Launch: "..url)
viewer=VNCLaunch(url, viewers, config) 
poll:add(viewer.stream)

if connector ~= nil then connector:accept(poll) end

while true
do
S=poll:select(1000)

if connector ~= nil 
then
	if S==connector.client then connector:from_client() end
	if S==connector.dest then connector:to_client() end
end

if S==viewer.stream
then
	if viewer.process(S, config) == false then break end
end

end

viewer:close()
if connector ~= nil then connector:close() end
end

