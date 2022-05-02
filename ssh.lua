
function SSHTunnelProcess(tunnel)
local str

str=tunnel.ssh_stream:readln()
if str == nil then return false end
print(str)
return true
end



function FindFreePort()
local server, port, S

	for port=5901,6000,1
	do
		server=net.SERVER("tcp:127.0.0.1:"..port)
		if server ~= nil and server:get_stream() ~= nil 
		then
						S=server:get_stream()
						S:close()
						return port
		end
	end

	return nil
end


function SSHTunnel(tunnel_host, target)
local tunnel={}
local S, local_port, ssh_path

ssh_path=AppFind("ssh")

local_port=FindFreePort()
print("PORT: "..local_port)

tunnel.host=tunnel_host
tunnel.target=target


tunnel.close=function(self)
local pid

pid=self.ssh_stream:getvalue("PeerPID")
process.kill(pid)
self.ssh_stream:close()
end




tunnel.ssh_stream=stream.STREAM("cmd:" .. ssh_path .. " -N -L 127.0.0.1:" .. local_port .. ":" .. target ..  " ".. tunnel_host)
if tunnel.ssh_stream ~= nil
then
		tunnel.url="127.0.0.1::"..local_port
		tunnel.process=SSHTunnelProcess

		tunnel.ssh_stream:timeout(10)
		while true == true
		do
			SSHTunnelProcess(tunnel)
			-- do nothing, SSHTunnelProcess does it all
			S=stream.STREAM("tcp:127.0.0.1:"..local_port)
			if S ~= nil
			then

				S:close()
				print("RETURN TUNNEL")
				return tunnel

			end

		end
end

return nil
end
