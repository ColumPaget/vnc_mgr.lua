
SRC=includes.lua settings.lua apps.lua dialog-types.lua dialogs.lua vnc_url.lua hosts.lua connector.lua viewers.lua viewer.lua main.lua

all: $(SRC) 
	cat $(SRC) > vnc_mgr.lua
	chmod a+x vnc_mgr.lua
