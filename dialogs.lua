function DialogsInit()
local dialog={}

dialog.driver=NewDialog("qarma")

dialog.notice=function(self, msg)
self.driver.info(msg)
end


dialog.authenticate=function(self, title)
local form, choices

form=self.driver:form(title)
form:addentry("Username")
form:addentry("Password")
form:addboolean("Save Details")

choices=form:run()

if choices == nil then return nil end
return choices.Username, choices.Password, choices["Save Details"]
end


dialog.ask_tunnel=function(self, prefix, title)
local str

str=self.driver.entry(title)
if strutil.strlen(str) > 0 then str=prefix..":"..str end

return str
end


dialog.ask_certificate=function(self)
local cert, key, form

while true
do
	form=self.driver.form("Enter path to an authentication certificate and key , or leave blank for none", "SSL/TLS/X509 certificate")
	form:addentry("CertFile")
	form:addentry("KeyFile")
	cert,key=form:run()

	if strutil.strlen(cert) > 0 and filesys.exists(cert) == false then self.driver.info("Path: " .. cert .. " no such file") 
	elseif strutil.strlen(key) > 0 and filesys.exists(key) == false then self.driver.info("Path: " .. key .. " no such file") 
	else break
	end
end

return cert, key
end


dialog.certificate_warning=function(self, stream)
local str

if strutil.strlen(stream:getvalue("SSL:CertificateCommonName")) > 0
then
str="Certificate Name:    "..stream:getvalue("SSL:CertificateCommonName") .."|"
str=str.."Certificate Issuer:    "..stream:getvalue("SSL:CertificateIssuer") .."|"
str=str.."Certificate Start:    "..stream:getvalue("SSL:CertificateNotBefore") .."|"
str=str.."Certificate End:      "..stream:getvalue("SSL:CertificateNotAfter") .."|"
str=str.."Certificate Fingerprint: "..stream:getvalue("SSL:CertificateFingerprint")
else
str="ERROR: No Certificate provided|Peer may not be using TLS/SSL"
end

str=self.driver.menu("Error: "..  stream:getvalue("SSL:CertificateVerify"), str, "Warning: Issue with Server Certificate") 

if str ~= nil then return true end
return false
end


dialog.settings_viewer=function(self, form)
local str, i, viewer

str=settings:get("viewer")
for i,viewer in ipairs(viewers)
do
	if strutil.strlen(str)==0 then str=viewer.name 
	else str=str .. "|" .. viewer.name
	end
end
form:addchoice("Viewer", str)
end


dialog.settings_proxy=function(self, form)
form:addentry("Global Proxy", settings:get("proxy"))
end



dialog.settings=function(self)
local form, choices, str

form=self.driver:form("Settings")
self:settings_viewer(form)
self:settings_proxy(form)

choices=form:run()

if choices ~= nil
then
if strutil.strlen(choices["Viewer"]) > 0 then settings:set("viewer", choices["Viewer"]) end
if strutil.strlen(choices["Global Proxy"]) > 0 then settings:set("proxy", choices["Global Proxy"]) end
settings:save()
end

end


dialog.config_host_process=function(self, config, choices)
local params, str, key
local host={}

params=URLtoVNCParams(choices.Host)
host.name=choices.Name
host.host=choices.Host
if strutil.strlen(params.port) > 0  and params.port ~= "5900" then host.host=host.host .. "::" ..params.port end
host.password=choices.Password
host.tunnel_type=choices.Protocol

if host.tunnel_type == "SSH" then host.tunnel=dialog:ask_tunnel("ssh", "SSH Tunnel Host/URL") 
elseif host.tunnel_type == "SOCKS5" then host.tunnel=dialog:ask_tunnel("socks5","SOCKS5 Proxy Host/URL") 
elseif host.tunnel_type == "unix" then host.tunnel="unix:"..choices.Host
elseif host.tunnel_type == "TLS" 
then 
	host.host="tls:"..choices.Host
	str,key=dialog:ask_certificate()
	if str==nil then return nil end
	host.certificate=str
	host.keyfile=key
elseif host.tunnel_type == "SOCKS5+TLS"
then
	host.host="tls:"..choices.Host
	host.tunnel=dialog:ask_tunnel("socks5","SOCKS5 Proxy Host/URL") 
	str=dialog:ask_certificate() 
	if str==nil then return nil end
	host.tunnel=str
end

return host
end



dialog.config_host=function(self, config)
local form, choices, host

while host == nil
do

if config ~= nil then form=self.driver:form("Host: "..config.name)
else form=self.driver:form("Setup New Host")
end

form:addentry("Name")
form:addentry("Host")
form:addentry("Password")
form:addchoice("Protocol", "TCP|SSH|TLS|SOCKS5|SOCKS5+TLS|unix")

choices=form:run()
if choices == nil then return nil end
host=dialog.config_host_process(self, config, choices)
end

table.insert(hosts.items, host)
hosts:save()

return host
end


dialog.launch_options_screen=function(self, host)
local choices={}
local form

form=self.driver:form("Host Options: "..host.name)

form:addboolean("View Only")
form:addboolean("Single Viewer")
form:addboolean("Full Screen")

choices=form:run()

if choices["View Only"]==true then host.view_only=true end
if choices["Single Viewer"]==true then host.single_viewer=true end
if choices["Full Screen"]==true then host.fullscreen=true end

end


dialog.host_screen=function(self, host)
local str
local act="back"

str=self.driver.menu("Host:"..host.name, "Launch|Launch with Options|Delete Host","vnc_mgr.lua: version "..settings:get("version"))
str=strutil.trim(str)
if str=="Delete Host"
then 
	hosts:delete(host.name) 
	hosts:save()
	act="back"
elseif str=="Launch with Options"
then
	self:launch_options_screen(host)
	act="launch"
elseif str=="Launch"
then
	act="launch"
end

return act
end


dialog.select_host=function(self)
local str, i, item, toks, tok
local host, hostname

str="Settings|New Host"
for i,item in ipairs(hosts.items)
do
str=str.. "|" .. item.name .. "  ("..item.host..")"
if strutil.strlen(item.tunnel) > 0 then str=str.." via("..item.tunnel..")" end
end

str=self.driver.menu("hosts available", str,"vnc_mgr.lua: version "..settings:get("version"))
str=strutil.trim(str)


if strutil.strlen(str) == 0 then return "quit" end

toks=strutil.TOKENIZER(str, "  (", "Q")
tok=toks:next()
if tok=="Settings"
then 
	act="back"
	self:settings()
elseif tok=="New Host"
then
	host=self:config_host()
	act="launch"
elseif strutil.strlen(tok) > 0 
then 
	host=hosts:find(tok) 
	if host ~= nil then act=self:host_screen(host) end
end


return act,host
end


dialog.top_level=function(self)
local act, host

act,host=dialog:select_host()
while act ~= nil
do
	if act=="launch" then break end
	if act=="quit" then break end
	act,host=dialog:select_host()
end

return act,host
end


return dialog
end