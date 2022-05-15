


function SSHTunnelProcess(tunnel)
local str

str=tunnel.client:readln()
if str == nil then return false end
print(str)
return true
end


function SSHTunnelClose(self)
local pid

pid=self.client:getvalue("PeerPID")
print("SSH CLOSE: "..pid)
process.kill(0 - pid)
self.client:close()
end



function SSHTunnelInit(self)
local S, local_port, ssh_path, str
local tunnel_params, target_params

local_port=tostring(math.floor(self.server:port()))
self.server:get_stream():close()
self.server=nil

ssh_path=AppFind("ssh")

tunnel_params=URLtoVNCParams(self.tunnel)
target_params=URLtoVNCParams(self.target)

str=ssh_path .. " -N -L 127.0.0.1:" .. local_port .. ":" .. target_params.host .. ":" .. target_params.port ..  " ".. tunnel_params.host
print(str)
self.client=stream.STREAM("cmd:" .. str, "rw setsid")
if self.client ~= nil
then
		self.local_url="127.0.0.1::"..local_port

		self.client:timeout(10)
		while true == true
		do
			SSHTunnelProcess(self)
			-- do nothing, SSHTunnelProcess does it all
			S=stream.STREAM("tcp:127.0.0.1:"..local_port)
			if S ~= nil
			then

				S:close()
				return true
			end

		end
end

return false 
end



--create and return a 'connector' object
function SetupConnector(config) 
local connector={}
local params, global_proxy


global_proxy=settings:get("proxy")
if strutil.strlen(global_proxy) > 0 then net.setProxy(global_proxy) end

-- we only use a connector for ssh/socks5 tunnels or unix and tls connections, or if we have a global proxy
if strutil.strlen(global_proxy) == 0 
then
if strutil.strlen(config.tunnel) == 0 and string.sub(config.host, 1, 4) ~= "tls:" and string.sub(config.host, 1, 5) ~= "unix:" then return nil end
end

-- All Below are functions included in the connector that SetupConnector returns
connector.noop=function(self)
end



-- stuff that needs to be handled after connection established 
connector.connect_postprocess=function(self, params)

if params.proto == "tls"
then
	if self.dest:getvalue("SSL:CertificateVerify") ~= "OK"
	then
		if dialogs:certificate_warning(self.dest) ~= true
		then
			self.dest:close()
			return false
		end
	end
end

return true
end


connector.connect=function(self)
local params, str
local connect_config="rw "

params=URLtoVNCParams(self.target)
str=params.proto .. ":" .. params.host 
if strutil.strlen(params.port) > 0 then str=str .. ":" .. params.port end


-- protocols handled before connection established
if params.proto == "tls" and strutil.strlen(self.certificate) > 0 and strutil.strlen(self.keyfile) > 0

then
 connect_config=connect_config.."SSL:CertFile="..self.certificate.." "
 connect_config=connect_config.."SSL:KeyFile="..self.keyfile.." "
end

if strutil.strlen(self.tunnel) > 0 and string.sub(self.tunnel, 1, 7) == "socks5:" then str=self.tunnel.."|"..str end

print("CON: "..str.." ["..connect_config.."]")
self.dest=stream.STREAM(str, connect_config)

if self.dest ~= nil and self.client ~= nil
then
	if connector:connect_postprocess(params) == false then return nil end
	poll:add(self.client)
	poll:add(self.dest)
end

return self.dest
end



connector.handle_connect_errors=function(self)
local E, str, params, user, password, save_details
local try_again=false

	--check if connect failure was due to proxy authentication
	E=libuseful_errors.ERRORS()
	str=E:next()
	if str ~= nil
  then 
					if string.sub(str, 1, 33) == "authentication to socks proxy at " 
					then
					user,password,save_details=dialogs:authenticate("socks proxy")
					if user == nil then return false end

					try_again=true 
					params=URLtoVNCParams(self.tunnel)
					self.tunnel=params.proto..":"..user..":"..password.."@"..params.host..":"..params.port
					if self:connect() ~= nil
					then
						if save_details == true 
						then 
							host=hosts:find(self.connection_name)
							if host ~= nil
							then
								host.tunnel=self.tunnel 
								hosts:save()
							end
						end
					end
					else
					dialogs:notice(str)  
					end
	else
					dialogs:notice("ERROR: Connection failed")
	end

	return try_again
end




connector.accept=function(self)

self.client=self.server:accept()
if self.client ~= nil 
then 
	if self:connect() == nil
	then 
		while	connector:handle_connect_errors() == true do end --do nothing, everyting is handled in 'handle_connect_errors'
	end
	if self.dest == nil then self.client:close() end
end

end


connector.close=function(self)
if self.client ~= nil then self.client:close() end
if self.dest ~= nil then self.dest:close() end
end


connector.from_client=function(self)
local bytes, result

if self.client ~= nil
then
bytes=rawdata.RAWDATA("", 49600)
result=bytes:read(self.client, 49600) 

if result < 1 then return false end
bytes:write(self.dest)
self.dest:flush()
end

return true
end

connector.to_client=function(self)
local bytes, result

if self.dest ~= nil
then
bytes=rawdata.RAWDATA("", 49600)
result=bytes:read(self.dest, 49600)

if result < 1 then return false end

bytes:write(self.client)
self.client:flush()
end

return true
end


connector.bind_server=function(self)
local str, serv, i

for i=1,100,1
do
	serv=net.SERVER("tcp:127.0.0.1:" .. string.format("%d", 5900 + i))
	if serv:port() > -1
	then 
	self.server=serv
	self.local_url="127.0.0.1::" ..  string.format("%d", 5900 + i)
	return serv:port()
	end
end

return nil
end


connector.ssh_connector=function(self)
self.connect=self.noop
self.accept=self.noop
self.close=SSHTunnelClose
self.from_client=SSHTunnelProcess
self.toclient=self.noop
SSHTunnelInit(self)
end


connector.tunnel=config.tunnel
connector.target=config.host
connector.connection_name=config.name
connector.certificate=config.certificate
connector.keyfile=config.keyfile

connector:bind_server()

params=URLtoVNCParams(config.tunnel)
if params ~= nil and params.proto=="ssh" then connector:ssh_connector() end

return connector
end

