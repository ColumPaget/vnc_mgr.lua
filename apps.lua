

function AppFind(fname)
local dirs, dir, i
local apps=""

dirs=strutil.TOKENIZER(process.getenv("PATH"), ":")
dir=dirs:next()
while dir ~= nil
do
	path=dir.."/"..fname

	if filesys.exists(path) == true 
	then
			apps=apps..path
			break
	end
	dir=dirs:next()
end

return(apps)
end


function AppFind1st(fname)
local toks

toks=strutil.TOKENIZER(AppFind(fname), ":")
return(toks:next())
end


