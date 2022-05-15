require("stream")
require("strutil")
require("process")
require("filesys")
require("time")
require("net")
require("rawdata")
require("libuseful_errors")



function tobool(str)

str=string.lower(strutil.trim(str))

if strutil.strlen(str) < 1 then return false end

if string.sub(str,1,1) =='y' then return true end
if string.sub(str,1,1) =='n' then return false end
if str=="true" then return true end
if str=="false" then return false end
if tonumber(str) > 0 then return true end

return false
end



function SettingsInit()
settings={}

settings.items={}

function settings.set(self, key, value)
self.items[key]=value
end

function settings.get(self, key)
if settings.items[key] ~= nil then return settings.items[key] end
return ""
end

settings.load=function(self)
local S, str, toks

S=stream.STREAM(process.homeDir().."/.config/vnc_mgr/settings.conf", "r")
if S ~= nil
then
	str=S:readln()
 	while str ~= nil
	do
	str=strutil.trim(str)
	toks=strutil.TOKENIZER(str, "=")
	self:set(toks:next(), toks:remaining())
	str=S:readln()
	end
	S:close()
end
end


settings.save=function(self)
local S, key, value

S=stream.STREAM(process.homeDir().."/.config/vnc_mgr/settings.conf", "w")
if S ~= nil
then
for key,value in pairs(self.items)
do
	S:writeln(key.."="..value.."\n")
end
S:close()
end
end

settings:set("version", "1.0")
settings:load()
return settings
end


function AppFind(fname)
local path

path=filesys.find(fname, process.getenv("PATH"))
if strutil.strlen(path) > 0 then return(path) end
return("")
end

function AppsFindMulti(pattern)
local dirs, dir, files, file, path
local founds={}

dirs=strutil.TOKENIZER(process.getenv("PATH"), ":")
dir=dirs:next()
while dir ~= nil
do
	path=dir.."/"..pattern
	files=filesys.GLOB(path)
	file=files:next()
	while file ~= nil
	do
	table.insert(founds, file)
	file=files:next()
	end
	dir=dirs:next()
end

return founds
end


function AppFind1st(fname)
local toks

toks=strutil.TOKENIZER(AppFind(fname), ":")
return(toks:next())
end




function DialogsProcessCmd(cmd)
local S, pid, str, status

S=stream.STREAM(cmd)
pid=S:getvalue("PeerPID")
str=S:readdoc()
if str ~= nil then str=strutil.trim(str) end
S:close()


status=process.childStatus(pid)
while status == "running"
do
time.sleep(0)
status=process.childStatus(pid)
end

--detect pressing 'cancel' and return nil
if status ~= "exit:0" then return nil end

return str
end


function FormItemAdd(form, item_type, item_name, item_cmd_args, item_description)
local form_item={}

form_item.type=item_type
form_item.name=item_name
form_item.cmd_args=item_cmd_args
if item_description==nil
then
form_item.description=""
else
form_item.description=item_description
end

table.insert(form.config, #form.config+1, form_item)

--return newly created item so we can add other fields to it other than the default
return form_item
end


function FormParseOutput(form, result_str)
local results, form_item, val
local config={}

if strutil.strlen(result_str) == 0 then return nil end

results=strutil.TOKENIZER(result_str, "|")

for i,form_item in ipairs(form.config)
do
val=results:next()
if form_item.type=="boolean" 
then 
	config[form_item.name]=tobool(val)
else
	config[form_item.name]=val
end
end

return config
end


function FormFormatChoices(choices, selected)
local toks, item, combo_values
local unselected=""
local has_selection=false

if strutil.strlen(selected) > 0 then has_selection=true end

toks=strutil.TOKENIZER(choices, "|")
item=toks:next()

while item ~= nil
do
  if has_selection == false or selected ~= item 
  then 
	if strutil.strlen(unselected) > 0 then unselected=unselected .. "|" .. item 
	else unselected=item
	end
  end
  item=toks:next()
end

if has_selection == true then combo_values=selected.."|"..unselected
else combo_values=unselected
end

return combo_values
end



function QarmaFormAddBoolean(form, name)
form:add("boolean", name, "--add-checkbox='"..name.."'")
end


function QarmaFormAddChoice(form, name, choices, description, selected)
local combo_values

combo_values=FormFormatChoices(choices, selected)
form:add("choice", name, "--add-combo='"..name.."' --combo-values='".. combo_values .."'")
end


function QarmaFormAddEntry(form, name, text)
local str

str="--add-entry='"..name.."'"
if strutil.strlen(text) > 0 then str=str.." '"..text.."'" end

form:add("entry", name, str)
end


function QarmaFormRun(form, width, height)
local str, S

str="qarma --forms --title='" .. form.title .."' "
if strutil.strlen(form.text) then str=str.. "--text='" .. form.text .. "' " end
if width ~= nil and width > 0 then str=str.." --width "..tostring(width) end
if height ~= nil and height > 0 then str=str.." --height "..tostring(height) end



for i,config_item in ipairs(form.config)
do
	str=str..config_item.cmd_args.. " "
end

S=stream.STREAM("cmd:"..str, "")
str=strutil.trim(S:readdoc())
S:close()

return FormParseOutput(form, str)
end


function QarmaYesNoDialog(text, flags)
local S, str, pid

str="cmd:qarma --question --text='"..text.."'"
str=DialogsProcessCmd(str)

if str == nil then return "no" end
return "yes"
end


function QarmaInfoDialog(text, title, width, height)
local str

str="cmd:qarma --info --text='"..text.."'"
if width ~= nil and width > 0 then str=str.." --width "..tostring(width) end
if height ~= nil and height > 0 then str=str.." --height "..tostring(height) end
if strutil.strlen(title) > 0 then str=str.." --title '"..title.."'" end

str=DialogsProcessCmd(str)
-- str will be nil if user pressed cancel
return str
end


function QarmaTextEntryDialog(text, title)
local str

str="cmd:qarma --entry"
if strutil.strlen(text) > 0 then str=str.." --text '"..text.."'" end
if strutil.strlen(title) > 0 then str=str.." --title '"..title.."'" end

str=DialogsProcessCmd(str)
-- str will be nil if user pressed cancel
return str
end


function QarmaFileSelectionDialog(text, title)
local str

str="cmd:qarma --file-selection --text='"..text.."'"
if strutil.strlen(title) > 0 then str=str.." --title '"..title.."'" end

str=DialogsProcessCmd(str)
-- str will be nil if user pressed cancel
return str

end


function QarmaCalendarDialog(text)
local str

str="cmd:qarma --calendar --text='"..text.."'"
str=DialogsProcessCmd(str)
-- str will be nil if user pressed cancel
return str

end


function QarmaMenuDialog(text, options, title, width, height)
local str, toks, tok, pid

str="cmd:qarma --list --hide-header --text='"..text.."' "
if width ~= nil and width > 0 then str=str.." --width "..tostring(width) end
if height ~= nil and height > 0 then str=str.." --height "..tostring(height) end


if title ~= nil then str=str.." --title='"..title.."' " end

toks=strutil.TOKENIZER(options, "|")
tok=toks:next()
while tok ~= nil
do
str=str.. "'" .. tok .."' "
tok=toks:next()
end

str=DialogsProcessCmd(str)
-- str will be nil if user pressed cancel
return str
end


function QarmaLogDialogAddText(dialog, text)
if text ~= nil then dialog.S:writeln(text.."\n") end
dialog.S:flush()
end


function QarmaLogDialog(form, text, width, height)
local S, str
local dialog={}

str="cmd:qarma --text-info --text='"..text.."'"
if width ~= nil and width > 0 then str=str.." --width "..tostring(width) end
if height ~= nil and height > 0 then str=str.." --height "..tostring(height) end

dialog.S=stream.STREAM(str)
dialog.add=QarmaLogDialogAddText

return dialog
end




function QarmaFormObjectCreate(dialogs, title, text)
local form={}

form.title=title
form.text=text
form.config={}
form.add=FormItemAdd
form.addboolean=QarmaFormAddBoolean
form.addchoice=QarmaFormAddChoice
form.addentry=QarmaFormAddEntry
form.run=QarmaFormRun

return form
end


function QarmaObjectCreate()
local dialogs={}

dialogs.yesno=QarmaYesNoDialog
dialogs.info=QarmaInfoDialog
dialogs.entry=QarmaTextEntryDialog
dialogs.fileselect=QarmaFileSelectionDialog
dialogs.calendar=QarmaCalendarDialog
dialogs.menu=QarmaMenuDialog
dialogs.log=QarmaLogDialog
--dialogs.progress=QarmaProgressDialog
dialogs.form=QarmaFormObjectCreate

return dialogs
end


function ZenityFormAddBoolean(form, name)
form:add("boolean", name, "--add-combo='"..name.."' --combo-values='yes|no'")
end

function ZenityFormAddChoice(form, name, choices, description, selected)
local combo_values
combo_values=FormFormatChoices(choices, selected)

form:add("choice", name, "--add-combo='"..name.."' --combo-values='"..combo_values.."'")
end

function ZenityFormAddEntry(form, name)
form:add("entry", name, "--add-entry='"..name.."'")
end


function ZenityFormRun(form, width, height)
local str, S

str="zenity --forms --title='" .. form.title .. "' "
if strutil.strlen(form.text) then str=str.. "--text='" .. form.text .. "' " end
if width ~= nil and width > 0 then str=str.." --width "..tostring(width) end
if height ~= nil and height > 0 then str=str.." --height "..tostring(height) end



for i,config_item in ipairs(form.config)
do
	str=str..config_item.cmd_args.. " "
end

S=stream.STREAM("cmd:"..str, "")
str=strutil.trim(S:readdoc())
S:close()

return FormParseOutput(form, str)
end


function ZenityYesNoDialog(text, flags, title)
local str, pid

str="cmd:zenity --question --text='"..text.."'"
if strutil.strlen(title) > 0 then str=str.." --title '"..title.."'" end

str=DialogsProcessCmd(str)
-- str will be nil if user pressed cancel
if str==nil then return "no" end
return "yes"
end


function ZenityInfoDialog(text, title)
local S, str

str="cmd:zenity --info --text='"..text.."'"
if strutil.strlen(title) > 0 then str=str.." --title '"..title.."'" end

str=DialogsProcessCmd(str)
-- str will be nil if user pressed cancel
return str

end


function ZenityTextEntryDialog(text, title)
local str

str="cmd:zenity --entry --text='"..text.."'"
if strutil.strlen(title) > 0 then str=str.." --title '"..title.."'" end

str=DialogsProcessCmd(str)
-- str will be nil if user pressed cancel
return str
end


function ZenityFileSelectionDialog(text, title)
local str

str="cmd:zenity --file-selection --text='"..text.."'"
if strutil.strlen(title) > 0 then str=str.." --title '"..title.."'" end

str=DialogsProcessCmd(str)
-- str will be nil if user pressed cancel
return str
end


function ZenityCalendarDialog(text, title)
local str

str="cmd:zenity --calendar --text='"..text.."'"
if strutil.strlen(title) > 0 then str=str.." --title '"..title.."'" end

str=DialogsProcessCmd(str)
-- str will be nil if user pressed cancel
return str
end


function ZenityMenuDialog(text, options, title)
local str, toks, tok

str="cmd:zenity --list --hide-header --text='"..text.."' "
if strutil.strlen(title) > 0 then str=str.." --title '"..title.."'" end

toks=strutil.TOKENIZER(options, "|")
tok=toks:next()
while tok ~= nil
do
str=str.. "'" .. tok .."' "
tok=toks:next()
end


str=DialogsProcessCmd(str)
-- str will be nil if user pressed cancel
return str
end


function ZenityLogDialogAddText(dialog, text)
if text ~= nil then dialog.S:writeln(text.."\n") end
dialog.S:flush()
end


function ZenityLogDialog(form, text, title)
local S, str
local dialog={}

str="cmd:zenity --text-info --auto-scroll --title='"..text.."'"
if strutil.strlen(title) > 0 then str=str.." --title '"..title.."'" end
dialog.S=stream.STREAM(str)
dialog.add=ZenityLogDialogAddText

return dialog
end




function ZenityFormObjectCreate(dialogs, title, text)
local form={}

form.title=title
form.text=text
form.config={}
form.add=FormItemAdd
form.addboolean=ZenityFormAddBoolean
form.addchoice=ZenityFormAddChoice
form.addentry=ZenityFormAddEntry
form.run=ZenityFormRun

return form
end


function ZenityObjectCreate()
local dialogs={}

dialogs.yesno=ZenityYesNoDialog
dialogs.info=ZenityInfoDialog
dialogs.entry=ZenityTextEntryDialog
dialogs.fileselect=ZenityFileSelectionDialog
dialogs.calendar=ZenityCalendarDialog
dialogs.menu=ZenityMenuDialog
dialogs.log=ZenityLogDialog
--dialogs.progress=ZenityProgressDialog
dialogs.form=ZenityFormObjectCreate

return dialogs
end




function YadFormAddBoolean(form, name)
form:add("boolean", name, "--field='"..name..":CHK' ''")
end


function YadFormAddChoice(form, name, choices, description, selected)
local combo_values
combo_values=FormFormatChoices(choices, selected)

form:add("choice", name, "--field='"..name..":CB' '"..string.gsub(combo_values,'|', '!').."'")
end


function YadFormAddEntry(form, name)
form:add("entry", name, "--add-entry='"..name.."'")
end


function YadFormRun(form, width, height)
local str, S, i, config_item

str="yad --form --title='" .. form.title .. "' "
if strutil.strlen(form.text) then str=str.. "--text='" .. form.text .. "' " end
if width ~= nil and width > 0 then str=str.." --width "..tostring(width) end
if height ~= nil and height > 0 then str=str.." --height "..tostring(height) end


for i,config_item in ipairs(form.config)
do
	str=str..config_item.cmd_args.. " "
end

S=stream.STREAM("cmd:"..str, "")
str=strutil.trim(S:readdoc())
S:close()

return FormParseOutput(form, str)
end



function YadYesNoDialog(text, flags, title)
local str, pid

str="cmd:yad --question --text='"..text.."'"
if strutil.strlen(title) > 0 then str=str.." --title '"..title.."'" end

str=DialogsProcessCmd(str)
-- str will be nil if user pressed cancel

if str == nil then return "no" end
return "yes"
end


function YadInfoDialog(text, title)
local str

str="cmd:yad --text='"..text.."'"
if strutil.strlen(title) > 0 then str=str.." --title '"..title.."'" end

str=DialogsProcessCmd(str)
-- str will be nil if user pressed cancel
return str
end


function YadTextEntryDialog(text, title)
local str

str="cmd:yad --entry --text='"..text.."'"
if strutil.strlen(title) > 0 then str=str.." --title '"..title.."'" end

str=DialogsProcessCmd(str)
-- str will be nil if user pressed cancel
return str
end



function YadFileSelectionDialog(text, title)
local str

str="cmd:yad --file-selection --text='"..text.."'"
if strutil.strlen(title) > 0 then str=str.." --title '"..title.."'" end

str=DialogsProcessCmd(str)
-- str will be nil if user pressed cancel
return str
end


function YadCalendarDialog(text, title)
local str

str="cmd:yad --calendar --text='"..text.."'"
if strutil.strlen(title) > 0 then str=str.." --title '"..title.."'" end

str=DialogsProcessCmd(str)
-- str will be nil if user pressed cancel
return str

end



function YadLogDialogAddText(dialog, text)
if text ~= nil then dialog.S:writeln(text.."\n") end
dialog.S:flush()
end


function YadLogDialog(form, text, title)
local S, str
local dialog={}

str="cmd:yad --text-info "
if strutil.strlen(text) > 0 then str=str.." --text='"..text.."'" end
if strutil.strlen(title) > 0 then str=str.." --title '"..title.."'" end
dialog.S=stream.STREAM(str)
dialog.add=YadLogDialogAddText

return dialog
end



function YadMenuDialog(text, options, title)
local str, toks, tok

str="cmd:yad --list --no-headers --column='c1' " 
if strutil.strlen(title) > 0 then str=str.." --title '"..title.."'" end
toks=strutil.TOKENIZER(options, "|")
tok=toks:next()
while tok ~= nil
do
str=str.. "'" .. tok .."' "
tok=toks:next()
end

str=DialogsProcessCmd(str)
-- str will be nil if user pressed cancel
return str
end




function YadFormObjectCreate(dialogs, title, text)
local form={}

form.title=title
form.text=text
form.config={}
form.add=FormItemAdd
form.addboolean=YadFormAddBoolean
form.addchoice=YadFormAddChoice
form.addentry=YadFormAddEntry
form.run=YadFormRun

return form
end


function YadObjectCreate()
local dialogs={}

dialogs.yesno=YadYesNoDialog
dialogs.info=YadInfoDialog
dialogs.entry=YadTextEntryDialog
dialogs.fileselect=YadFileSelectionDialog
dialogs.calendar=YadCalendarDialog
dialogs.log=YadLogDialog
dialogs.menu=YadMenuDialog
--dialogs.progress=YadProgressDialog
dialogs.form=YadFormObjectCreate

return dialogs
end


function TextConsoleInfoDialog(text)

end


function TextConsoleTextEntryDialog(form, text)
local str

str=form.prompt(text..":")

return str
end



function TextConsoleFileSelectionDialog(text)
local str

return str
end


function TextConsoleCalendarDialog(text)
local str

return str
end



function TextConsoleLogDialogAddText(dialog, text)
dialog.term:puts(text.."\n")
end


function TextConsoleLogDialog(form, text)
local dialog={}

--there is no communication stream to a dialog application
--as this type of dialog is supported by native libUseful
--terminal functions
dialog.S=form.stdio

dialog.term=form.term
dialog.add=TextConsoleLogDialogAddText
dialog.term:bar("PRESS ANY KEY TO END RECORDING")

return dialog
end



function TextConsoleMenuDialog(form, text, options, description)
local S, str, toks, tok, menu

if description==nil then description="" end

form.term:clear()
form.term:move(2,2)
form.term:puts("Choose '"..text.."'  - " .. description)
menu=terminal.TERMMENU(form.term, 2, 4, form.term:width()-4, form.term:length() - 10)

toks=strutil.TOKENIZER(options, "|")
tok=toks:next()
while tok ~= nil
do
	menu:add(tok, tok)
	tok=toks:next()
end

str=menu:run()

return str
end



function TextConsoleYesNoDialog(form, text, description)
return TextConsoleMenuDialog(form, text, "yes|no", description)
end



function TextConsoleFormAddBoolean(form, name, description)
form:add("boolean", name, "", description)
end


function TextConsoleFormAddChoice(form, name, choices, description, selected)
local item
item=form:add("choice", name, "", description)
item.choices=choices
end


function TextConsoleFormAddEntry(form, name, description)
form:add("entry", name, "", description)
end


function TextConsoleFormRun(form)
local str, results, toks, tok

form.term:clear()
results=""

for i,form_item in ipairs(form.config)
do

	if form_item.type == "boolean"
	then
		str=TextConsoleYesNoDialog(form, form_item.name, form_item.description)
		results=results..str.."|"
	elseif form_item.type=="choice"
	then
		str=TextConsoleMenuDialog(form, form_item.name, form_item.choices, form_item.description)
		results=results..str.."|"
	elseif qtype=="entry"
	then
		str=TextConsoleTextEntryDialog(form, form_item.name, form_item.description)
		results=results..str.."|"
	end
end

form.term:reset()
return FormParseOutput(form, results)
end




function TextConsoleFormObjectCreate(dialogs, title)
local form={}

form.title=title
form.stdio=dialogs.stdio
form.term=dialogs.term
form.config={}
form.add=FormItemAdd
form.addboolean=TextConsoleFormAddBoolean
form.addchoice=TextConsoleFormAddChoice
form.addentry=TextConsoleFormAddEntry
form.run=TextConsoleFormRun

return form
end


function TextConsoleObjectCreate()
local dialogs={}

dialogs.stdio=stream.STREAM("-")

dialogs.term=terminal.TERM(dialogs.stdio)
dialogs.yesno=TextConsoleYesNoDialog
dialogs.info=TextConsoleInfoDialog
dialogs.entry=TextConsoleTextEntryDialog
dialogs.fileselect=TextConsoleFileSelectionDialog
dialogs.calendar=TextConsoleCalendarDialog
dialogs.log=TextConsoleLogDialog
dialogs.menu=TextConsoleMenuDialog
--dialogs.progress=TextConsoleProgressDialog
dialogs.form=TextConsoleFormObjectCreate

return dialogs
end



function DialogSelectDriver()

if strutil.strlen(filesys.find("zenity", process.getenv("PATH"))) > 0 then return "zenity" end
if strutil.strlen(filesys.find("qarma", process.getenv("PATH"))) > 0 then return "qarma" end
if strutil.strlen(filesys.find("yad", process.getenv("PATH"))) > 0 then return "yad" end

return "native"
end


function NewDialog(driver)
local dialog={}


dialog.config=""

if strutil.strlen(driver) == 0 then driver=DialogSelectDriver() end

if driver == "qarma"
then
	dialog=QarmaObjectCreate()
elseif driver == "zenity"
then
	dialog=ZenityObjectCreate()
elseif driver == "yad"
then
	dialog=YadObjectCreate()
else
	dialog=TextConsoleObjectCreate(dialog)
end

return dialog
end

function DialogsInit()
local dialog={}

dialog.driver=NewDialog("qarma")

dialog.notice=function(self, msg)

self.driver.info(msg, "vnc_mgr.lua: version "..settings:get("version"))
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


dialog.ask_password=function(self, window_title)
local str

str=self.driver.entry("Enter password", window_title)

return str
end


dialog.ask_tunnel=function(self, prefix, title)
local str

str=self.driver.entry(title)
if strutil.strlen(str) > 0 then str=prefix..":"..str end

return str
end


dialog.ask_certificate=function(self)
local cert, key, form, choices

while true
do
	form=self.driver.form("Enter path to an authentication certificate and key , or leave blank for none", "SSL/TLS/X509 certificate")
	form:addentry("CertFile")
	form:addentry("KeyFile")
	choices=form:run()
	if choices == nil then return nil end

	cert=choices.CertFile
	key=choices.KeyFile
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
local str

str=settings:get("proxy")
if strutil.strlen(str) > 0
then 
				str=str.."|change" 
else
				str="set new"
end

str=str.."|none"
form:addchoice("Global Proxy", str)
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

str=choices["Global Proxy"]
if strutil.strlen(str) > 0 
then 
  if str == "none"
	then
			settings:set("proxy", "")
  elseif str == "change" or str == "set new"
	then
			str=self.driver.entry("Enter Global Proxy", "Settings: vnc_mgr.lua")
			if strutil.strlen(str) > 0 then settings:set("proxy", str) end
	else
			settings:set("proxy", str)
	end
end
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
	--nil, rather than blank, means the user hit 'cancel'
	if str==nil then return nil end
	host.certificate=str
	host.keyfile=key
elseif host.tunnel_type == "SOCKS5+TLS"
then
	host.host="tls:"..choices.Host
	host.tunnel=dialog:ask_tunnel("socks5","SOCKS5 Proxy Host/URL") 
	str=dialog:ask_certificate() 
	--nil, rather than blank, means the user hit 'cancel'
	if str==nil then return nil end
	host.tunnel=str
end

return host
end



dialog.config_host=function(self, config)
local form, choices, host, str

while host == nil
do

if config ~= nil then
 str="Host: "..config.name
 form=self.driver:form(str)
else form=self.driver:form("Setup New Host", "Host can be: <hostname::portnumber> or <hostname:vnc-display>")
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
form:addboolean("Cursor Dot")

choices=form:run()
if choices == nil then return false end

if choices["View Only"]==true then host.view_only=true else host.view_only=false end
if choices["Single Viewer"]==true then host.single_viewer=true else host.single_viewer=false end
if choices["Full Screen"]==true then host.fullscreen=true else host.fullscreen=false end
if choices["Cursor Dot"]==true then host.cursor_dot=true else host.cursor_dot=false end

return true
end


dialog.host_screen=function(self, host)
local title, str
local act="back"

title="Host: "..host.name
if strutil.strlen(host.tunnel) > 0 then title=title.."  via: " .. host.tunnel end

str="Launch|Launch with Options|Change Password"
if string.sub(host.host, 1, 4) == "tls:" then str=str.."|Change Certificate" end
str=str.."|Delete Host"

str=self.driver.menu(title, str, "vnc_mgr.lua: version "..settings:get("version"))
str=strutil.trim(str)
if str=="Delete Host"
then 
	hosts:delete(host.name) 
	hosts:save()
	act="back"
elseif str=="Change Password"
then 
	host.password=self:ask_password("vnc_mgr: password for "..host.name)
	hosts:save()
	act="back"
elseif str=="Change Certificate"
then 
	host.certificate,host.keyfile=dialog:ask_certificate()
	if host.certificate ~= nil then hosts:save() end
	act="back"
elseif str=="Launch with Options"
then
	if self:launch_options_screen(host) == true then act="launch"
	else act="back"
	end
elseif str=="Launch"
then
	act="launch"
end

return act
end


dialog.select_host=function(self)
local str, i, item, toks, tok
local host, hostname

str="Settings|New Host|"
for i,item in pairs(hosts.items)
do
str=str.. "|" .. item.name .. "    ("..item.host..")"
if strutil.strlen(item.tunnel) > 0 then str=str.." via("..item.tunnel..")" end
end

str=self.driver.menu("hosts available", str,"vnc_mgr.lua: version "..settings:get("version"), 400)
str=strutil.trim(str)


if strutil.strlen(str) == 0 then return "quit" end

toks=strutil.TOKENIZER(str, "    (", "Q")
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
	if host ~= nil
	then 
	host.cursor_dot=true
	act=self:host_screen(host) 
	end
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
	if strutil.strlen(item.keyfile) > 0 then str=str.. " key=" .. item.keyfile end
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

function ViewerAdd(viewers, path, platform, cmd, toks)
local str
local viewer={}


viewer.password_arg=""

str=toks:next()
while str ~= nil
do
if str=="port" then viewer.display_or_port="port" 
elseif string.sub(str, 1, 7) == "pw_arg=" then viewer.password_arg=string.sub(str, 8)
elseif string.sub(str, 1, 11) == "pwfile_arg=" then viewer.pwfile_arg=string.sub(str, 12)
elseif string.sub(str, 1, 13) == "autopass_arg=" then viewer.autopass_arg=string.sub(str, 14)
elseif string.sub(str, 1, 13) == "viewonly_arg=" then viewer.viewonly_arg=string.sub(str, 14)
elseif string.sub(str, 1, 13) == "nocursor_arg=" then viewer.nocursor_arg=string.sub(str, 14)
elseif string.sub(str, 1, 12) == "noshare_arg=" then viewer.noshare_arg=string.sub(str, 13)
elseif string.sub(str, 1, 15) == "fullscreen_arg=" then viewer.fullscreen_arg=string.sub(str, 16)
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
else
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
local viewer_configs={
"VNC-Viewer*:fullscreen_arg=-FullScreen=1:noshare_arg=-Shared=0:nocursor_arg=-DotWhenNoCursor",
 "vncviewer.exe:noshare_arg=/noshared:fullscreen_arg=/fullscreen:viewonly_arg=/viewonly",
 "ultravnc.exe:pw_arg=/password",
 "ultravncviewer.exe:pw_arg=/password",
 "tightvnc:autopass_arg=-autopass:noshare_arg=-noshared:fullscreen_arg=-fullscreen:viewonly_arg=-viewonly",
 "tightvncviewer:autopass_arg=-autopass:noshare_arg=-noshared:fullscreen_arg=-fullscreen:viewonly_arg=-viewonly",
 "xtightvncviewer:autopass_arg=-autopass:noshare_arg=-noshared:fullscreen_arg=-fullscreen:viewonly_arg=-viewonly",
 "ultravnc",
 "tightvnc-jviewer.jar:port:pw_arg=-password",
 "turbovncviewer.exe:display:fullscreen_arg=/fullscreen:autopass_arg=/autopass:noshare_arg=/noshared:viewonly_arg=/viewonly",
 "tigervnc:pwfile_arg=-passwd:noshare_arg=-Shared=no:viewonly_arg=-ViewOnly:fullscreen_arg=-FullScreen:nocursor_arg=-DotWhenNoCursor",
 "tigervncviewer:pwfile_arg=-passwd:noshare_arg=-Shared=no:viewonly_arg=-ViewOnly:fullscreen_arg=-FullScreen:nocursor_arg=-DotWhenNoCursor",
 "xtigervncviewer:pwfile_arg=-passwd:noshare_arg=-Shared=no:viewonly_arg=-ViewOnly:fullscreen_arg=-FullScreen:nocursor_arg=-DotWhenNoCursor",
 "vncviewer.jar",
 "vncviewer"}

local viewers={}
local str, i, config

	for i,config in ipairs(viewer_configs)
	do
		--get first item in config, as it is the app name and subsequent ones are possible settings
		toks=strutil.TOKENIZER(config, ":")
		apps=AppsFindMulti(toks:next())
		for i,str in ipairs(apps)
		do
		if strutil.strlen(str) > 0 then ViewerConsider(viewers, str, toks) end
		end
	end

return(viewers)
end






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


function VNCProcess(self, S, host)
local str

str=VNCReadLine(S)
if str ~= nil
then
	print(str)
	if str=="Password:"
	then S:writeln(host.password.."\n") 
	elseif string.sub(str, 1, 21) == "Authentication failed"
	then
	dialogs:notice("Authentication Failure to vnc:" .. host.name) 
	end
	return true
end

-- if we read nil then the vnc viewer shut down, and we will get here
if strutil.strlen(self.pwfile_path) > 0 then filesys.unlink(self.pwfile_path) end

return false
end


function VNCLaunchPasswordFile(host)
local str, path, S

path=process.homeDir().."/."..host.name.."-vncpasswd.tmp"
filesys.unlink(path)
str=AppFind("vncpasswd")
if strutil.strlen(str) > 0
then
S=stream.STREAM("cmd:".. str.. " -f >"..path,  "rw pty")
print(str)
process.usleep(100000)
S:writeln(host.password.."\n")
process.usleep(10000)
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

str=viewer.cmd.." " .. params.host .. ":" 
if viewer.display_or_port == "port" then str=str..params.port
else str=str ..params.display end

if strutil.strlen(viewer.password_arg) > 0 then str=str.." "..viewer.password_arg.." "..config.password end

if host.view_only == true and strutil.strlen(viewer.viewonly_arg) > 0 then str=str.. " " .. viewer.viewonly_arg end
if host.single_viewer == true and strutil.strlen(viewer.noshare_arg) > 0 then str=str.. " " .. viewer.noshare_arg end
if host.fullscreen == true and strutil.strlen(viewer.fullscreen_arg) > 0 then str=str.. " " .. viewer.fullscreen_arg end
if host.cursor_dot == true and strutil.strlen(viewer.nocursor_arg) > 0 then str=str.. " " .. viewer.nocursor_arg .. "=1" end

if strutil.strlen(viewer.autopass_arg) > 0 then str=str .. " " .. viewer.autopass_arg end
if strutil.strlen(viewer.pwfile_arg) > 0
then
 viewer.pwfile_path=VNCLaunchPasswordFile(host) 
 str=str .. " " ..viewer.pwfile_arg .. " " .. viewer.pwfile_path
end

print(str)
viewer.stream=stream.STREAM("cmd: "..str, "rw pty")
viewer.process=VNCProcess
if strutil.strlen(viewer.autopass_arg) > 0 then viewer.stream:writeln(host.password.."\n") end
end
 
return viewer
end





function InitConnections()
local target, config, act, str


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


url,config,connector=InitConnections()
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
	if S==connector.client
	then
		if connector:from_client() == false then break end
	end

	if S==connector.dest 
  then 
		if connector:to_client() == false 
		then 
				dialogs:notice("Server Closed Connection")
				break 
		end
	end
end

if S==viewer.stream
then
	if viewer:process(S, config) == false then break end
end

end

viewer:close()
if connector ~= nil then connector:close() end
end

