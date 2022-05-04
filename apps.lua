

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


