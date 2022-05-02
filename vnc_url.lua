
function URLtoVNCParams(input)
local pos, str, val
local vnc_params={}

if strutil.strlen(input) ==0 then return nil end

vnc_params.proto="tcp"
vnc_params.port="5900"
vnc_params.display="0"


if string.sub(input, 1, 5)=="unix:"
then
  vnc_params.proto="unix"
  vnc_params.port=""
  vnc_params.display=""
  input=string.sub(input, 6)
elseif string.sub(input, 1, 4)=="tcp:"
then
  vnc_params.proto="tcp"
  input=string.sub(input, 5)
elseif string.sub(input, 1, 4)=="ssl:"
then
  vnc_params.proto="tls"
  input=string.sub(input, 5)
elseif string.sub(input, 1, 4)=="tls:"
then
  vnc_params.proto="tls"
  input=string.sub(input, 5)
elseif string.sub(input, 1, 4)=="ssh:"
then
  vnc_params.proto="ssh"
  input=string.sub(input, 5)
elseif string.sub(input, 1, 7)=="socks5:"
then
  vnc_params.proto="socks5"
  input=string.sub(input, 8)
end

pos=string.find(input, '@')
if pos ~= nil
then
str=string.sub(input, 1, pos-1)
toks=strutil.TOKENIZER(str, ":")
vnc_params.user=toks:next()
vnc_params.password=toks:remaining()
input=string.sub(input, pos+1)
end


pos=string.find(input, ':')
if pos ~= nil
then 
	vnc_params.host=string.sub(input, 1, pos-1)
	str=string.sub(input, pos+1)

	-- if the string contains '::' then it will be a port, else ':' means it's a display num
	if string.sub(str, 1, 1) ==':' 
	then 
					val=tonumber(string.sub(str, 2)) 
					vnc_params.port=tostring(math.floor(val))
					vnc_params.display=tostring(math.floor(val - 5900))
	else
					val=tonumber(str) 
					if vnc_params.proto=="socks5" or vnc_params.proto=="ssh"
					then
					vnc_params.port=tostring(math.floor(val))
					else
					vnc_params.port=tostring(math.floor(val + 5900))
					vnc_params.display=tostring(math.floor(val))
					end
	end

else
	vnc_params.host=input
end

return vnc_params
end
