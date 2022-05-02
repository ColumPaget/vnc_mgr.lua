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

