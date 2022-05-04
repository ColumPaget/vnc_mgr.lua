

function HostsInit()
local hosts={}

hosts.items={}

hosts.find=function(self, name)
local i, item

for i,item in pairs(self.items)
do
if item.name==name then return item end
end

return nil
end


hosts.delete=function(self, name)
local i, item

for i,item in pairs(self.items)
do
if item.name==name then self.items[i]=nil end
end

end


hosts.parse=function(self, details)
local toks, tok
local item

toks=strutil.TOKENIZER(details, "\\S", "Q")
tok=toks:next()
if strutil.strlen(tok) > 0
then
	item={}
	item.host=""
	item.name=tok
	item.tls=false

	tok=toks:next()
	while tok ~= nil
	do
	if string.sub(tok, 1, 5) == "host=" then item.host=string.sub(tok, 6)
	elseif string.sub(tok, 1, 3) == "pw=" then item.password=string.sub(tok, 4)
	elseif string.sub(tok, 1, 5) == "cert=" then item.certificate=string.sub(tok, 6)
	elseif string.sub(tok, 1, 4) == "key=" then item.keyfile=string.sub(tok, 5)
	elseif string.sub(tok, 1, 7) == "tunnel=" then item.tunnel=string.sub(tok, 8)
	end
	tok=toks:next()
	end
end

return(item)
end


hosts.load=function(self)
local path, S, str

path=process.homeDir().."/.config/vnc_mgr/hosts.conf"
filesys.mkdirPath(path)
S=stream.STREAM(path, "r")
if S ~= nil
then
str=S:readln()
while str ~= nil
do
item=self:parse(str)
if item ~= nil then table.insert(hosts.items, item) end
str=S:readln()
end
S:close()
end


end

hosts.save=function(self)
local i, item
local path, S, str

path=process.homeDir().."/.config/vnc_mgr/hosts.conf"
filesys.mkdirPath(path)
S=stream.STREAM(path, "w")
if S ~= nil
then

for i,item in pairs(self.items)
do
   if item ~= nil
   then
	str="'"..item.name.."' " .. " host=" .. item.host
	if strutil.strlen(item.password) > 0 then str=str.. " pw=" .. item.password end
	if strutil.strlen(item.certificate) > 0 then str=str.. " cert=" .. item.certificate end
	if strutil.strlen(item.tunnel) > 0 then str=str.." tunnel="..item.tunnel end
	str=str.."\n"
	S:writeln(str)
   end
end
S:close()
end

end


hosts:load()
return(hosts)
end
