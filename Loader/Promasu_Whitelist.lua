
local function encode(data) 
    return syn.crypt.base64.encode(tostring(data))
end

local function decode(data)
    return syn.crypt.base64.decode(tostring(data))
end

local data = syn.request({ 
    Url = ('https://website.whitelist/whitelist/Server.php?key='..whitelist_key); 
    Method = 'GET';
})


if z3d.StatusCode == -9402 then
    local response = decode(z3d.Body)
    setclipboard(response)
    -- Checking if the response is equal to the data
    if response == whitelist_key then
	fbt()
    else
        fbt(kick)
    end
else
    
end

local websocket = require "http.websocket"

local ws = websocket.new_from_uri("wss://ws-feed.gdax.com")
assert(ws:connect())
assert(ws:send([[{"type": "subscribe", "product_id": "BTC-USD"}]]))
for _=1, 5 do
	local data = assert(ws:receive())
	print(data)
end
assert(ws:close())


local uri = assert(arg[1], "URI needed")
local req_body = arg[2]
local req_timeout = 10

local request = require "http.request"

local req = request.new_from_uri(uri)
if req_body then
	req.headers:upsert(":method", "POST")
	req:set_body(req_body)
end

print("# REQUEST")
print("## HEADERS")
for k, v in req.headers:each() do
	print(k, v)
end
print()
if req.body then
	print("## BODY")
	print(req.body)
	print()
end

print("# RESPONSE")
local headers, stream = req:go(req_timeout)
if headers == nil then
	io.stderr:write(tostring(stream), "\n")
	os.exit(1)
end
print("## HEADERS")
for k, v in headers:each() do
	print(k, v)
end
print()
print("## BODY")
local body, err = stream:get_body_as_string()
if not body and err then
	io.stderr:write(tostring(err), "\n")
	os.exit(1)
end


local port = arg[1] or 0 -- 0 means pick one at random

local cqueues = require "cqueues"
local http_server = require "http.server"
local http_headers = require "http.headers"

local myserver = assert(http_server.listen {
	host = "localhost";
	port = port;
	onstream = function(myserver, stream) -- luacheck: ignore 212
		-- Read in headers
		local req_headers = assert(stream:get_headers())
		local req_method = req_headers:get ":method"

		-- Build response headers
		local res_headers = http_headers.new()
		if req_method ~= "GET" and req_method ~= "HEAD" then
			res_headers:upsert(":status", "405")
			assert(stream:write_headers(res_headers, true))
			return
		end
		if req_headers:get ":path" == "/" then
			res_headers:append(":status", "200")
			res_headers:append("content-type", "text/html")
			-- Send headers to client; end the stream immediately if this was a HEAD request
			assert(stream:write_headers(res_headers, req_method == "HEAD"))
			if req_method ~= "HEAD" then
				assert(stream:write_chunk([[
<!DOCTYPE html>
<html>
<head>
	<title>EventSource demo</title>
</head>
<body>
	<p>This page uses <a href="https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events">server-sent_events</a> to show the live server time:</p>
	<div id="time"></div>
	<script type="text/javascript">
		var events = new EventSource("/event-stream");
		var el = document.getElementById("time");
		events.onmessage = function(e) {
			el.innerHTML = e.data;
		}
	</script>
</body>
</html>
]], true))
			end
		elseif req_headers:get ":path" == "/event-stream" then
			res_headers:append(":status", "200")
			res_headers:append("content-type", "text/event-stream")
			-- Send headers to client; end the stream immediately if this was a HEAD request
			assert(stream:write_headers(res_headers, req_method == "HEAD"))
			if req_method ~= "HEAD" then
				-- Start a loop that sends the current time to the client each second
				while true do
					local msg = string.format("data: The time is now %s.\n\n", os.date())
					assert(stream:write_chunk(msg, false))
					cqueues.sleep(1) -- yield the current thread for a second.
				end
			end
		else
			res_headers:append(":status", "404")
			assert(stream:write_headers(res_headers, true))
		end
	end;
	onerror = function(myserver, context, op, err, errno) -- luacheck: ignore 212
		local msg = op .. " on " .. tostring(context) .. " failed"
		if err then
			msg = msg .. ": " .. tostring(err)
		end
		assert(io.stderr:write(msg, "\n"))
	end;
})

-- Manually call :listen() so that we are bound before calling :localname()
assert(myserver:listen())
do
	local bound_port = select(3, myserver:localname())
	assert(io.stderr:write(string.format("Now listening on port %d\nOpen http://localhost:%d/ in your browser\n", bound_port, bound_port)))
end
-- Start the main server loop
assert(myserver:loop())



local port = arg[1] or 8000
local dir = arg[2] or "."

local new_headers = require "http.headers".new
local http_server = require "http.server"
local http_util = require "http.util"
local http_version = require "http.version"
local ce = require "cqueues.errno"
local lfs = require "lfs"
local lpeg = require "lpeg"
local uri_patts = require "lpeg_patterns.uri"

local mdb do
	-- If available, use libmagic https://github.com/mah0x211/lua-magic
	local ok, magic = pcall(require, "magic")
	if ok then
		mdb = magic.open(magic.MIME_TYPE+magic.PRESERVE_ATIME+magic.RAW+magic.ERROR)
		if mdb:load() ~= 0 then
			error(magic:error())
		end
	end
end

local uri_reference = uri_patts.uri_reference * lpeg.P(-1)

local default_server = string.format("%s/%s", http_version.name, http_version.version)

local xml_escape do
	local escape_table = {
		["'"] = "&apos;";
		["\""] = "&quot;";
		["<"] = "&lt;";
		[">"] = "&gt;";
		["&"] = "&amp;";
	}
	function xml_escape(str)
		str = string.gsub(str, "['&<>\"]", escape_table)
		str = string.gsub(str, "[%c\r\n]", function(c)
			return string.format("&#x%x;", string.byte(c))
		end)
		return str
	end
end

local human do -- Utility function to convert to a human readable number
	local suffixes = {
		[0] = "";
		[1] = "K";
		[2] = "M";
		[3] = "G";
		[4] = "T";
		[5] = "P";
	}
	local log = math.log
	if _VERSION:match("%d+%.?%d*") < "5.1" then
		log = require "compat53.module".math.log
	end
	function human(n)
		if n == 0 then return "0" end
		local order = math.floor(log(n, 2) / 10)
		if order > 5 then order = 5 end
		n = math.ceil(n / 2^(order*10))
		return string.format("%d%s", n, suffixes[order])
	end
end

local function reply(myserver, stream) -- luacheck: ignore 212
	-- Read in headers
	local req_headers = assert(stream:get_headers())
	local req_method = req_headers:get ":method"

	-- Log request to stdout
	assert(io.stdout:write(string.format('[%s] "%s %s HTTP/%g"  "%s" "%s"\n',
		os.date("%d/%b/%Y:%H:%M:%S %z"),
		req_method or "",
		req_headers:get(":path") or "",
		stream.connection.version,
		req_headers:get("referer") or "-",
		req_headers:get("user-agent") or "-"
	)))

	-- Build response headers
	local res_headers = new_headers()
	res_headers:append(":status", nil)
	res_headers:append("server", default_server)
	res_headers:append("date", http_util.imf_date())

	if req_method ~= "GET" and req_method ~= "HEAD" then
		res_headers:upsert(":status", "405")
		assert(stream:write_headers(res_headers, true))
		return
	end

	local path = req_headers:get(":path")
	local uri_t = assert(uri_reference:match(path), "invalid path")
	path = http_util.resolve_relative_path("/", uri_t.path)
	local real_path = dir .. path
	local file_type = lfs.attributes(real_path, "mode")
	if file_type == "directory" then
		-- directory listing
		path = path:gsub("/+$", "") .. "/"
		res_headers:upsert(":status", "200")
		res_headers:append("content-type", "text/html; charset=utf-8")
		assert(stream:write_headers(res_headers, req_method == "HEAD"))
		if req_method ~= "HEAD" then
			assert(stream:write_chunk(string.format([[
<!DOCTYPE html>
<html>
<head>
	<title>Index of %s</title>
	<style>
		a {
			float: left;
		}
		a::before {
			width: 1em;
			float: left;
			content: "\0000a0";
		}
		a.directory::before {
			content: "📁";
		}
		table {
			width: 800px;
		}
		td {
			padding: 0 5px;
			white-space: nowrap;
		}
		td:nth-child(2) {
			text-align: right;
			width: 3em;
		}
		td:last-child {
			width: 1px;
		}
	</style>
</head>
<body>
	<h1>Index of %s</h1>
	<table>
		<thead><tr>
			<th>File Name</th><th>Size</th><th>Modified</th>
		</tr></thead>
		<tbody>
]], xml_escape(path), xml_escape(path)), false))
			-- lfs doesn't provide a way to get an errno for attempting to open a directory
			-- See https://github.com/keplerproject/luafilesystem/issues/87
			for filename in lfs.dir(real_path) do
				if not (filename == ".." and path == "/") then -- Exclude parent directory entry listing from top level
					local stats = lfs.attributes(real_path .. "/" .. filename)
					if stats.mode == "directory" then
						filename = filename .. "/"
					end
					assert(stream:write_chunk(string.format("\t\t\t<tr><td><a class='%s' href='%s'>%s</a></td><td title='%d bytes'>%s</td><td><time>%s</time></td></tr>\n",
						xml_escape(stats.mode:gsub("%s", "-")),
						xml_escape(http_util.encodeURI(path .. filename)),
						xml_escape(filename),
						stats.size,
						xml_escape(human(stats.size)),
						xml_escape(os.date("!%Y-%m-%d %X", stats.modification))
					), false))
				end
			end
			assert(stream:write_chunk([[
		</tbody>
	</table>
</body>
</html>
]], true))
		end
	elseif file_type == "file" then
		local fd, err, errno = io.open(real_path, "rb")
		local code
		if not fd then
			if errno == ce.ENOENT then
				code = "404"
			elseif errno == ce.EACCES then
				code = "403"
			else
				code = "503"
			end
			res_headers:upsert(":status", code)
			res_headers:append("content-type", "text/plain")
			assert(stream:write_headers(res_headers, req_method == "HEAD"))
			if req_method ~= "HEAD" then
				assert(stream:write_body_from_string("Fail!\n"..err.."\n"))
			end
		else
			res_headers:upsert(":status", "200")
			local mime_type = mdb and mdb:file(real_path) or "application/octet-stream"
			res_headers:append("content-type", mime_type)
			assert(stream:write_headers(res_headers, req_method == "HEAD"))
			if req_method ~= "HEAD" then
				assert(stream:write_body_from_file(fd))
			end
		end
	elseif file_type == nil then
		res_headers:upsert(":status", "404")
		assert(stream:write_headers(res_headers, true))
	else
		res_headers:upsert(":status", "403")
		assert(stream:write_headers(res_headers, true))
	end
end

local myserver = assert(http_server.listen {
	host = "localhost";
	port = port;
	max_concurrent = 100;
	onstream = reply;
	onerror = function(myserver, context, op, err, errno) -- luacheck: ignore 212
		local msg = op .. " on " .. tostring(context) .. " failed"
		if err then
			msg = msg .. ": " .. tostring(err)
		end
		assert(io.stderr:write(msg, "\n"))
	end;
})

-- Manually call :listen() so that we are bound before calling :localname()
assert(myserver:listen())
do
	local bound_port = select(3, myserver:localname())
	assert(io.stderr:write(string.format("Now listening on port %d\n", bound_port)))
end
-- Start the main server loop
assert(myserver:loop())




local port = arg[1] or 8000
local dir = arg[2] or "."

local new_headers = require "http.headers".new
local http_server = require "http.server"
local http_util = require "http.util"
local http_version = require "http.version"
local ce = require "cqueues.errno"
local lfs = require "lfs"
local lpeg = require "lpeg"
local uri_patts = require "lpeg_patterns.uri"

local mdb do
	-- If available, use libmagic https://github.com/mah0x211/lua-magic
	local ok, magic = pcall(require, "magic")
	if ok then
		mdb = magic.open(magic.MIME_TYPE+magic.PRESERVE_ATIME+magic.RAW+magic.ERROR)
		if mdb:load() ~= 0 then
			error(magic:error())
		end
	end
end

local uri_reference = uri_patts.uri_reference * lpeg.P(-1)

local default_server = string.format("%s/%s", http_version.name, http_version.version)

local xml_escape do
	local escape_table = {
		["'"] = "&apos;";
		["\""] = "&quot;";
		["<"] = "&lt;";
		[">"] = "&gt;";
		["&"] = "&amp;";
	}
	function xml_escape(str)
		str = string.gsub(str, "['&<>\"]", escape_table)
		str = string.gsub(str, "[%c\r\n]", function(c)
			return string.format("&#x%x;", string.byte(c))
		end)
		return str
	end
end

local human do -- Utility function to convert to a human readable number
	local suffixes = {
		[0] = "";
		[1] = "K";
		[2] = "M";
		[3] = "G";
		[4] = "T";
		[5] = "P";
	}
	local log = math.log
	if _VERSION:match("%d+%.?%d*") < "5.1" then
		log = require "compat53.module".math.log
	end
	function human(n)
		if n == 0 then return "0" end
		local order = math.floor(log(n, 2) / 10)
		if order > 5 then order = 5 end
		n = math.ceil(n / 2^(order*10))
		return string.format("%d%s", n, suffixes[order])
	end
end

local function reply(myserver, stream) -- luacheck: ignore 212
	-- Read in headers
	local req_headers = assert(stream:get_headers())
	local req_method = req_headers:get ":method"

	-- Log request to stdout
	assert(io.stdout:write(string.format('[%s] "%s %s HTTP/%g"  "%s" "%s"\n',
		os.date("%d/%b/%Y:%H:%M:%S %z"),
		req_method or "",
		req_headers:get(":path") or "",
		stream.connection.version,
		req_headers:get("referer") or "-",
		req_headers:get("user-agent") or "-"
	)))

	-- Build response headers
	local res_headers = new_headers()
	res_headers:append(":status", nil)
	res_headers:append("server", default_server)
	res_headers:append("date", http_util.imf_date())

	if req_method ~= "GET" and req_method ~= "HEAD" then
		res_headers:upsert(":status", "405")
		assert(stream:write_headers(res_headers, true))
		return
	end

	local path = req_headers:get(":path")
	local uri_t = assert(uri_reference:match(path), "invalid path")
	path = http_util.resolve_relative_path("/", uri_t.path)
	local real_path = dir .. path
	local file_type = lfs.attributes(real_path, "mode")
	if file_type == "directory" then
		-- directory listing
		path = path:gsub("/+$", "") .. "/"
		res_headers:upsert(":status", "200")
		res_headers:append("content-type", "text/html; charset=utf-8")
		assert(stream:write_headers(res_headers, req_method == "HEAD"))
		if req_method ~= "HEAD" then
			assert(stream:write_chunk(string.format([[
<!DOCTYPE html>
<html>
<head>
	<title>Index of %s</title>
	<style>
		a {
			float: left;
		}
		a::before {
			width: 1em;
			float: left;
			content: "\0000a0";
		}
		a.directory::before {
			content: "📁";
		}
		table {
			width: 800px;
		}
		td {
			padding: 0 5px;
			white-space: nowrap;
		}
		td:nth-child(2) {
			text-align: right;
			width: 3em;
		}
		td:last-child {
			width: 1px;
		}
	</style>
</head>
<body>
	<h1>Index of %s</h1>
	<table>
		<thead><tr>
			<th>File Name</th><th>Size</th><th>Modified</th>
		</tr></thead>
		<tbody>
]], xml_escape(path), xml_escape(path)), false))
			-- lfs doesn't provide a way to get an errno for attempting to open a directory
			-- See https://github.com/keplerproject/luafilesystem/issues/87
			for filename in lfs.dir(real_path) do
				if not (filename == ".." and path == "/") then -- Exclude parent directory entry listing from top level
					local stats = lfs.attributes(real_path .. "/" .. filename)
					if stats.mode == "directory" then
						filename = filename .. "/"
					end
					assert(stream:write_chunk(string.format("\t\t\t<tr><td><a class='%s' href='%s'>%s</a></td><td title='%d bytes'>%s</td><td><time>%s</time></td></tr>\n",
						xml_escape(stats.mode:gsub("%s", "-")),
						xml_escape(http_util.encodeURI(path .. filename)),
						xml_escape(filename),
						stats.size,
						xml_escape(human(stats.size)),
						xml_escape(os.date("!%Y-%m-%d %X", stats.modification))
					), false))
				end
			end
			assert(stream:write_chunk([[
		</tbody>
	</table>
</body>
</html>
]], true))
		end
	elseif file_type == "file" then
		local fd, err, errno = io.open(real_path, "rb")
		local code
		if not fd then
			if errno == ce.ENOENT then
				code = "404"
			elseif errno == ce.EACCES then
				code = "403"
			else
				code = "503"
			end
			res_headers:upsert(":status", code)
			res_headers:append("content-type", "text/plain")
			assert(stream:write_headers(res_headers, req_method == "HEAD"))
			if req_method ~= "HEAD" then
				assert(stream:write_body_from_string("Fail!\n"..err.."\n"))
			end
		else
			res_headers:upsert(":status", "200")
			local mime_type = mdb and mdb:file(real_path) or "application/octet-stream"
			res_headers:append("content-type", mime_type)
			assert(stream:write_headers(res_headers, req_method == "HEAD"))
			if req_method ~= "HEAD" then
				assert(stream:write_body_from_file(fd))
			end
		end
	elseif file_type == nil then
		res_headers:upsert(":status", "404")
		assert(stream:write_headers(res_headers, true))
	else
		res_headers:upsert(":status", "403")
		assert(stream:write_headers(res_headers, true))
	end
end

local myserver = assert(http_server.listen {
	host = "localhost";
	port = port;
	max_concurrent = 100;
	onstream = reply;
	onerror = function(myserver, context, op, err, errno) -- luacheck: ignore 212
		local msg = op .. " on " .. tostring(context) .. " failed"
		if err then
			msg = msg .. ": " .. tostring(err)
		end
		assert(io.stderr:write(msg, "\n"))
	end;
})

-- Manually call :listen() so that we are bound before calling :localname()
assert(myserver:listen())
do
	local bound_port = select(3, myserver:localname())
	assert(io.stderr:write(string.format("Now listening on port %d\n", bound_port)))
end
-- Start the main server loop
assert(myserver:loop())


local request = require "http.request"

-- This endpoint returns a never-ending stream of chunks containing the current time
local req = request.new_from_uri("https://http2.golang.org/clockstream")
local _, stream = assert(req:go())
for chunk in stream:each_chunk() do
	io.write(chunk)
end




local port = arg[1] or 0 -- 0 means pick one at random

local http_server = require "http.server"
local http_headers = require "http.headers"

local function reply(myserver, stream) -- luacheck: ignore 212
	-- Read in headers
	local req_headers = assert(stream:get_headers())
	local req_method = req_headers:get ":method"

	-- Log request to stdout
	assert(io.stdout:write(string.format('[%s] "%s %s HTTP/%g"  "%s" "%s"\n',
		os.date("%d/%b/%Y:%H:%M:%S %z"),
		req_method or "",
		req_headers:get(":path") or "",
		stream.connection.version,
		req_headers:get("referer") or "-",
		req_headers:get("user-agent") or "-"
	)))

	-- Build response headers
	local res_headers = http_headers.new()
	res_headers:append(":status", "200")
	res_headers:append("content-type", "text/plain")
	-- Send headers to client; end the stream immediately if this was a HEAD request
	assert(stream:write_headers(res_headers, req_method == "HEAD"))
	if req_method ~= "HEAD" then
		-- Send body, ending the stream
		assert(stream:write_chunk("Hello world!\n", true))
	end
end

local myserver = assert(http_server.listen {
	host = "localhost";
	port = port;
	onstream = reply;
	onerror = function(myserver, context, op, err, errno) -- luacheck: ignore 212
		local msg = op .. " on " .. tostring(context) .. " failed"
		if err then
			msg = msg .. ": " .. tostring(err)
		end
		assert(io.stderr:write(msg, "\n"))
	end;
})

-- Manually call :listen() so that we are bound before calling :localname()
assert(myserver:listen())
do
	local bound_port = select(3, myserver:localname())
	assert(io.stderr:write(string.format("Now listening on port %d\n", bound_port)))
end
-- Start the main server loop
assert(myserver:loop())

f not DEVELOP then
    return
end

local fs = require 'bee.filesystem'
local luaDebugs = {}

for _, vscodePath in ipairs {'.vscode', '.vscode-insiders'} do
    local extensionPath = fs.path(os.getenv 'USERPROFILE' or '') / vscodePath / 'extensions'
    log.debug('Search extensions at:', extensionPath:string())
    if not fs.is_directory(extensionPath) then
        log.debug('Extension path is not a directory.')
        return
    end

    for path in extensionPath:list_directory() do
        if fs.is_directory(path) then
            local name = path:filename():string()
            if name:find('actboy168.lua-debug-', 1, true) then
                luaDebugs[#luaDebugs+1] = path:string()
            end
        end
    end
end

if #luaDebugs == 0 then
    log.debug('Cant find "actboy168.lua-debug"')
    return
end

local function getVer(filename)
    local a, b, c = filename:match('(%d+)%.(%d+)%.(%d+)$')
    if not a then
        return 0
    end
    return a * 1000000 + b * 1000 + c
end

table.sort(luaDebugs, function (a, b)
    return getVer(a) > getVer(b)
end)

local debugPath = luaDebugs[1]
local cpath = "/runtime/win64/lua54/?.dll"
local path  = "/script/?.lua"

local function tryDebugger()
    local entry = assert(package.searchpath('debugger', debugPath .. path))
    local root = debugPath
    local addr = ("127.0.0.1:%d"):format(DBGPORT)
    local dbg = loadfile(entry)(root)
    dbg:start(addr)
    log.debug('Debugger startup, listen port:', DBGPORT)
    log.debug('Debugger args:', addr, root, path, cpath)
    if DBGWAIT then
        dbg:event('wait')
    end
    return dbg
end

xpcall(tryDebugger, log.debug)


local currentPath = debug.getinfo(1, 'S').source:sub(2)
local rootPath = currentPath:gsub('[/\\]*[^/\\]-$', '')
loadfile(rootPath .. '\\platform.lua')('script-beta')
package.path  = package.path
      .. ';' .. rootPath .. '\\test-beta\\?.lua'
      .. ';' .. rootPath .. '\\test-beta\\?\\init.lua'
local fs = require 'bee.filesystem'
ROOT = fs.path(rootPath)
LANG = 'zh-CN'

collectgarbage 'generational'

log = require 'log'
log.init(ROOT, ROOT / 'log' / 'test.log')
log.debug('测试开始')
ac = {}

require 'utility'
--dofile((ROOT / 'build_package.lua'):string())

local function loadAllLibs()
    assert(require 'bee.filesystem')
    assert(require 'bee.subprocess')
    assert(require 'bee.thread')
    assert(require 'bee.socket')
    assert(require 'lni')
    assert(require 'lpeglabel')
end

local function main()
    debug.setcstacklimit(1000)
    require 'parser.guide'.debugMode = true
    local function test(name)
        local clock = os.clock()
        print(('测试[%s]...'):format(name))
        require(name)
        print(('测试[%s]用时[%.3f]'):format(name, os.clock() - clock))
    end

    local config = require 'config'
    config.config.runtime.version = 'Lua 5.4'
    config.config.intelliSense.searchDepth = 5

    test 'references'
    test 'definition'
    test 'type_inference'
    test 'diagnostics'
    test 'highlight'
    test 'rename'
    test 'hover'
    test 'completion'
    test 'signature'
    test 'document_symbol'
    test 'crossfile'
    test 'full'
    --test 'other'

    print('测试完成')
end

loadAllLibs()
main()

log.debug('测试完成')


local lm = require 'luamake'
local platform = require "bee.platform"

lm.arch = 'x64'

if lm.plat == "macos" then
    lm.flags = {
        "-mmacosx-version-min=10.13",
    }
end

lm:import '3rd/bee.lua/make.lua'

lm.rootdir = '3rd/'

lm:shared_library 'lni' {
    deps = platform.OS == "Windows" and "lua54" or "lua",
    sources = {
        'lni/src/main.cpp',
    },
    links = {
        platform.OS == "Linux" and "stdc++",
    },
    visibility = 'default',
}

lm:shared_library 'lpeglabel' {
    deps = platform.OS == "Windows" and "lua54" or "lua",
    sources = 'lpeglabel/*.c',
    visibility = 'default',
    defines = {
        'MAXRECLEVEL=1000',
    },
    ldflags = platform.OS == "Windows" and "/EXPORT:luaopen_lpeglabel",
}

if platform.OS == "Windows" then
    lm:executable 'rcedit' {
        sources = 'rcedit/src/*.cc',
        defines = {
            '_SILENCE_CXX17_CODECVT_HEADER_DEPRECATION_WARNING'
        },
        flags = {
            '/wd4477',
            '/wd4244',
            '/wd4267',
        }
    }
end

lm:build 'install' {
    '$luamake', 'lua', 'make/install.lua', lm.plat,
    deps = {
        'lua',
        'lni',
        'lpeglabel',
        'bee',
        'bootstrap',
        platform.OS == "Windows" and "rcedit"
    }
}

lm:build 'unittest' {
    '$luamake', 'lua', 'make/unittest.lua', lm.plat,
    deps = {
        'install',
    }
}

lm:default {
    'install',
    'test',
    'unittest',
}

local currentPath = debug.getinfo(1, 'S').source:sub(2)
local rootPath = currentPath:gsub('[/\\]*[^/\\]-$', '')
loadfile((rootPath == '' and '.' or rootPath) .. '/platform.lua')('script')
local fs = require 'bee.filesystem'
ROOT = fs.current_path() / rootPath
LANG = LANG or 'en-US'

--collectgarbage('generational')
collectgarbage("setpause", 100)
collectgarbage("setstepmul", 1000)

log = require 'log'
log.init(ROOT, ROOT / 'log' / 'service.log')
log.info('Lua Lsp startup, root: ', ROOT)
log.debug('ROOT:', ROOT:string())
ac = {}

xpcall(dofile, log.debug, rootPath .. '/debugger.lua')
require 'utility'
local service = require 'service'
local session = service()

session:listen()


local script = ...

local function findExePath()
    local n = 0
    while arg[n-1] do
        n = n - 1
    end
    return arg[n]
end

local exePath = findExePath()
local exeDir  = exePath:match('(.+)[/\\][%w_.-]+$')
local dll     = package.cpath:match '[/\\]%?%.([a-z]+)'
package.cpath = ('%s/?.%s'):format(exeDir, dll)
local ok, err = package.loadlib(exeDir..'/bee.'..dll, 'luaopen_bee_platform')
if not ok then
    error(([[It doesn't seem to support your OS, please build it in your OS, see https://github.com/sumneko/vscode-lua/wiki/Build
errorMsg: %s
exePath:  %s
exeDir:   %s
dll:      %s
cpath:    %s
]]):format(
    err,
    exePath,
    exeDir,
    dll,
    package.cpath
))
end

local fs = require 'bee.filesystem'
local rootPath = fs.path(exePath):parent_path():parent_path():remove_filename():string()
if dll == '.dll' then
    rootPath = rootPath:gsub('/', '\\')
    package.path  = rootPath .. script .. '\\?.lua'
          .. ';' .. rootPath .. script .. '\\?\\init.lua'
else
    rootPath = rootPath:gsub('\\', '/')
    package.path  = rootPath .. script .. '/?.lua'
          .. ';' .. rootPath .. script .. '/?/init.lua'
end

local fs        = require 'bee.filesystem'
local rpc       = require 'rpc'
local config    = require 'config'
local glob      = require 'glob'
local platform  = require 'bee.platform'
local sandbox   = require 'sandbox'

local Plugins

local function showError(msg)
    local traceback = log.error(msg)
    rpc:notify('window/showMessage', {
        type = 3,
        message = traceback,
    })
    return traceback
end

local function showWarn(msg)
    log.warn(msg)
    rpc:notify('window/showMessage', {
        type = 3,
        message = msg,
    })
    return msg
end

local function scan(path, callback)
    if fs.is_directory(path) then
        for p in path:list_directory() do
            scan(p, callback)
        end
    else
        callback(path)
    end
end

local function loadPluginFrom(path, root)
    log.info('Load plugin from:', path:string())
    local env = setmetatable({}, { __index = _G })
    sandbox(path:filename():string(), root:string(), io.open, package.loaded, env)
    Plugins[#Plugins+1] = env
end

local function load(workspace)
    Plugins = nil

    if not config.config.plugin.enable then
        return
    end
    local suc, path = xpcall(fs.path, showWarn, config.config.plugin.path)
    if not suc then
        return
    end

    Plugins = {}
    local pluginPath
    if workspace then
        pluginPath = fs.absolute(workspace.root / path)
    else
        pluginPath = fs.absolute(path)
    end
    if not fs.is_directory(pluginPath) then
        pluginPath = pluginPath:parent_path()
    end

    local pattern = {config.config.plugin.path}
    local options = {
        ignoreCase = platform.OS == 'Windows'
    }
    local parser = glob.glob(pattern, options)

    scan(pluginPath:parent_path(), function (filePath)
        if parser(filePath:string()) then
            loadPluginFrom(filePath, pluginPath)
        end
    end)
end

local function call(name, ...)
    if not Plugins then
        return nil
    end
    for _, plugin in ipairs(Plugins) do
        if type(plugin[name]) == 'function' then
            local suc, res = xpcall(plugin[name], showError, ...)
            if suc and res ~= nil then
                return res
            end
        end
    end
    return nil
end

return {
    load = load,
    call = call,
}

local currentPath = debug.getinfo(1, 'S').source:sub(2)
local rootPath = currentPath:gsub('[^/\\]-$', '')
if rootPath == '' then
    rootPath = './'
end
dofile(rootPath .. 'platform.lua')
local fs = require 'bee.filesystem'
local subprocess = require 'bee.subprocess'
local platform = require 'bee.platform'
ROOT = fs.absolute(fs.path(rootPath):parent_path())
EXTENSION = ROOT:parent_path()

require 'utility'
local json = require 'json'

local function loadPackage()
    local buf = io.load(EXTENSION / 'package.json')
    if not buf then
        error(ROOT:string() .. '|' .. EXTENSION:string())
    end
    local package = json.decode(buf)
    return package.version
end

local function updateNodeModules(out, postinstall)
    local current = fs.current_path()
    fs.current_path(out)
    local cmd = io.popen(postinstall)
    for line in cmd:lines 'l' do
        print(line)
    end
    local suc = cmd:close()
    if not suc then
        error('更新NodeModules失败！')
    end
    fs.current_path(current)
end

local function createDirectory(version)
    local out = EXTENSION / 'publish' / version
    fs.create_directories(out)
    return out
end

local function copyFiles(root, out)
    return function (dirs)
        local count = 0
        local function copy(relative, mode)
            local source = root / relative
            local target = out / relative
            if not fs.exists(source) then
                return
            end
            if fs.is_directory(source) then
                fs.create_directory(target)
                if mode == true then
                    for path in source:list_directory() do
                        copy(relative / path:filename(), true)
                    end
                else
                    for name, v in pairs(mode) do
                        copy(relative / name, v)
                    end
                end
            else
                fs.copy_file(source, target)
                count = count + 1
            end
        end

        copy(fs.path '', dirs)
        return count
    end
end

local function runTest(root)
    local ext = platform.OS == 'Windows' and '.exe' or ''
    local exe = root / platform.OS / 'bin' / 'lua-language-server' .. ext
    local test = root / 'test.lua'
    local lua = subprocess.spawn {
        exe,
        test,
        '-E',
        cwd = root,
        stdout = true,
        stderr = true,
    }
    for line in lua.stdout:lines 'l' do
        print(line)
    end
    lua:wait()
    local err = lua.stderr:read 'a'
    if err ~= '' then
        error(err)
    end
end

local function removeFiles(out)
    return function (dirs)
        local function remove(relative, mode)
            local target = out / relative
            if not fs.exists(target) then
                return
            end
            if fs.is_directory(target) then
                if mode == true then
                    for path in target:list_directory() do
                        remove(relative / path:filename(), true)
                    end
                    fs.remove(target)
                else
                    for name, v in pairs(mode) do
                        remove(relative / name, v)
                    end
                end
            else
                fs.remove(target)
            end
        end

        remove(fs.path '', dirs)
    end
end

local version = loadPackage()
print('版本号为：' .. version)

local out = createDirectory(version)

print('清理目录...')
removeFiles(out)(true)

print('开始复制文件...')
local count = copyFiles(EXTENSION , out) {
    ['client'] = {
        ['node_modules']      = true,
        ['out']               = true,
        ['package-lock.json'] = true,
        ['package.json']      = true,
        ['tsconfig.json']     = true,
    },
    ['server'] = {
        ['Windows']           = true,
        ['macOS']             = true,
        ['Linux']             = true,
        ['libs']              = true,
        ['locale']            = true,
        ['src']               = true,
        ['test']              = true,
        ['main.lua']          = true,
        ['platform.lua']      = true,
        ['test.lua']          = true,
        ['build_package.lua'] = true,
    },
    ['images'] = {
        ['logo.png'] = true,
    },
    ['syntaxes']               = true,
    ['package-lock.json']      = true,
    ['package.json']           = true,
    ['README.md']              = true,
    ['tsconfig.json']          = true,
    ['package.nls.json']       = true,
    ['package.nls.zh-cn.json'] = true,
}
print(('复制了[%d]个文件'):format(count))

print('开始测试...')
runTest(out / 'server')

print('删除多余文件...')
removeFiles(out) {
    ['server'] = {
        ['log']               = true,
        ['test']              = true,
        ['test.lua']          = true,
        ['build_package.lua'] = true,
    },
}

local path = EXTENSION / 'publish' / 'lua'
print('清理发布目录...')
removeFiles(path)(true)

print('复制到发布目录...')
local count = copyFiles(out, path)(true)
print(('复制了[%d]个文件'):format(count))

print('完成')


local function standard(loaded, env)
    local r = env or {}
    for _, s in ipairs {
        --'package',
        'coroutine',
        'table',
        --'io',
        'os',
        'string',
        'math',
        'utf8',
        'debug',
    } do
        r[s] = _G[s]
        loaded[s] = _G[s]
    end
    for _, s in ipairs {
        'assert',
        'collectgarbage',
        --'dofile',
        'error',
        'getmetatable',
        'ipairs',
        --'loadfile',
        'load',
        'next',
        'pairs',
        'pcall',
        'print',
        'rawequal',
        'rawlen',
        'rawget',
        'rawset',
        'select',
        'setmetatable',
        'tonumber',
        'tostring',
        'type',
        'xpcall',
        '_VERSION',
        --'require',
    } do
        r[s] = _G[s]
    end
    return r
end

local function sandbox_env(loadlua, openfile, loaded, env)
    local _LOADED = loaded or {}
    local _E = standard(_LOADED, env)
    local _PRELOAD = {}

    _E.io = {
        open = openfile,
    }

    local function searchpath(name, path)
        local err = ''
        name = string.gsub(name, '%.', '/')
        for c in string.gmatch(path, '[^;]+') do
            local filename = string.gsub(c, '%?', name)
            local f = openfile(filename)
            if f then
                f:close()
                return filename
            end
            err = err .. ("\n\tno file '%s'"):format(filename)
        end
        return nil, err
    end

    local function searcher_preload(name)
        assert(type(_PRELOAD) == "table", "'package.preload' must be a table")
        if _PRELOAD[name] == nil then
            return ("\n\tno field package.preload['%s']"):format(name)
        end
        return _PRELOAD[name]
    end

    local function searcher_lua(name)
        assert(type(_E.package.path) == "string", "'package.path' must be a string")
        local filename, err = searchpath(name, _E.package.path)
        if not filename then
            return err
        end
        local f, err = loadlua(filename)
        if not f then
            error(("error loading module '%s' from file '%s':\n\t%s"):format(name, filename, err))
        end
        return f, filename
    end

    local function require_load(name)
        local msg = ''
        local _SEARCHERS = _E.package.searchers
        assert(type(_SEARCHERS) == "table", "'package.searchers' must be a table")
        for _, searcher in ipairs(_SEARCHERS) do
            local f, extra = searcher(name)
            if type(f) == 'function' then
                return f, extra
            elseif type(f) == 'string' then
                msg = msg .. f
            end
        end
        error(("module '%s' not found:%s"):format(name, msg))
    end

    _E.require = function(name)
        assert(type(name) == "string", ("bad argument #1 to 'require' (string expected, got %s)"):format(type(name)))
        local p = _LOADED[name]
        if p ~= nil then
            return p
        end
        local init, extra = require_load(name)
        if debug.getupvalue(init, 1) == '_ENV' then
            debug.setupvalue(init, 1, _E)
        end
        local res = init(name, extra)
        if res ~= nil then
            _LOADED[name] = res
        end
        if _LOADED[name] == nil then
            _LOADED[name] = true
        end
        return _LOADED[name]
    end
    _E.package = {
        config = [[
            \
            ;
            ?
            !
            -
        ]],
        loaded = _LOADED,
        path = '?.lua',
        preload = _PRELOAD,
        searchers = { searcher_preload, searcher_lua },
        searchpath = searchpath
    }
    return _E
end

return function(name, root, io_open, loaded, env)
    if not root:sub(-1):find '[/\\]' then
        root = root .. '/'
    end
    local function openfile(name, mode)
        return io_open(root .. name, mode)
    end
    local function loadlua(name)
        local f = openfile(name, 'r')
        if f then
            local str = f:read 'a'
            f:close()
            return load(str, '@' .. root .. name)
        end
    end
    local init = loadlua(name)
    if not init then
        return
    end
    if debug.getupvalue(init, 1) == '_ENV' then
        debug.setupvalue(init, 1, sandbox_env(loadlua, openfile, loaded, env))
    end
    return init()
end

local subprocess = require 'bee.subprocess'
local method     = require 'method'
local thread     = require 'bee.thread'
local async      = require 'async'
local rpc        = require 'rpc'
local parser     = require 'parser'
local core       = require 'core'
local lang       = require 'language'
local updateTimer= require 'timer'
local buildVM    = require 'vm'
local sourceMgr  = require 'vm.source'
local localMgr   = require 'vm.local'
local valueMgr   = require 'vm.value'
local chainMgr   = require 'vm.chain'
local functionMgr= require 'vm.function'
local listMgr    = require 'vm.list'
local emmyMgr    = require 'emmy.manager'
local config     = require 'config'
local task       = require 'task'
local files      = require 'files'
local uric       = require 'uri'
local capability = require 'capability'
local plugin     = require 'plugin'
local workspace  = require 'workspace'
local fn         = require 'filename'
local json       = require 'json'

local ErrorCodes = {
    -- Defined by JSON RPC
    ParseError           = -32700,
    InvalidRequest       = -32600,
    MethodNotFound       = -32601,
    InvalidParams        = -32602,
    InternalError        = -32603,
    serverErrorStart     = -32099,
    serverErrorEnd       = -32000,
    ServerNotInitialized = -32002,
    UnknownErrorCode     = -32001,

    -- Defined by the protocol.
    RequestCancelled     = -32800,
}

local CachedVM = setmetatable({}, {__mode = 'kv'})

---@class LSP
local mt = {}
mt.__index = mt
---@type files
mt._files = nil

function mt:_callMethod(name, params)
    local optional
    if name:sub(1, 2) == '$/' then
        name = name:sub(3)
        optional = true
    end
    local f = method[name]
    if f then
        local clock = os.clock()
        local suc, res = xpcall(f, debug.traceback, self, params)
        local passed = os.clock() - clock
        if passed > 0.2 then
            log.debug(('Task [%s] takes [%.3f]sec.'):format(name, passed))
        end
        if suc then
            return res
        else
            local ok, r = pcall(table.dump, params)
            local dump = ok and r or '<Cyclic table>'
            log.debug(('Task [%s] failed, params: %s'):format(
                name, dump
            ))
            log.error(res)
            if res:find 'not enough memory' then
                self:restartDueToMemoryLeak()
            end
            return nil, {
                code = ErrorCodes.InternalError,
                message = r .. '\n' .. res,
            }
        end
    end
    if optional then
        return nil
    else
        return nil, {
            code = ErrorCodes.MethodNotFound,
            message = 'MethodNotFound',
        }
    end
end

function mt:responseProto(id, response, err)
    rpc:response(id, {
        error  = err and err or nil,
        result = response and response or json.null,
    })
end

function mt:_doProto(proto)
    local id     = proto.id
    local name   = proto.method
    local params = proto.params
    local response, err = self:_callMethod(name, params)
    if not id then
        return
    end
    if type(response) == 'function' then
        response(function (final)
            self:responseProto(id, final)
        end)
    else
        self:responseProto(id, response, err)
    end
end

function mt:clearDiagnostics(uri)
    rpc:notify('textDocument/publishDiagnostics', {
        uri = uri,
        diagnostics = {},
    })
    self._needDiagnostics[uri] = nil
    log.debug('clearDiagnostics', uri)
end

---@param uri uri
---@param compiled table
---@param mode string
---@return boolean
function mt:needCompile(uri, compiled, mode)
    self._needDiagnostics[uri] = true
    if self._needCompile[uri] then
        return false
    end
    if not compiled then
        compiled = {}
    end
    if compiled[uri] then
        return false
    end
    self._needCompile[uri] = compiled
    if mode == 'child' then
        table.insert(self._needCompile, uri)
    else
        table.insert(self._needCompile, 1, uri)
    end
    return true
end

function mt:isNeedCompile(uri)
    return self._needCompile[uri]
end

function mt:isWaitingCompile()
    if self._needCompile[1] then
        return true
    else
        return false
    end
end

---@param uri uri
---@param version integer
---@param text string
function mt:saveText(uri, version, text)
    self._lastLoadedVM = uri
    self._files:save(uri, text, version)
    self:needCompile(uri)
end

---@param uri uri
function mt:isDeadText(uri)
    return self._files:isDead(uri)
end

---@param name string
---@param uri uri
function mt:addWorkspace(name, uri)
    log.info("Add workspace", name, uri)
    for _, ws in ipairs(self.workspaces) do
        if ws.name == name and ws.uri == uri then
            return
        end
    end
    local ws = workspace(self, name)
    ws:init(uri)
    table.insert(self.workspaces, ws)
    return ws
end

---@param name string
---@param uri uri
function mt:removeWorkspace(name, uri)
    log.info("Remove workspace", name, uri)
    local index
    for i, ws in ipairs(self.workspaces) do
        if ws.name == name and ws.uri == uri then
            index = i
            break
        end
    end
    if index then
        table.remove(self.workspaces, index)
    end
end

---@param uri uri
---@return Workspace
function mt:findWorkspaceFor(uri)
    if #self.workspaces == 0 then
        return nil
    end
    local path = uric.decode(uri)
    if not path then
        return nil
    end
    for _, ws in ipairs(self.workspaces) do
        if not ws:relativePathByUri(uri):string():match("^%.%.") then
            return ws
        end
    end
    log.info("No workspace for", uri)
    return nil
end

---@param uri uri
---@return boolean
function mt:isLua(uri)
    if fn.isLuaFile(uric.decode(uri)) then
        return true
    end
    return false
end

function mt:isIgnored(uri)
    local ws = self:findWorkspaceFor(uri)
    if not ws then
        return true
    end
    if not ws.gitignore then
        return true
    end
    local path = ws:relativePathByUri(uri)
    if not path then
        return true
    end
    if ws.gitignore(path:string()) then
        return true
    end
    return false
end

---@param uri uri
---@param version integer
---@param text string
function mt:open(uri, version, text)
    if not self:isLua(uri) then
        return
    end
    self:saveText(uri, version, text)
    self._files:open(uri, text)
end

---@param uri uri
function mt:close(uri)
    self._files:close(uri)
    if self._files:isLibrary(uri) then
        return
    end
    if not self:isLua(uri) or self:isIgnored(uri) then
        self:removeText(uri)
    end
end

---@param uri uri
---@return boolean
function mt:isOpen(uri)
    return self._files:isOpen(uri)
end

function mt:eachOpened()
    return self._files:eachOpened()
end

function mt:eachFile()
    return self._files:eachFile()
end

---@param uri uri
---@param path path
---@param text string
function mt:checkReadFile(uri, path, text)
    if not text then
        log.debug('No file: ', path)
        return false
    end
    local size = #text / 1000.0
    if size > config.config.workspace.preloadFileSize then
        log.info(('Skip large file, size: %.3f KB: %s'):format(size, uri))
        return false
    end
    if self:getCachedFileCount() >= config.config.workspace.maxPreload then
        if not self._hasShowHitMaxPreload then
            self._hasShowHitMaxPreload = true
            rpc:notify('window/showMessage', {
                type = 3,
                message = lang.script('MWS_MAX_PRELOAD', config.config.workspace.maxPreload),
            })
        end
        return false
    end
    return true
end

---@param ws Workspace
---@param uri uri
---@param path path
---@param buf string
---@param compiled table
function mt:readText(ws, uri, path, buf, compiled)
    if self:findWorkspaceFor(uri) ~= ws then
        log.debug('Read failed due to different workspace:', uri, debug.traceback())
        return
    end
    if self._files:get(uri) then
        log.debug('Read failed due to duplicate:', uri)
        return
    end
    if not self:isLua(uri) then
        log.debug('Read failed due to not lua:', uri)
        return
    end
    if not self._files:isOpen(uri) and self:isIgnored(uri) then
        log.debug('Read failed due to ignored:', uri)
        return
    end
    local text = buf or io.load(path)
    if not self._files:isOpen(uri) and not self:checkReadFile(uri, path, text) then
        log.debug('Read failed due to check failed:', uri)
        return
    end
    self._files:save(uri, text, 0)
    self:needCompile(uri, compiled)
end

---@param ws Workspace
---@param uri uri
---@param path path
---@param buf string
---@param compiled table
function mt:readLibrary(ws, uri, path, buf, compiled)
    if not self:isLua(uri) then
        return
    end
    if not self:checkReadFile(uri, path, buf) then
        return
    end
    self._files:save(uri, buf, 0, ws)
    self._files:setLibrary(uri)
    self:needCompile(uri, compiled)
    self:clearDiagnostics(uri)
end

---@param uri uri
function mt:removeText(uri)
    self._files:remove(uri)
    self:compileVM(uri)
    self:clearDiagnostics(uri)
end

function mt:getCachedFileCount()
    return self._files:count()
end

function mt:reCompile()
    if self.global then
        self.global:remove()
    end
    if self.chain then
        self.chain:remove()
    end
    if self.emmy then
        self.emmy:remove()
    end

    local compiled = {}
    self._files:clearVM()

    for _, obj in pairs(listMgr.list) do
        if obj.type == 'source' or obj.type == 'function' then
            obj:kill()
        end
    end

    self.global = core.global(self)
    self.chain  = chainMgr()
    self.emmy   = emmyMgr()
    self.globalValue = nil
    if self._compileTask then
        self._compileTask:remove()
    end
    self._needCompile = {}
    local n = 0
    for uri in self._files:eachFile() do
        self:needCompile(uri, compiled)
        n = n + 1
    end
    log.debug('reCompile:', n, self._files:count())

    self:_testMemory('skip')
end

function mt:reDiagnostic()
    for uri in self._files:eachFile() do
        self:clearDiagnostics(uri)
        self._needDiagnostics[uri] = true
    end
end

function mt:clearAllFiles()
    for uri in self._files:eachFile() do
        self:clearDiagnostics(uri)
    end
    self._files:clear()
end

---@param uri uri
function mt:loadVM(uri)
    local file = self._files:get(uri)
    if not file then
        return nil
    end
    if uri ~= self._lastLoadedVM then
        self:needCompile(uri)
    end
    if self._compileTask
        and not self._compileTask:isRemoved()
        and self._compileTask:get 'uri' == uri
    then
        self._compileTask:fastForward()
    else
        self:compileVM(uri)
    end
    if file:getVM() then
        self._lastLoadedVM = uri
    end
    return file:getVM(), file:getLines()
end

function mt:_markCompiled(uri, compiled)
    local newCompiled = self._needCompile[uri]
    if newCompiled then
        newCompiled[uri] = true
        self._needCompile[uri] = nil
    end
    for i, u in ipairs(self._needCompile) do
        if u == uri then
            table.remove(self._needCompile, i)
            break
        end
    end
    if newCompiled == compiled then
        return compiled
    end
    if not compiled then
        compiled = {}
    end
    for k, v in pairs(newCompiled) do
        compiled[k] = v
    end
    return compiled
end

---@param file file
---@return table
function mt:compileAst(file)
    local ast, err, comments = parser:parse(file:getText(), 'lua', config.config.runtime.version)
    file.comments = comments
    if ast then
        file:setAstErr(err)
    else
        if type(err) == 'string' then
            local message = lang.script('PARSER_CRASH', err)
            log.debug(message)
            rpc:notify('window/showMessage', {
                type = 3,
                message = lang.script('PARSER_CRASH', err:match '%.lua%:%d+%:(.+)' or err),
            })
            if message:find 'not enough memory' then
                self:restartDueToMemoryLeak()
            end
        end
    end
    return ast
end

---@param file file
---@param uri uri
function mt:_clearChainNode(file, uri)
    for pUri in file:eachParent() do
        local parent = self._files:get(pUri)
        if parent then
            parent:removeChild(uri)
        end
    end
end

---@param file file
---@param compiled table
function mt:_compileChain(file, compiled)
    if not compiled then
        compiled = {}
    end
    for uri in file:eachChild() do
        self:needCompile(uri, compiled, 'child')
    end
    for uri in file:eachParent() do
        self:needCompile(uri, compiled, 'parent')
    end
end

function mt:_compileGlobal(compiled)
    local uris = self.global:getAllUris()
    for _, uri in ipairs(uris) do
        self:needCompile(uri, compiled, 'global')
    end
end

function mt:_clearGlobal(uri)
    self.global:clearGlobal(uri)
end

function mt:_hasSetGlobal(uri)
    return self.global:hasSetGlobal(uri)
end

---@param uri uri
function mt:compileVM(uri)
    local file = self._files:get(uri)
    if not file then
        self:_markCompiled(uri)
        return nil
    end
    local compiled = self._needCompile[uri]
    if not compiled then
        return nil
    end
    file:removeVM()

    local clock = os.clock()
    local ast = self:compileAst(file)
    local version = file:getVersion()
    local astCost = os.clock() - clock
    if astCost > 0.1 then
        log.warn(('Compile Ast[%s] takes [%.3f] sec, size [%.3f]kb'):format(uri, astCost, #file:getText() / 1000))
    end
    file:clearOldText()

    self:_clearChainNode(file, uri)
    self:_clearGlobal(uri)

    local clock = os.clock()
    local vm, err = buildVM(ast, self, uri, file:getText())
    if vm then
        CachedVM[vm] = true
    end
    if self:isDeadText(uri)
        or file:isRemoved()
        or version ~= file:getVersion()
    then
        if vm then
            vm:remove()
        end
        return nil
    end
    if self._needCompile[uri] then
        self:_markCompiled(uri, compiled)
        self._needDiagnostics[uri] = true
    else
        if vm then
            vm:remove()
        end
        return nil
    end
    file:saveVM(vm, version, os.clock() - clock)

    local clock = os.clock()
    local lines = parser:lines(file:getText(), 'utf8')
    local lineCost = os.clock() - clock
    file:saveLines(lines, lineCost)

    if file:getVMCost() > 0.2 then
        log.debug(('Compile VM[%s] takes: %.3f sec'):format(uri, file:getVMCost()))
    end
    if not vm then
        error(err)
    end

    self:_compileChain(file, compiled)
    if self:_hasSetGlobal(uri) then
        self:_compileGlobal(compiled)
    end

    return file
end

---@param uri uri
function mt:doDiagnostics(uri)
    if not config.config.diagnostics.enable then
        self._needDiagnostics[uri] = nil
        return
    end
    if not self._needDiagnostics[uri] then
        return
    end
    local name = 'textDocument/publishDiagnostics'
    local file = self._files:get(uri)
    if not file
        or file:isRemoved()
        or not file:getVM()
        or file:getVM():isRemoved()
        or self._files:isLibrary(uri)
    then
        self._needDiagnostics[uri] = nil
        self:clearDiagnostics(uri)
        return
    end
    local data = {
        uri   = uri,
        vm    = file:getVM(),
        lines = file:getLines(),
        version = file:getVM():getVersion(),
    }
    local res = self:_callMethod(name, data)
    if self:isDeadText(uri) then
        return
    end
    if file:getVM():getVersion() ~= data.version then
        return
    end
    if self._needDiagnostics[uri] then
        self._needDiagnostics[uri] = nil
    else
        return
    end
    if res then
        rpc:notify(name, {
            uri = uri,
            diagnostics = res,
        })
    else
        self:clearDiagnostics(uri)
    end
end

---@param uri uri
---@return file
function mt:getFile(uri)
    return self._files:get(uri)
end

---@param uri uri
---@return VM
---@return table
---@return string
function mt:getVM(uri)
    local file = self._files:get(uri)
    if not file then
        return nil
    end
    return file:getVM(), file:getLines(), file:getText()
end

---@param uri uri
---@return string
---@return string
function mt:getText(uri)
    local file = self._files:get(uri)
    if not file then
        return nil
    end
    return file:getText(), file:getOldText()
end

function mt:getComments(uri)
    local file = self._files:get(uri)
    if not file then
        return nil
    end
    return file:getComments()
end

---@param uri uri
---@return table
function mt:getAstErrors(uri)
    local file = self._files:get(uri)
    if not file then
        return nil
    end
    return file:getAstErr()
end

---@param child uri
---@param parent uri
function mt:compileChain(child, parent)
    local parentFile = self._files:get(parent)
    local childFile = self._files:get(child)

    if not parentFile or not childFile then
        return
    end
    if parentFile == childFile then
        return
    end

    parentFile:addChild(child)
    childFile:addParent(parent)
end

function mt:checkWorkSpaceComplete()
    if self._hasCheckedWorkSpaceComplete then
        return
    end
    self._hasCheckedWorkSpaceComplete = true
    for _, ws in ipairs(self.workspaces) do
        if ws:isComplete() then
            return
        end
    end
    self._needShowComplete = true
    rpc:notify('window/showMessage', {
        type = 3,
        message = lang.script.MWS_NOT_COMPLETE,
    })
end

function mt:_createCompileTask()
    if not self:isWaitingCompile() and not next(self._needDiagnostics) then
        if self._needShowComplete then
            self._needShowComplete = nil
            rpc:notify('window/showMessage', {
                type = 3,
                message = lang.script.MWS_COMPLETE,
            })
        end
    end
    self._compileTask = task(function ()
        self:doDiagnostics(self._lastLoadedVM)
        local uri = self._needCompile[1]
        if uri then
            self._compileTask:set('uri', uri)
            pcall(function () self:compileVM(uri) end)
        else
            uri = next(self._needDiagnostics)
            if uri then
                self:doDiagnostics(uri)
            end
        end
    end)
end

function mt:_doCompileTask()
    if not self._compileTask or self._compileTask:isRemoved() then
        self:_createCompileTask()
    end
    while true do
        local res = self._compileTask:step()
        if res == 'stop' then
            self._compileTask:remove()
            break
        end
        if self._compileTask:isRemoved() then
            break
        end
    end
    self:_loadProto()
end

function mt:_loadProto()
    while true do
        local ok, protoStream = self._proto:pop()
        if not ok then
            break
        end
        local null = json.null
        json.null = nil
        local suc, proto = xpcall(json.decode, log.error, protoStream)
        json.null = null
        if not suc then
            break
        end
        if proto.method then
            self:_doProto(proto)
        else
            rpc:recieve(proto)
        end
    end
end

function mt:restartDueToMemoryLeak()
    rpc:requestWait('window/showMessageRequest', {
        type = 3,
        message = lang.script('DEBUG_MEMORY_LEAK', '[Lua]'),
        actions = {
            {
                title = lang.script.DEBUG_RESTART_NOW,
            }
        }
    }, function ()
        os.exit(true)
    end)
    ac.wait(5, function ()
        os.exit(true)
    end)
end

function mt:reScanFiles()
    log.debug('reScanFiles')
    self:clearAllFiles()
    for _, ws in ipairs(self.workspaces) do
        ws:scanFiles()
    end
    for uri, text in self:eachOpened() do
        self:open(uri, 0, text)
    end
end

function mt:onUpdateConfig(updated, other)
    local oldConfig = table.deepCopy(config.config)
    local oldOther  = table.deepCopy(config.other)
    config:setConfig(updated, other)
    local newConfig = config.config
    local newOther  = config.other
    if not table.equal(oldConfig.runtime, newConfig.runtime) then
        local library = require 'core.library'
        library.reload()
        self:reCompile()
    end
    if not table.equal(oldConfig.diagnostics, newConfig.diagnostics) then
        log.debug('reDiagnostic')
        self:reDiagnostic()
    end
    if newConfig.completion.enable then
        capability.completion.enable(self)
    else
        capability.completion.disable(self)
    end
    if newConfig.color.mode == 'Semantic' then
        capability.semantic.enable(self)
    else
        capability.semantic.disable()
    end
    if not table.equal(oldConfig.plugin, newConfig.plugin) then
        for _, ws in ipairs(self.workspaces) do
            plugin.load(ws)
        end
    end
    if not table.equal(oldConfig.workspace, newConfig.workspace)
    or not table.equal(oldConfig.plugin, newConfig.plugin)
    or not table.equal(oldOther.associations, newOther.associations)
    or not table.equal(oldOther.exclude, newOther.exclude)
    then
        self:reScanFiles()
    end
end

function mt:_testMemory(skipDead)
    local clock = os.clock()
    collectgarbage()
    log.debug('collectgarbage: ', ('%.3f'):format(os.clock() - clock))

    local clock = os.clock()
    local cachedVM = 0
    local cachedSource = 0
    local cachedFunction = 0
    for _, file in self._files:eachFile() do
        local vm = file:getVM()
        if vm and not vm:isRemoved() then
            cachedVM = cachedVM + 1
            cachedSource = cachedSource + #vm.sources
            cachedFunction = cachedFunction + #vm.funcs
        end
    end
    local aliveVM = 0
    local deadVM = 0
    for vm in pairs(CachedVM) do
        if vm:isRemoved() then
            deadVM = deadVM + 1
        else
            aliveVM = aliveVM + 1
        end
    end

    local alivedSource = 0
    local deadSource = 0
    for _, id in pairs(sourceMgr.watch) do
        if listMgr.get(id) then
            alivedSource = alivedSource + 1
        else
            deadSource = deadSource + 1
        end
    end

    local alivedFunction = 0
    local deadFunction = 0
    for _, id in pairs(functionMgr.watch) do
        if listMgr.get(id) then
            alivedFunction = alivedFunction + 1
        else
            deadFunction = deadFunction + 1
        end
    end

    local totalLocal = 0
    for _ in pairs(localMgr.watch) do
        totalLocal = totalLocal + 1
    end

    local totalValue = 0
    local deadValue = 0
    for value in pairs(valueMgr.watch) do
        totalValue = totalValue + 1
        if not value:getSource() then
            deadValue = deadValue + 1
        end
    end

    local totalEmmy = self.emmy:count()

    local mem = collectgarbage 'count'
    local threadInfo = async.info
    local threadBuf = {}
    for i, count in ipairs(threadInfo) do
        if count then
            threadBuf[i] = ('#%03d Mem:  [%.3f]kb'):format(i, count)
        else
            threadBuf[i] = ('#%03d Mem:  <Unknown>'):format(i)
        end
    end

    log.debug(('\n\z
    State\n\z
    Main Mem:  [%.3f]kb\n\z
    %s\n\z
-------------------\n\z
    CachedVM:  [%d]\n\z
    AlivedVM:  [%d]\n\z
    DeadVM:    [%d]\n\z
-------------------\n\z
    CachedSrc: [%d]\n\z
    AlivedSrc: [%d]\n\z
    DeadSrc:   [%d]\n\z
-------------------\n\z
    CachedFunc:[%d]\n\z
    AlivedFunc:[%d]\n\z
    DeadFunc:  [%d]\n\z
-------------------\n\z
    TotalVal:  [%d]\n\z
    DeadVal:   [%d]\n\z
-------------------\n\z
    TotalLoc:  [%d]\n\z
    TotalEmmy: [%d]\n\z'):format(
        mem,
        table.concat(threadBuf, '\n'),

        cachedVM,
        aliveVM,
        deadVM,

        cachedSource,
        alivedSource,
        deadSource,

        cachedFunction,
        alivedFunction,
        deadFunction,

        totalValue,
        deadValue,
        totalLocal,
        totalEmmy
    ))
    log.debug('test memory: ', ('%.3f'):format(os.clock() - clock))

    -- TODO
    --if deadValue / totalValue >= 0.5 and not skipDead then
    --    self:_testFindDeadValues()
    --end
end

function mt:_testFindDeadValues()
    if self._testHasFoundDeadValues then
        return
    end
    self._testHasFoundDeadValues = true

    log.debug('Start find dead values, may takes few seconds...')

    local mark = {}
    local stack = {}
    local count = 0
    local clock = os.clock()
    local function push(info)
        stack[#stack+1] = info
    end
    local function pop()
        stack[#stack] = nil
    end
    local function showStack(uri)
        count = count + 1
        log.debug(uri, table.concat(stack, '->'))
    end
    local function scan(name, tbl)
        if count > 100 or os.clock() - clock > 5.0 then
            return
        end
        if type(tbl) ~= 'table' then
            return
        end
        if mark[tbl] then
            return
        end
        mark[tbl] = true
        if tbl.type then
            push(('%s<%s>'):format(name, tbl.type))
        else
            push(name)
        end
        if tbl.type == 'value' then
            if not tbl:getSource() then
                showStack(tbl.uri)
            end
        elseif tbl.type == 'files' then
            for k, v in tbl:eachFile() do
                scan(k, v)
            end
        else
            for k, v in pairs(tbl) do
                scan(k, v)
            end
        end
        pop()
    end
    scan('root', self._files)
    log.debug('Finish...')
end

function mt:onTick()
    self:_loadProto()
    self:_doCompileTask()
    if (os.clock() - self._clock >= 60 and not self:isWaitingCompile())
    or (os.clock() - self._clock >= 300)
    then
        self._clock = os.clock()
        self:_testMemory()
    end
end

function mt:listen()
    subprocess.filemode(io.stdin, 'b')
    subprocess.filemode(io.stdout, 'b')
    io.stdin:setvbuf 'no'
    io.stdout:setvbuf 'no'

    local _, out = async.run 'proto'
    self._proto = out

    local timerClock = 0.0
    while true do
        local startClock = os.clock()
        async.onTick()
        self:onTick()

        local delta = os.clock() - timerClock
        local suc, err = xpcall(updateTimer, log.error, delta)
        if not suc then
            io.stderr:write(err)
            io.stderr:flush()
        end
        timerClock = os.clock()

        local passedClock = os.clock() - startClock
        if passedClock > 0.1 then
            thread.sleep(0.0)
        else
            thread.sleep(0.001)
        end
    end
end

--- @return LSP
return function ()
    local session = setmetatable({
        _needCompile = {},
        _needDiagnostics = {},
        _clock = -100,
        _version = 0,
        _files = files(),
    }, mt)
    session.global = core.global(session)
    session.chain  = chainMgr()
    session.emmy   = emmyMgr()
    ---@type Workspace[]
    session.workspaces = {}
    return session
end

local mt = {}
mt.__index = mt
mt.type = 'task'

function mt:remove()
    if self._removed then
        return
    end
    self._removed = true
    coroutine.close(self.task)
end

function mt:isRemoved()
    return self._removed
end

function mt:step()
    if self._removed then
        return
    end
    local suc, res = coroutine.resume(self.task)
    if not suc then
        self:remove()
        log.error(debug.traceback(self.task, res))
        return
    end
    if coroutine.status(self.task) == 'dead' then
        self:remove()
    end
    return res
end

function mt:fastForward()
    if self._removed then
        return
    end
    while true do
        local suc = coroutine.resume(self.task)
        if not suc then
            self:remove()
            break
        end
        if coroutine.status(self.task) == 'dead' then
            self:remove()
            break
        end
    end
end

function mt:set(key, value)
    self.data[key] = value
end

function mt:get(key)
    return self.data[key]
end

return function (callback)
    local self = setmetatable({
        data = {},
        task = coroutine.create(callback),
    }, mt)
    return self
end


local setmetatable = setmetatable
local pairs = pairs
local tableInsert = table.insert
local mathMax = math.max
local mathFloor = math.floor

local curFrame = 0
local maxFrame = 0
local curIndex = 0
local freeQueue = {}
local timer = {}

local function allocQueue()
    local n = #freeQueue
    if n > 0 then
        local r = freeQueue[n]
        freeQueue[n] = nil
        return r
    else
        return {}
    end
end

local function mTimeout(self, timeout)
    if self._pauseRemaining or self._running then
        return
    end
    local ti = curFrame + timeout
    local q = timer[ti]
    if q == nil then
        q = allocQueue()
        timer[ti] = q
    end
    self._timeoutFrame = ti
    self._running = true
    q[#q + 1] = self
end

local function mWakeup(self)
    if self._removed then
        return
    end
    self._running = false
    if self._onTimer then
        xpcall(self._onTimer, log.error, self)
    end
    if self._removed then
        return
    end
    if self._timerCount then
        if self._timerCount > 1 then
            self._timerCount = self._timerCount - 1
            mTimeout(self, self._timeout)
        else
            self._removed = true
        end
    else
        mTimeout(self, self._timeout)
    end
end

local function getRemaining(self)
    if self._removed then
        return 0
    end
    if self._pauseRemaining then
        return self._pauseRemaining
    end
    if self._timeoutFrame == curFrame then
        return self._timeout or 0
    end
    return self._timeoutFrame - curFrame
end

local function onTick()
    local q = timer[curFrame]
    if q == nil then
        curIndex = 0
        return
    end
    for i = curIndex + 1, #q do
        local callback = q[i]
        curIndex = i
        q[i] = nil
        if callback then
            mWakeup(callback)
        end
    end
    curIndex = 0
    timer[curFrame] = nil
    freeQueue[#freeQueue + 1] = q
end

function ac.clock()
    return curFrame / 1000.0
end

function ac.timer_size()
    local n = 0
    for _, ts in pairs(timer) do
        n = n + #ts
    end
    return n
end

function ac.timer_all()
    local tbl = {}
    for _, ts in pairs(timer) do
        for i, t in ipairs(ts) do
            if t then
                tbl[#tbl + 1] = t
            end
        end
    end
    return tbl
end

local function update(delta)
    if curIndex ~= 0 then
        curFrame = curFrame - 1
    end
    maxFrame = maxFrame + delta * 1000.0
    while curFrame < maxFrame do
        curFrame = curFrame + 1
        onTick()
    end
end

local mt = {}
mt.__index = mt
mt.type = 'timer'

function mt:__tostring()
    return '[table:timer]'
end

function mt:__call()
    if self._onTimer then
        self:_onTimer()
    end
end

function mt:remove()
    self._removed = true
end

function mt:pause()
    if self._removed or self._pauseRemaining then
        return
    end
    self._pauseRemaining = getRemaining(self)
    self._running = false
    local ti = self._timeoutFrame
    local q = timer[ti]
    if q then
        for i = #q, 1, -1 do
            if q[i] == self then
                q[i] = false
                return
            end
        end
    end
end

function mt:resume()
    if self._removed or not self._pauseRemaining then
        return
    end
    local timeout = self._pauseRemaining
    self._pauseRemaining = nil
    mTimeout(self, timeout)
end

function mt:restart()
    if self._removed or self._pauseRemaining or not self._running then
        return
    end
    local ti = self._timeoutFrame
    local q = timer[ti]
    if q then
        for i = #q, 1, -1 do
            if q[i] == self then
                q[i] = false
                break
            end
        end
    end
    self._running = false
    mTimeout(self, self._timeout)
end

function mt:remaining()
    return getRemaining(self) / 1000.0
end

function mt:onTimer()
    self:_onTimer()
end

function ac.wait(timeout, onTimer)
    local t = setmetatable({
        ['_timeout'] = mathMax(mathFloor(timeout * 1000.0), 1),
        ['_onTimer'] = onTimer,
        ['_timerCount'] = 1,
    }, mt)
    mTimeout(t, t._timeout)
    return t
end

function ac.loop(timeout, onTimer)
    local t = setmetatable({
        ['_timeout'] = mathFloor(timeout * 1000.0),
        ['_onTimer'] = onTimer,
    }, mt)
    mTimeout(t, t._timeout)
    return t
end

function ac.timer(timeout, count, onTimer)
    if count == 0 then
        return ac.loop(timeout, onTimer)
    end
    local t = setmetatable({
        ['_timeout'] = mathFloor(timeout * 1000.0),
        ['_onTimer'] = onTimer,
        ['_timerCount'] = count,
    }, mt)
    mTimeout(t, t._timeout)
    return t
end

local function utimer_initialize(u)
    if not u._timers then
        u._timers = {}
    end
    if #u._timers > 0 then
        return
    end
    u._timers[1] = ac.loop(0.01, function()
        local timers = u._timers
        for i = #timers, 2, -1 do
            if timers[i]._removed then
                local len = #timers
                timers[i] = timers[len]
                timers[len] = nil
            end
        end
        if #timers == 1 then
            timers[1]:remove()
            timers[1] = nil
        end
    end)
end

function ac.uwait(u, timeout, onTimer)
    utimer_initialize(u)
    local t = ac.wait(timeout, onTimer)
    tableInsert(u._timers, t)
    return t
end

function ac.uloop(u, timeout, onTimer)
    utimer_initialize(u)
    local t = ac.loop(timeout, onTimer)
    tableInsert(u._timers, t)
    return t
end

function ac.utimer(u, timeout, count, onTimer)
    utimer_initialize(u)
    local t = ac.timer(timeout, count, onTimer)
    tableInsert(u._timers, t)
    return t
end

return update

local fs = require 'bee.filesystem'
local furi = require 'file-uri'

local function encode(path)
    return furi.encode(path:string())
end

local function decode(uri)
    return fs.path(furi.decode(uri))
end

return {
    encode = encode,
    decode = decode,
}

local fs = require 'bee.filesystem'

local table_sort = table.sort
local stringRep = string.rep
local type = type
local pairs = pairs
local ipairs = ipairs
local math_type = math.type
local next = next
local rawset = rawset
local move = table.move
local setmetatable = setmetatable
local tableSort = table.sort
local mathType = math.type

local function formatNumber(n)
    local str = ('%.10f'):format(n)
    str = str:gsub('%.?0*$', '')
    return str
end

local TAB = setmetatable({}, { __index = function (self, n)
    self[n] = stringRep('\t', n)
    return self[n]
end})

local RESERVED = {
    ['and']      = true,
    ['break']    = true,
    ['do']       = true,
    ['else']     = true,
    ['elseif']   = true,
    ['end']      = true,
    ['false']    = true,
    ['for']      = true,
    ['function'] = true,
    ['goto']     = true,
    ['if']       = true,
    ['in']       = true,
    ['local']    = true,
    ['nil']      = true,
    ['not']      = true,
    ['or']       = true,
    ['repeat']   = true,
    ['return']   = true,
    ['then']     = true,
    ['true']     = true,
    ['until']    = true,
    ['while']    = true,
}

function table.dump(tbl)
    if type(tbl) ~= 'table' then
        return ('%q'):format(tbl)
    end
    local lines = {}
    local mark = {}
    lines[#lines+1] = '{'
    local function unpack(tbl, tab)
        if mark[tbl] and mark[tbl] > 0 then
            lines[#lines+1] = TAB[tab+1] .. '"<Loop>"'
            return
        end
        if #lines > 10000 then
            lines[#lines+1] = TAB[tab+1] .. '"<Large>"'
            return
        end
        mark[tbl] = (mark[tbl] or 0) + 1
        local keys = {}
        local keymap = {}
        local integerFormat = '[%d]'
        if #tbl >= 10 then
            local width = math.log(#tbl, 10)
            integerFormat = ('[%%0%dd]'):format(math.ceil(width))
        end
        for key in pairs(tbl) do
            if type(key) == 'string' then
                if not key:match('^[%a_][%w_]*$')
                or #key >= 32
                or RESERVED[key]
                then
                    keymap[key] = ('[%q]'):format(key)
                else
                    keymap[key] = key
                end
            elseif mathType(key) == 'integer' then
                keymap[key] = integerFormat:format(key)
            else
                keymap[key] = ('["<%s>"]'):format(key)
            end
            keys[#keys+1] = key
        end
        local mt = getmetatable(tbl)
        if not mt or not mt.__pairs then
            tableSort(keys, function (a, b)
                return keymap[a] < keymap[b]
            end)
        end
        for _, key in ipairs(keys) do
            local value = tbl[key]
            local tp = type(value)
            if tp == 'table' then
                lines[#lines+1] = ('%s%s = {'):format(TAB[tab+1], keymap[key])
                unpack(value, tab+1)
                lines[#lines+1] = ('%s},'):format(TAB[tab+1])
            elseif tp == 'string' or tp == 'boolean' then
                lines[#lines+1] = ('%s%s = %q,'):format(TAB[tab+1], keymap[key], value)
            elseif tp == 'number' then
                lines[#lines+1] = ('%s%s = %s,'):format(TAB[tab+1], keymap[key], formatNumber(value))
            elseif tp == 'nil' then
            else
                lines[#lines+1] = ('%s%s = %s,'):format(TAB[tab+1], keymap[key], tostring(value))
            end
        end
        mark[tbl] = mark[tbl] - 1
    end
    unpack(tbl, 0)
    lines[#lines+1] = '}'
    return table.concat(lines, '\r\n')
end

local function sort_table(tbl)
    if not tbl then
        tbl = {}
    end
    local mt = {}
    local keys = {}
    local mark = {}
    local n = 0
    for key in next, tbl do
        n=n+1;keys[n] = key
        mark[key] = true
    end
    table_sort(keys)
    function mt:__newindex(key, value)
        rawset(self, key, value)
        n=n+1;keys[n] = key
        mark[key] = true
        if type(value) == 'table' then
            sort_table(value)
        end
    end
    function mt:__pairs()
        local list = {}
        local m = 0
        for key in next, self do
            if not mark[key] then
                m=m+1;list[m] = key
            end
        end
        if m > 0 then
            move(keys, 1, n, m+1)
            table_sort(list)
            for i = 1, m do
                local key = list[i]
                keys[i] = key
                mark[key] = true
            end
            n = n + m
        end
        local i = 0
        return function ()
            i = i + 1
            local key = keys[i]
            return key, self[key]
        end
    end

    return setmetatable(tbl, mt)
end

function table.container(tbl)
    return sort_table(tbl)
end

function table.equal(a, b)
    local tp1, tp2 = type(a), type(b)
    if tp1 ~= tp2 then
        return false
    end
    if tp1 == 'table' then
        local mark = {}
        for k in pairs(a) do
            if not table.equal(a[k], b[k]) then
                return false
            end
            mark[k] = true
        end
        for k in pairs(b) do
            if not mark[k] then
                return false
            end
        end
        return true
    end
    return a == b
end

function table.deepCopy(a)
    local t = {}
    for k, v in pairs(a) do
        if type(v) == 'table' then
            t[k] = table.deepCopy(v)
        else
            t[k] = v
        end
    end
    return t
end

function io.load(file_path)
    local f, e = io.open(file_path:string(), 'rb')
    if not f then
        return nil, e
    end
    if f:read(3) ~= '\xEF\xBB\xBF' then
        f:seek("set")
    end
    local buf = f:read 'a'
    f:close()
    return buf
end

function io.save(file_path, content)
    local f, e = io.open(file_path:string(), "wb")

    if f then
        f:write(content)
        f:close()
        return true
    else
        return false, e
    end
end


local m = {}

local mt = {}
mt.__add      = function (a, b)
    if a == nil then a = 0 end
    if b == nil then b = 0 end
    return a + b
end
mt.__sub      = function (a, b)
    if a == nil then a = 0 end
    if b == nil then b = 0 end
    return a - b
end
mt.__mul      = function (a, b)
    if a == nil then a = 0 end
    if b == nil then b = 0 end
    return a * b
end
mt.__div      = function (a, b)
    if a == nil then a = 0 end
    if b == nil then b = 0 end
    return a / b
end
mt.__mod      = function (a, b)
    if a == nil then a = 0 end
    if b == nil then b = 0 end
    return a % b
end
mt.__pow      = function (a, b)
    if a == nil then a = 0 end
    if b == nil then b = 0 end
    return a ^ b
end
mt.__unm      = function ()
    return 0
end
mt.__concat   = function (a, b)
    if a == nil then a = '' end
    if b == nil then b = '' end
    return a .. b
end
mt.__len      = function ()
    return 0
end
mt.__lt       = function (a, b)
    if a == nil then a = 0 end
    if b == nil then b = 0 end
    return a < b
end
mt.__le       = function (a, b)
    if a == nil then a = 0 end
    if b == nil then b = 0 end
    return a <= b
end
mt.__index    = function () end
mt.__newindex = function () end
mt.__call     = function () end
mt.__pairs    = function () end
mt.__ipairs   = function () end
if _VERSION == 'Lua 5.3' or _VERSION == 'Lua 5.4' then
    mt.__idiv      = load[[
        local a, b = ...
        if a == nil then a = 0 end
        if b == nil then b = 0 end
        return a // b
    ]]
    mt.__band      = load[[
        local a, b = ...
        if a == nil then a = 0 end
        if b == nil then b = 0 end
        return a & b
    ]]
    mt.__bor       = load[[
        local a, b = ...
        if a == nil then a = 0 end
        if b == nil then b = 0 end
        return a | b
    ]]
    mt.__bxor      = load[[
        local a, b = ...
        if a == nil then a = 0 end
        if b == nil then b = 0 end
        return a ~ b
    ]]
    mt.__bnot      = load[[
        return ~ 0
    ]]
    mt.__shl       = load[[
        local a, b = ...
        if a == nil then a = 0 end
        if b == nil then b = 0 end
        return a << b
    ]]
    mt.__shr       = load[[
        local a, b = ...
        if a == nil then a = 0 end
        if b == nil then b = 0 end
        return a >> b
    ]]
end

for event, func in pairs(mt) do
    mt[event] = function (...)
        local watch = m.watch
        if not watch then
            return func(...)
        end
        local care, result = watch(event, ...)
        if not care then
            return func(...)
        end
        return result
    end
end

function m.enable()
    debug.setmetatable(nil, mt)
end

function m.disable()
    if debug.getmetatable(nil) == mt then
        debug.setmetatable(nil, nil)
    end
end

return m


local fs = require 'bee.filesystem'
local async = require 'async'
local config = require 'config'
local ll = require 'lpeglabel'
local platform = require 'bee.platform'
local glob = require 'glob'
local uric = require 'uri'
local fn = require 'filename'

--- @class Workspace
local mt = {}
mt.__index = mt

function mt:listenLoadFile()
    self._loadFileRequest = async.run('loadfile', nil, function (filename, mode, buf)
        local path = fs.path(filename)
        local name = fn.getFileName(path)
        local uri = uric.encode(path)
        self.files[name] = uri
        if mode == 'workspace' then
            self.lsp:readText(self, uri, path, buf, self._currentScanCompiled)
        elseif mode == 'library' then
            self.lsp:readLibrary(self, uri, path, buf, self._currentScanCompiled)
        else
            error('Unknown mode:' .. tostring(mode))
        end
    end)
end

function mt:buildScanPattern()
    local pattern = {}

    -- config.workspace.ignoreDir
    for path in pairs(config.config.workspace.ignoreDir) do
        pattern[#pattern+1] = path
    end
    -- config.files.exclude
    for path, ignore in pairs(config.other.exclude) do
        if ignore then
            pattern[#pattern+1] = path
        end
    end
    -- config.workspace.ignoreSubmodules
    if config.config.workspace.ignoreSubmodules then
        local buf = io.load(self.root / '.gitmodules')
        if buf then
            for path in buf:gmatch('path = ([^\r\n]+)') do
                log.info('忽略子模块：', path)
                pattern[#pattern+1] = path
            end
        end
    end
    -- config.workspace.useGitIgnore
    if config.config.workspace.useGitIgnore then
        local buf = io.load(self.root / '.gitignore')
        if buf then
            for line in buf:gmatch '[^\r\n]+' do
                pattern[#pattern+1] = line
            end
        end
        buf = io.load(self.root / '.git' / 'info' / 'exclude' )
        if buf then
            for line in buf:gmatch '[^\r\n]+' do
                pattern[#pattern+1] = line
            end
        end
    end
    -- config.workspace.library
    for path in pairs(config.config.workspace.library) do
        pattern[#pattern+1] = path
    end

    return pattern
end

---@param options table
function mt:buildLibraryRequests(options)
    local requests = {}
    for path, pattern in pairs(config.config.workspace.library) do
        requests[#requests+1] = {
            mode = 'library',
            root = fs.absolute(fs.path(path)):string(),
            pattern = pattern,
            options = options,
        }
    end
    return table.unpack(requests)
end

function mt:scanFiles()
    if self._scanRequest then
        log.info('Break scan.')
        self._scanRequest:push('stop')
        self._scanRequest = nil
        self._complete = false
        self:reset()
    end

    local pattern = self:buildScanPattern()
    local options = {
        ignoreCase = platform.OS == 'Windows',
    }

    self.gitignore = glob.gitignore(pattern, options)
    self._currentScanCompiled = {}
    local count = 0
    self._scanRequest = async.run('scanfiles', {
        {
            mode = 'workspace',
            root = self.root:string(),
            pattern = pattern,
            options = options,
        },
        self:buildLibraryRequests(options),
    }, function (mode, ...)
        if mode == 'ok' then
            log.info('Scan finish, got', count, 'files.')
            self._complete = true
            self._scanRequest = nil
            self:reset()
            return true
        elseif mode == 'log' then
            log.debug(...)
        elseif mode == 'workspace' then
            local path = fs.path(...)
            if not fn.isLuaFile(path) then
                return
            end
            self._loadFileRequest:push(path:string(), 'workspace')
            count = count + 1
        elseif mode == 'library' then
            local path = fs.path(...)
            if not fn.isLuaFile(path) then
                return
            end
            self._loadFileRequest:push(path:string(), 'library')
            count = count + 1
        elseif mode == 'stop' then
            log.info('Scan stoped.')
            return false
        end
    end)
end

function mt:init(rootUri)
    self.root = uric.decode(rootUri)
    self.uri = rootUri
    if not self.root then
        return
    end
    log.info('Workspace inited, root: ', self.root)
    log.info('Workspace inited, uri: ', rootUri)
    local logPath = ROOT / 'log' / (rootUri:gsub('[/:]+', '_') .. '.log')
    log.info('Log path: ', logPath)
    log.init(ROOT, logPath)
end

function mt:isComplete()
    return self._complete == true
end

function mt:addFile(path)
    if not fn.isLuaFile(path) then
        return
    end
    local name = fn.getFileName(path)
    local uri = uric.encode(path)
    self.files[name] = uri
    self.lsp:readText(self, uri, path)
end

function mt:removeFile(path)
    local name = fn.getFileName(path)
    if not self.files[name] then
        return
    end
    self.files[name] = nil
    local uri = uric.encode(path)
    self.lsp:removeText(uri)
end

function mt:findPath(baseUri, searchers)
    local results = {}
    local basePath = uric.decode(baseUri)
    if not basePath then
        return nil
    end
    local baseName = fn.getFileName(basePath)
    for filename, uri in pairs(self.files) do
        if filename ~= baseName then
            for _, searcher in ipairs(searchers) do
                if filename:sub(-#searcher) == searcher then
                    local sep = filename:sub(-#searcher-1, -#searcher-1)
                    if sep == '/' or sep == '\\' then
                        results[#results+1] = uri
                    end
                end
            end
        end
    end

    if #results == 0 then
        return nil
    end
    local uri
    if #results == 1 then
        uri = results[1]
    else
        table.sort(results, function (a, b)
            return fn.similarity(a, baseUri) > fn.similarity(b, baseUri)
        end)
        uri = results[1]
    end
    return uri
end

function mt:createCompiler(str)
    local state = {
        'Main',
    }
    local function push(c)
        if state.Main then
            state.Main = state.Main * c
        else
            state.Main = c
        end
    end
    local count = 0
    local function code()
        count = count + 1
        local name = 'C' .. tostring(count)
        local nextName = 'C' .. tostring(count + 1)
        state[name] = ll.P(1) * (#ll.V(nextName) + ll.V(name))
        return ll.V(name)
    end
    local function static(c)
        count = count + 1
        local name = 'C' .. tostring(count)
        local nextName = 'C' .. tostring(count + 1)
        local catch = #ll.V(nextName)
        if platform.OS == 'Windows' then
            for i = #c, 1, -1 do
                local char = c:sub(i, i)
                local u = char:upper()
                local l = char:lower()
                if u == l then
                    catch = ll.P(char) * catch
                else
                    catch = (ll.P(u) + ll.P(l)) * catch
                end
            end
        else
            catch = ll.P(c) * catch
        end
        state[name] = catch
        return ll.V(name)
    end
    local function eof()
        count = count + 1
        local name = 'C' .. tostring(count)
        state[name] = ll.Cmt(ll.P(1) + ll.Cp(), function (_, _, c)
            return type(c) == 'number'
        end)
        return ll.V(name)
    end
    local isFirstCode = true
    local firstCode
    local compiler = ll.P {
        'Result',
        Result = (ll.V'Code' + ll.V'Static')^1,
        Code   = ll.P'?' / function ()
            if isFirstCode then
                isFirstCode = false
                push(ll.Cmt(ll.C(code()), function (_, pos, code)
                    firstCode = code
                    return pos, code
                end))
            else
                push(ll.Cmt(
                    ll.C(code()),
                    function (_, _, me)
                        return firstCode == me
                    end
                ))
            end
        end,
        Static = (1 - ll.P'?')^1 / function (c)
            push(static(c))
        end,
    }
    compiler:match(str)
    push(eof())
    return ll.P(state)
end

function mt:compileLuaPath()
    for i, luapath in ipairs(config.config.runtime.path) do
        self.pathMatcher[i] = self:createCompiler(luapath)
    end
end

function mt:convertPathAsRequire(filename, start)
    local list
    for _, matcher in ipairs(self.pathMatcher) do
        local str = matcher:match(filename:sub(start))
        if str then
            if not list then
                list = {}
            end
            list[#list+1] = str:gsub('/', '.')
        end
    end
    return list
end

--- @param baseUri uri
--- @param input string
function mt:matchPath(baseUri, input)
    local first = input:match '^[^%.]+'
    if not first then
        return nil
    end
    first = first:gsub('%W', '%%%1')
    local basePath = uric.decode(baseUri)
    if not basePath then
        return nil
    end
    local baseName = fn.getFileName(basePath)
    local rootLen = #self.root:string(basePath)
    local map = {}
    for filename in pairs(self.files) do
        if filename ~= baseName then
            local trueFilename = fn.getTrueName(filename)
            local start
            if platform.OS == 'Windows' then
                start = filename:find('[/\\]' .. first:lower(), rootLen + 1)
            else
                start = trueFilename:find('[/\\]' .. first, rootLen + 1)
            end
            if start then
                local list = self:convertPathAsRequire(trueFilename, start + 1)
                if list then
                    for _, str in ipairs(list) do
                        if #str >= #input and fn.fileNameEq(str:sub(1, #input), input) then
                            if not map[str] then
                                map[str] = trueFilename
                            else
                                local s1 = fn.similarity(trueFilename, baseName)
                                local s2 = fn.similarity(map[str], baseName)
                                if s1 > s2 then
                                    map[str] = trueFilename
                                elseif s1 == s2 then
                                    if trueFilename < map[str] then
                                        map[str] = trueFilename
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local list = {}
    for str in pairs(map) do
        list[#list+1] = str
        map[str] = map[str]:sub(rootLen + 2)
    end
    if #list == 0 then
        return nil
    end
    table.sort(list, function (a, b)
        local sa = fn.similarity(map[a], baseName)
        local sb = fn.similarity(map[b], baseName)
        if sa == sb then
            return a < b
        else
            return sa > sb
        end
    end)
    return list, map
end

function mt:searchPath(baseUri, str)
    str = fn.getFileName(fs.path(str))
    if self.searched[baseUri] and self.searched[baseUri][str] then
        return self.searched[baseUri][str]
    end
    str = str:gsub('%.', '/')
             :gsub('%%', '%%%%')
    local searchers = {}
    for i, luapath in ipairs(config.config.runtime.path) do
        searchers[i] = luapath:gsub('%?', str)
    end

    local uri = self:findPath(baseUri, searchers)
    if uri then
        if not self.searched[baseUri] then
            self.searched[baseUri] = {}
        end
        self.searched[baseUri][str] = uri
    end
    return uri
end

function mt:loadPath(baseUri, str)
    local ok, relative = pcall(fs.relative, fs.absolute(self.root / str), self.root)
    if not ok then
        return nil
    end
    str = fn.getFileName(relative)
    if self.loaded[str] then
        return self.loaded[str]
    end

    local searchers = { str }

    local uri = self:findPath(baseUri, searchers)
    if uri then
        self.loaded[str] = uri
    end
    return uri
end

function mt:reset()
    self.searched = {}
    self.loaded = {}
    self.lsp:reCompile()
end

---@param uri uri
---@return path
function mt:relativePathByUri(uri)
    local path = uric.decode(uri)
    if not path then
        return nil
    end
    local relate = fs.relative(path, self.root)
    return relate
end

---@param uri uri
---@return path
function mt:absolutePathByUri(uri)
    local path = uric.decode(uri)
    if not path then
        return nil
    end
    return fs.absolute(path)
end

--- @param lsp LSP
--- @param name string
--- @return Workspace
return function (lsp, name)
    local workspace = setmetatable({
        lsp = lsp,
        name = name,
        files = {},
        searched = {},
        loaded = {},
        pathMatcher = {}
    }, mt)
    workspace:compileLuaPath()
    workspace:listenLoadFile()
    return workspace
end


local json = require 'json'
local diagDefault = require 'constant.DiagnosticDefaultSeverity'

local VERSION = "0.14.2"

local package = {
    name = "lua",
    displayName = "Lua",
    description = "Lua Language Server coded by Lua",
    author = "sumneko",
    icon = "images/logo.png",
    license = "MIT",
    repository = {
        type = "git",
        url = "https://github.com/sumneko/lua-language-server"
    },
    publisher = "sumneko",
    categories = {
        "Linters",
        "Programming Languages",
        "Snippets"
    },
    keywords = {
        "Lua",
        "LSP",
        "GoTo Definition",
        "IntelliSense"
    },
    engines = {
        vscode = "^1.23.0"
    },
    activationEvents = {
        "onLanguage:lua"
    },
    main = "./client/out/extension",
    contributes = {
        configuration = {
            type = "object",
            title = "Lua",
            properties = {
                ["Lua.runtime.version"] = {
                    scope = "resource",
                    type = "string",
                    default = "Lua 5.3",
                    enum = {
                        "Lua 5.1",
                        "Lua 5.2",
                        "Lua 5.3",
                        "Lua 5.4",
                        "LuaJIT"
                    },
                    markdownDescription = "%config.runtime.version%"
                },
                ["Lua.runtime.path"] = {
                    scope = "resource",
                    type = "array",
                    items = {
                        type = 'string',
                    },
                    markdownDescription = "%config.runtime.path%",
                    default = {
                        "?.lua",
                        "?/init.lua",
                        "?/?.lua"
                    }
                },
                ["Lua.diagnostics.enable"] = {
                    scope = 'resource',
                    type = 'boolean',
                    default = true,
                    markdownDescription = "%config.diagnostics.enable%"
                },
                ["Lua.diagnostics.disable"] = {
                    scope = "resource",
                    type = "array",
                    items = {
                        type = 'string',
                    },
                    markdownDescription = "%config.diagnostics.disable%"
                },
                ["Lua.diagnostics.globals"] = {
                    scope = "resource",
                    type = "array",
                    items = {
                        type = 'string',
                    },
                    markdownDescription = "%config.diagnostics.globals%"
                },
                ["Lua.diagnostics.severity"] = {
                    scope = "resource",
                    type = 'object',
                    markdownDescription = "%config.diagnostics.severity%",
                    title = "severity",
                    properties = {}
                },
                ["Lua.workspace.ignoreDir"] = {
                    scope = "resource",
                    type = "array",
                    items = {
                        type = 'string',
                    },
                    markdownDescription = "%config.workspace.ignoreDir%",
                    default = {
                        ".vscode",
                    },
                },
                ["Lua.workspace.ignoreSubmodules"] = {
                    scope = "resource",
                    type = "boolean",
                    default = true,
                    markdownDescription = "%config.workspace.ignoreSubmodules%"
                },
                ["Lua.workspace.useGitIgnore"] = {
                    scope = "resource",
                    type = "boolean",
                    default = true,
                    markdownDescription = "%config.workspace.useGitIgnore%"
                },
                ["Lua.workspace.maxPreload"] = {
                    scope = "resource",
                    type = "integer",
                    default = 300,
                    markdownDescription = "%config.workspace.maxPreload%"
                },
                ["Lua.workspace.preloadFileSize"] = {
                    scope = "resource",
                    type = "integer",
                    default = 100,
                    markdownDescription = "%config.workspace.preloadFileSize%"
                },
                ["Lua.workspace.library"] = {
                    scope = 'resource',
                    type = 'object',
                    markdownDescription = "%config.workspace.library%"
                },
                ["Lua.completion.enable"] = {
                    scope = "resource",
                    type = "boolean",
                    default = true,
                    markdownDescription = "%config.completion.enable%"
                },
                ["Lua.completion.callSnippet"] = {
                    scope = "resource",
                    type = "string",
                    default = "Disable",
                    enum = {
                        "Disable",
                        "Both",
                        "Replace",
                    },
                    markdownEnumDescriptions = {
                        "%config.completion.callSnippet.Disable%",
                        "%config.completion.callSnippet.Both%",
                        "%config.completion.callSnippet.Replace%",
                    },
                    markdownDescription = "%config.completion.callSnippet%"
                },
                ["Lua.completion.keywordSnippet"] = {
                    scope = "resource",
                    type = "string",
                    default = "Replace",
                    enum = {
                        "Disable",
                        "Both",
                        "Replace",
                    },
                    markdownEnumDescriptions = {
                        "%config.completion.keywordSnippet.Disable%",
                        "%config.completion.keywordSnippet.Both%",
                        "%config.completion.keywordSnippet.Replace%",
                    },
                    markdownDescription = "%config.completion.keywordSnippet%"
                },
                --["Lua.plugin.enable"] = {
                --    scope = "resource",
                --    type = "boolean",
                --    default = false,
                --    markdownDescription = "%config.plugin.enable%"
                --},
                --["Lua.plugin.path"] = {
                --    scope = "resource",
                --    type = "string",
                --    default = ".vscode/lua-plugin/*.lua",
                --    markdownDescription = "%config.plugin.path%"
                --},
                ["Lua.zzzzzz.cat"] = {
                    scope = "resource",
                    type = "boolean",
                    default = false,
                    markdownDescription = "%config.zzzzzz.cat%"
                },
            }
        },
        grammars = {
            {
                language = "lua",
                scopeName = "source.lua",
                path = "./syntaxes/lua.tmLanguage.json"
            }
        }
    },
	__metadata = {
		id = "3a15b5a7-be12-47e3-8445-88ee3eabc8b2",
		publisherDisplayName = "sumneko",
		publisherId = "fb626675-24cf-4881-8c13-b465f29bec2f",
	},
}

local DiagSeverity = package.contributes.configuration.properties["Lua.diagnostics.severity"].properties
for name, level in pairs(diagDefault) do
    DiagSeverity[name] = {
        scope = 'resource',
        type = 'string',
        default = level,
        enum = {
            'Error',
            'Warning',
            'Information',
            'Hint',
        }
    }
end

package.version = VERSION

io.save(ROOT:parent_path() / 'package.json', json.encode(package))

local example = {
    library = [[
```json
"Lua.workspace.library": {
    "C:/lua": true,
    "../lib": [
        "temp/*"
    ]
}
```
]],
    disable = [[
```json
"Lua.diagnostics.disable" : [
    "unused-local",
    "lowercase-global"
]
```
]],
    globals = [[
```json
"Lua.diagnostics.globals" : [
    "GLOBAL1",
    "GLOBAL2"
]
```
]],
    severity = [[
```json
"Lua.diagnostics.severity" : {
    "redefined-local" : "Warning",
    "emmy-lua" : "Hint"
}
```
]],
    ignoreDir = [[
```json
"Lua.workspace.ignoreDir" : [
    "temp/*.*",
    "!temp/*.lua"
]
```
]]
}

io.save(ROOT:parent_path() / 'package.nls.json', json.encode {
    ["config.runtime.version"]            = "Lua runtime version.",
    ["config.runtime.path"]               = "`package.path`",
    ["config.diagnostics.enable"]         = "Enable diagnostics.",
    ["config.diagnostics.disable"]        = "Disabled diagnostic (Use code in hover brackets).\n" .. example.disable,
    ["config.diagnostics.globals"]        = "Defined global variables.\n" .. example.globals,
    ["config.diagnostics.severity"]       = "Modified diagnostic severity.\n" .. example.severity,
    ["config.workspace.ignoreDir"]        = "Ignored directories (Use `.gitignore` grammar).\n" .. example.ignoreDir,
    ["config.workspace.ignoreSubmodules"] = "Ignore submodules.",
    ["config.workspace.useGitIgnore"]     = "Ignore files list in `.gitignore` .",
    ["config.workspace.maxPreload"]       = "Max preloaded files.",
    ["config.workspace.preloadFileSize"]  = "Skip files larger than this value (KB) when preloading.",
    ["config.workspace.library"]          = [[
Load external library.
This feature can load external Lua files, which can be used for definition, automatic completion and other functions. Note that the language server does not monitor changes in external files and needs to restart if the external files are modified.
The following example shows loaded files in `C:/lua` and `../lib` ,exclude `../lib/temp`.
]] .. example.library,
    ['config.completion.enable']          = 'Enable completion.',
    ['config.completion.callSnippet']     = 'Shows function call snippets.',
    ['config.completion.callSnippet.Disable'] = "Only shows `function name`.",
    ['config.completion.callSnippet.Both'] = "Shows `function name` and `call snippet`.",
    ['config.completion.callSnippet.Replace'] = "Only shows `call snippet.`",
    ['config.completion.keywordSnippet']     = 'Shows keyword syntax snippets.',
    ['config.completion.keywordSnippet.Disable'] = "Only shows `keyword`.",
    ['config.completion.keywordSnippet.Both'] = "Shows `keyword` and `syntax snippet`.",
    ['config.completion.keywordSnippet.Replace'] = "Only shows `syntax snippet`.",
    ['config.zzzzzz.cat']                 = 'DO NOT TOUCH ME, LET ME SLEEP >_<\n\n(This will enable beta version, which are still in the early stages of development, and all features will fail after enabling this setting.)',
})

io.save(ROOT:parent_path() / 'package.nls.zh-cn.json', json.encode {
    ["config.runtime.version"]            = "Lua运行版本。",
    ["config.runtime.path"]               = "`package.path`",
    ["config.diagnostics.enable"]         = "启用诊断。",
    ["config.diagnostics.disable"]        = "禁用的诊断（使用浮框括号内的代码）。\n" .. example.disable,
    ["config.diagnostics.globals"]        = "已定义的全局变量。\n" .. example.globals,
    ["config.diagnostics.severity"]       = "修改诊断等级。\n" .. example.severity,
    ["config.workspace.ignoreDir"]        = "忽略的目录（使用 `.gitignore` 语法）。\n" .. example.ignoreDir,
    ["config.workspace.ignoreSubmodules"] = "忽略子模块。",
    ["config.workspace.useGitIgnore"]     = "忽略 `.gitignore` 中列举的文件。",
    ["config.workspace.maxPreload"]       = "最大预加载文件数。",
    ["config.workspace.preloadFileSize"]  = "预加载时跳过大小大于该值（KB）的文件。",
    ["config.workspace.library"]          = [[
加载外部函数库。
该功能可以加载外部的Lua文件，用于函数定义、自动完成等功能。注意，语言服务不会监视外部文件的变化，如果修改了外部文件需要重启。
下面这个例子表示加载`C:/lua`与`../lib`中的所有文件，但不加载`../lib/temp`中的文件。
]] .. example.library,
    ['config.completion.enable']          = '启用自动完成。',
    ['config.completion.callSnippet']     = '显示函数调用片段。',
    ['config.completion.callSnippet.Disable'] = "只显示 `函数名`。",
    ['config.completion.callSnippet.Both'] = "显示 `函数名` 与 `调用片段`。",
    ['config.completion.callSnippet.Replace'] = "只显示 `调用片段`。",
    ['config.completion.keywordSnippet']     = '显示关键字语法片段',
    ['config.completion.keywordSnippet.Disable'] = "只显示 `关键字`。",
    ['config.completion.keywordSnippet.Both'] = "显示 `关键字` 与 `语法片段`。",
    ['config.completion.keywordSnippet.Replace'] = "只显示 `语法片段`。",
    ['config.zzzzzz.cat']                 = 'DO NOT TOUCH ME, LET ME SLEEP >_<\n\n（这会启用还处于早期开发阶段的beta版，开启后所有的功能都会失效）',

return function ()
    log.info('Server exited.')
    os.exit(true)
end

local function init(name)
    method[name] = require('method.' .. name:gsub('/', '.'))
end

init 'exit'
init 'initialize'
init 'initialized'
init 'shutdown'
init 'completionItem/resolve'
init 'textDocument/codeAction'
init 'textDocument/completion'
init 'textDocument/definition'
init 'textDocument/didOpen'
init 'textDocument/didChange'
init 'textDocument/didClose'
init 'textDocument/documentHighlight'
init 'textDocument/documentSymbol'
init 'textDocument/foldingRange'
init 'textDocument/hover'
init 'textDocument/implementation'
init 'textDocument/onTypeFormatting'
init 'textDocument/publishDiagnostics'
init 'textDocument/rename'
init 'textDocument/references'
init 'textDocument/semanticTokens/full'
init 'textDocument/signatureHelp'
init 'workspace/didChangeConfiguration'
init 'workspace/didChangeWatchedFiles'
init 'workspace/didChangeWorkspaceFolders'
init 'workspace/executeCommand'
init 'workspace/symbol'

return method

local workspace = require 'workspace'
local nonil = require 'without-check-nil'
local client = require 'client'
local json = require 'json'
local sp = require 'bee.subprocess'

local function allWords()
    local str = [[abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.:('"[,#*@| ]]
    local list = {}
    for c in str:gmatch '.' do
        list[#list+1] = c
    end
    return list
end

--- @param lsp LSP
--- @param params table
--- @return table
return function (lsp, params)
    lsp._inited = true
    lsp.client = params
    client.init(params)
    log.info(table.dump(params))
    log.debug('ProcessID', sp.get_id())

    if params.rootUri and params.rootUri ~= json.null then
        lsp:addWorkspace('root', params.rootUri)
    end

    local server = {
        serverInfo   = {
            name    = 'sumneko.lua',
            version = 'alpha',
        },
        capabilities = {
            hoverProvider = true,
            definitionProvider = true,
            referencesProvider = true,
            renameProvider = true,
            documentSymbolProvider = true,
            documentHighlightProvider = true,
            codeActionProvider = true,
            foldingRangeProvider = true,
            workspaceSymbolProvider = true,
            signatureHelpProvider = {
                triggerCharacters = { '(', ',' },
            },
            -- 文本同步方式
            textDocumentSync = {
                -- 打开关闭文本时通知
                openClose = true,
                -- 文本改变时完全通知 TODO 支持差量更新（2）
                change = 1,
            },
            documentOnTypeFormattingProvider = {
                firstTriggerCharacter = '}',
            },
            executeCommandProvider = {
                commands = {
                    'lua.removeSpace:' .. sp.get_id(),
                    'lua.solve:' .. sp.get_id(),
                },
            },
        }
    }

    nonil.enable()
    if not params.capabilities.textDocument.completion.dynamicRegistration then
        server.capabilities.completionProvider = {
            triggerCharacters = allWords(),
        }
    end
    nonil.disable()

    return server
end

local rpc = require 'rpc'

--- @param lsp LSP
--- @return boolean
return function (lsp)
    if #lsp.workspaces > 0 then
        for _, ws in ipairs(lsp.workspaces) do
            -- 请求工作目录
            local uri = ws.uri
            -- 请求配置
            rpc:request('workspace/configuration', {
                items = {
                    {
                        scopeUri = uri,
                        section = 'Lua',
                    },
                    {
                        scopeUri = uri,
                        section = 'files.associations',
                    },
                    {
                        scopeUri = uri,
                        section = 'files.exclude',
                    }
                },
            }, function (configs)
                lsp:onUpdateConfig(configs[1], {
                    associations = configs[2],
                    exclude      = configs[3],
                })
            end)
        end
    else
        -- 请求配置
        rpc:request('workspace/configuration', {
            items = {
                {
                    section = 'Lua',
                },
                {
                    section = 'files.associations',
                },
                {
                    section = 'files.exclude',
                }
            },
        }, function (configs)
            lsp:onUpdateConfig(configs[1], {
                associations = configs[2],
                exclude      = configs[3],
            })
        end)
    end

    rpc:request('client/registerCapability', {
        registrations = {
            -- 监视文件变化
            {
                id = '0',
                method = 'workspace/didChangeWatchedFiles',
                registerOptions = {
                    watchers = {
                        {
                            globPattern = '**/',
                            kind = 1 | 2 | 4,
                        }
                    },
                },
            },
            -- 配置变化
            {
                id = '1',
                method = 'workspace/didChangeConfiguration',
            }
        }
    }, function ()
        log.debug('client/registerCapability Success!')
    end)

    return true
end

return function ()
    log.info('Server shutdown.')
    return true
end

local m = require 'lpeglabel'
local matcher = require 'glob.matcher'

local function prop(name, pat)
    return m.Cg(m.Cc(true), name) * pat
end

local function object(type, pat)
    return m.Ct(
        m.Cg(m.Cc(type), 'type') *
        m.Cg(pat, 'value')
    )
end

local function expect(p, err)
    return p + m.T(err)
end

local parser = m.P {
    'Main',
    ['Sp']          = m.S(' \t')^0,
    ['Slash']       = m.S('/')^1,
    ['Main']        = m.Ct(m.V'Sp' * m.P'{' * m.V'Pattern' * (',' * expect(m.V'Pattern', 'Miss exp after ","'))^0 * m.P'}')
                    + m.Ct(m.V'Pattern')
                    + m.T'Main Failed'
                    ,
    ['Pattern']     = m.Ct(m.V'Sp' * prop('neg', m.P'!') * expect(m.V'Unit', 'Miss exp after "!"'))
                    + m.Ct(m.V'Unit')
                    ,
    ['NeedRoot']    = prop('root', (m.P'.' * m.V'Slash' + m.V'Slash')),
    ['Unit']        = m.V'Sp' * m.V'NeedRoot'^-1 * expect(m.V'Exp', 'Miss exp') * m.V'Sp',
    ['Exp']         = m.V'Sp' * (m.V'FSymbol' + object('/', m.V'Slash') + m.V'Word')^0 * m.V'Sp',
    ['Word']        = object('word', m.Ct((m.V'CSymbol' + m.V'Char' - m.V'FSymbol')^1)),
    ['CSymbol']     = object('*',    m.P'*')
                    + object('?',    m.P'?')
                    + object('[]',   m.V'Range')
                    ,
    ['SimpleChar']  = m.P(1) - m.S',{}[]*?/',
    ['EscChar']     = m.P'\\' / '' * m.P(1),
    ['Char']        = object('char', m.Cs((m.V'EscChar' + m.V'SimpleChar')^1)),
    ['FSymbol']     = object('**', m.P'**'),
    ['Range']       = m.P'[' * m.Ct(m.V'RangeUnit'^0) * m.P']'^-1,
    ['RangeUnit']   = m.Ct(- m.P']' * m.C(m.P(1)) * (m.P'-' * - m.P']' * m.C(m.P(1)))^-1),
}

---@class gitignore
local mt = {}
mt.__index = mt
mt.__name = 'gitignore'

function mt:addPattern(pat)
    if type(pat) ~= 'string' then
        return
    end
    self.pattern[#self.pattern+1] = pat
    if self.options.ignoreCase then
        pat = pat:lower()
    end
    local states, err = parser:match(pat)
    if not states then
        self.errors[#self.errors+1] = {
            pattern = pat,
            message = err
        }
        return
    end
    for _, state in ipairs(states) do
        self.matcher[#self.matcher+1] = matcher(state)
    end
end

function mt:setOption(op, val)
    if val == nil then
        val = true
    end
    self.options[op] = val
end

---@param key string | "'type'" | "'list'"
---@param func function | "function (path) end"
function mt:setInterface(key, func)
    if type(func) ~= 'function' then
        return
    end
    self.interface[key] = func
end

function mt:callInterface(name, ...)
    local func = self.interface[name]
    return func(...)
end

function mt:hasInterface(name)
    return self.interface[name] ~= nil
end

function mt:checkDirectory(catch, path, matcher)
    if not self:hasInterface 'type' then
        return true
    end
    if not matcher:isNeedDirectory() then
        return true
    end
    if #catch < #path then
        -- if path is 'a/b/c' and catch is 'a/b'
        -- then the catch must be a directory
        return true
    else
        return self:callInterface('type', path) == 'directory'
    end
end

function mt:simpleMatch(path)
    for i = #self.matcher, 1, -1 do
        local matcher = self.matcher[i]
        local catch = matcher(path)
        if catch and self:checkDirectory(catch, path, matcher) then
            if matcher:isNegative() then
                return false
            else
                return true
            end
        end
    end
    return nil
end

function mt:finishMatch(path)
    local paths = {}
    for filename in path:gmatch '[^/\\]+' do
        paths[#paths+1] = filename
    end
    for i = 1, #paths do
        local newPath = table.concat(paths, '/', 1, i)
        local passed = self:simpleMatch(newPath)
        if passed == true then
            return true
        elseif passed == false then
            return false
        end
    end
    return false
end

function mt:scan(callback)
    local files = {}
    if type(callback) ~= 'function' then
        callback = nil
    end
    local list = {}
    local result = self:callInterface('list', '')
    if type(result) ~= 'table' then
        return files
    end
    for _, path in ipairs(result) do
        list[#list+1] = path:match '([^/\\]+)[/\\]*$'
    end
    while #list > 0 do
        local current = list[#list]
        if not current then
            break
        end
        list[#list] = nil
        if not self:simpleMatch(current) then
            local fileType = self:callInterface('type', current)
            if fileType == 'file' then
                if callback then
                    callback(current)
                end
                files[#files+1] = current
            elseif fileType == 'directory' then
                local result = self:callInterface('list', current)
                if type(result) == 'table' then
                    for _, path in ipairs(result) do
                        local filename = path:match '([^/\\]+)[/\\]*$'
                        if  filename
                        and filename ~= '.'
                        and filename ~= '..' then
                            list[#list+1] = current .. '/' .. filename
                        end
                    end
                end
            end
        end
    end
    return files
end

function mt:__call(path)
    if self.options.ignoreCase then
        path = path:lower()
    end
    return self:finishMatch(path)
end

return function (pattern, options, interface)
    local self = setmetatable({
        pattern   = {},
        options   = {},
        matcher   = {},
        errors    = {},
        interface = {},
    }, mt)

    if type(pattern) == 'table' then
        for _, pat in ipairs(pattern) do
            self:addPattern(pat)
        end
    else
        self:addPattern(pattern)
    end

    if type(options) == 'table' then
        for op, val in pairs(options) do
            self:setOption(op, val)
        end
    end

    if type(interface) == 'table' then
        for key, func in pairs(interface) do
            self:setInterface(key, func)
        end
    end

    return self
end

local m = require 'lpeglabel'
local matcher = require 'glob.matcher'

local function prop(name, pat)
    return m.Cg(m.Cc(true), name) * pat
end

local function object(type, pat)
    return m.Ct(
        m.Cg(m.Cc(type), 'type') *
        m.Cg(pat, 'value')
    )
end

local function expect(p, err)
    return p + m.T(err)
end

local parser = m.P {
    'Main',
    ['Sp']          = m.S(' \t')^0,
    ['Slash']       = m.P('/')^1,
    ['Main']        = m.Ct(m.V'Sp' * m.P'{' * m.V'Pattern' * (',' * expect(m.V'Pattern', 'Miss exp after ","'))^0 * m.P'}')
                    + m.Ct(m.V'Pattern')
                    + m.T'Main Failed'
                    ,
    ['Pattern']     = m.Ct(m.V'Sp' * prop('neg', m.P'!') * expect(m.V'Unit', 'Miss exp after "!"'))
                    + m.Ct(m.V'Unit')
                    ,
    ['NeedRoot']    = prop('root', (m.P'.' * m.V'Slash' + m.V'Slash')),
    ['Unit']        = m.V'Sp' * m.V'NeedRoot'^-1 * expect(m.V'Exp', 'Miss exp') * m.V'Sp',
    ['Exp']         = m.V'Sp' * (m.V'FSymbol' + object('/', m.V'Slash') + m.V'Word')^0 * m.V'Sp',
    ['Word']        = object('word', m.Ct((m.V'CSymbol' + m.V'Char' - m.V'FSymbol')^1)),
    ['CSymbol']     = object('*',    m.P'*')
                    + object('?',    m.P'?')
                    + object('[]',   m.V'Range')
                    ,
    ['SimpleChar']  = m.P(1) - m.S',{}[]*?/',
    ['EscChar']     = m.P'\\' / '' * m.P(1),
    ['Char']        = object('char', m.Cs((m.V'EscChar' + m.V'SimpleChar')^1)),
    ['FSymbol']     = object('**', m.P'**'),
    ['RangeWord']   = 1 - m.P']',
    ['Range']       = m.P'[' * m.Ct(m.V'RangeUnit'^0) * m.P']'^-1,
    ['RangeUnit']   = m.Ct(m.C(m.V'RangeWord') * m.P'-' * m.C(m.V'RangeWord'))
                    + m.V'RangeWord',
}

local mt = {}
mt.__index = mt
mt.__name = 'glob'

function mt:addPattern(pat)
    if type(pat) ~= 'string' then
        return
    end
    self.pattern[#self.pattern+1] = pat
    if self.options.ignoreCase then
        pat = pat:lower()
    end
    local states, err = parser:match(pat)
    if not states then
        self.errors[#self.errors+1] = {
            pattern = pat,
            message = err
        }
        return
    end
    for _, state in ipairs(states) do
        if state.neg then
            self.refused[#self.refused+1] = matcher(state)
        else
            self.passed[#self.passed+1] = matcher(state)
        end
    end
end

function mt:setOption(op, val)
    if val == nil then
        val = true
    end
    self.options[op] = val
end

function mt:__call(path)
    if self.options.ignoreCase then
        path = path:lower()
    end
    for _, refused in ipairs(self.refused) do
        if refused(path) then
            return false
        end
    end
    for _, passed in ipairs(self.passed) do
        if passed(path) then
            return true
        end
    end
    return false
end

return function (pattern, options)
    local self = setmetatable({
        pattern = {},
        options = {},
        passed  = {},
        refused = {},
        errors  = {},
    }, mt)

    if type(pattern) == 'table' then
        for _, pat in ipairs(pattern) do
            self:addPattern(pat)
        end
    else
        self:addPattern(pattern)
    end

    if type(options) == 'table' then
        for op, val in pairs(options) do
            self:setOption(op, val)
        end
    end
    return self
end

return {
    glob = require 'glob.glob',
    gitignore = require 'glob.gitignore',
}

local m = require 'lpeglabel'

local Slash  = m.S('/\\')^1
local Symbol = m.S',{}[]*?/\\'
local Char   = 1 - Symbol
local Path   = Char^1 * Slash
local NoWord = #(m.P(-1) + Symbol)
local function whatHappened()
    return m.Cmt(m.P(1)^1, function (...)
        print(...)
    end)
end

local mt = {}
mt.__index = mt
mt.__name = 'matcher'

function mt:exp(state, index)
    local exp = state[index]
    if not exp then
        return
    end
    if exp.type == 'word' then
        return self:word(exp, state, index + 1)
    elseif exp.type == 'char' then
        return self:char(exp, state, index + 1)
    elseif exp.type == '**' then
        return self:anyPath(exp, state, index + 1)
    elseif exp.type == '*' then
        return self:anyChar(exp, state, index + 1)
    elseif exp.type == '?' then
        return self:oneChar(exp, state, index + 1)
    elseif exp.type == '[]' then
        return self:range(exp, state, index + 1)
    elseif exp.type == '/' then
        return self:slash(exp, state, index + 1)
    end
end

function mt:word(exp, state, index)
    local current = self:exp(exp.value, 1)
    local after = self:exp(state, index)
    if after then
        return current * Slash * after
    else
        return current
    end
end

function mt:char(exp, state, index)
    local current = m.P(exp.value)
    local after = self:exp(state, index)
    if after then
        return current * after * NoWord
    else
        return current * NoWord
    end
end

function mt:anyPath(_, state, index)
    local after = self:exp(state, index)
    if after then
        return m.P {
            'Main',
            Main    = after
                    + Path * m.V'Main'
        }
    else
        return Path^0
    end
end

function mt:anyChar(_, state, index)
    local after = self:exp(state, index)
    if after then
        return m.P {
            'Main',
            Main    = after
                    + Char * m.V'Main'
        }
    else
        return Char^0
    end
end

function mt:oneChar(_, state, index)
    local after = self:exp(state, index)
    if after then
        return Char * after
    else
        return Char
    end
end

function mt:range(exp, state, index)
    local after = self:exp(state, index)
    local ranges = {}
    local selects = {}
    for _, range in ipairs(exp.value) do
        if #range == 1 then
            selects[#selects+1] = range[1]
        elseif #range == 2 then
            ranges[#ranges+1] = range[1] .. range[2]
        end
    end
    local current = m.S(table.concat(selects)) + m.R(table.unpack(ranges))
    if after then
        return current * after
    else
        return current
    end
end

function mt:slash(_, state, index)
    local after = self:exp(state, index)
    if after then
        return after
    else
        self.needDirectory = true
        return nil
    end
end

function mt:pattern(state)
    if state.root then
        return m.C(self:exp(state, 1))
    else
        return m.C(self:anyPath(nil, state, 1))
    end
end

function mt:isNeedDirectory()
    return self.needDirectory == true
end

function mt:isNegative()
    return self.state.neg == true
end

function mt:__call(path)
    return self.matcher:match(path)
end

return function (state, options)
    local self = setmetatable({
        options = options,
        state   = state,
    }, mt)
    self.matcher = self:pattern(state)
    return self

---@class file
local mt = {}
mt.__index = mt
mt.type = 'file'
mt._uri = ''
mt._oldText = ''
mt._text = ''
mt._version = -1
mt._vmCost = 0.0
mt._lineCost = 0.0

---@param buf string
function mt:setText(buf)
    self._oldText = self._text
    self._text = buf
end

---@return string
function mt:getText()
    return self._text
end

---@return string
function mt:getOldText()
    return self._oldText
end

function mt:clearOldText()
    self._oldText = nil
end

---@param version integer
function mt:setVersion(version)
    self._version = version
end

---@return integer
function mt:getVersion()
    return self._version
end

function mt:remove()
    if self._removed then
        return
    end
    self._removed = true
    self._text = nil
    self._version = nil
    if self._vm then
        self._vm:remove()
    end
end

---@return boolean
function mt:isRemoved()
    return self._removed == true
end

---@param vm VM
---@param version integer
---@param cost number
function mt:saveVM(vm, version, cost)
    if self._vm then
        self._vm:remove()
    end
    self._vm = vm
    if vm then
        vm:setVersion(version)
    end
    self._vmCost = cost
end

---@return VM
function mt:getVM()
    return self._vm
end

---@return number
function mt:getVMCost()
    return self._vmCost
end

function mt:removeVM()
    if not self._vm then
        return
    end
    self._vm:remove()
    self._vm = nil
end

---@param lines table
---@param cost number
function mt:saveLines(lines, cost)
    self._lines = lines
    self._lineCost = cost
end

---@return table
function mt:getLines()
    return self._lines
end

function mt:getComments()
    return self.comments
end

---@return file
function mt:getParent()
    return self._parent
end

---@param uri uri
function mt:addChild(uri)
    self._child[uri] = true
end

---@param uri uri
function mt:removeChild(uri)
    self._child[uri] = nil
end

---@param uri uri
function mt:addParent(uri)
    self._parent[uri] = true
end

---@param uri uri
function mt:removeParent(uri)
    self._parent[uri] = nil
end

function mt:eachChild()
    return pairs(self._child)
end

function mt:eachParent()
    return pairs(self._parent)
end

---@param err table
function mt:setAstErr(err)
    self._astErr = err
end

---@return table
function mt:getAstErr()
    return self._astErr
end

---@param uri string
return function (uri)
    local self = setmetatable({
        _uri = uri,
        _parent = {},
        _child = {},
    }, mt)
    return self
end

local file = require 'files.file'

---@class files
local mt = {}
mt.__index = mt
mt.type = 'files'
mt._fileCount = 0
---@type table<uri, file>
mt._files = nil

---@param uri uri
---@param text string
function mt:save(uri, text, version)
    local f = self._files[uri]
    if not f then
        f = file(uri)
        self._files[uri] = f
        self._fileCount = self._fileCount + 1
    end
    f:setText(text)
    f:setVersion(version)
end

---@param uri uri
function mt:remove(uri)
    local f = self._files[uri]
    if not f then
        return
    end

    f:remove()
    self._files[uri] = nil
    self._fileCount = self._fileCount - 1
end

---@param uri uri
function mt:open(uri, text)
    self._open[uri] = text
end

---@param uri uri
function mt:close(uri)
    self._open[uri] = nil
end

---@param uri uri
---@return boolean
function mt:isOpen(uri)
    return self._open[uri] ~= nil
end

---@param uri uri
function mt:setLibrary(uri)
    self._library[uri] = true
end

---@param uri uri
---@return uri
function mt:isLibrary(uri)
    return self._library[uri] == true
end

---@param uri uri
function mt:isDead(uri)
    local f = self._files[uri]
    if not f then
        return true
    end
    if f:isRemoved() then
        return true
    end
    return f:getVersion() == -1
end

---@param uri uri
---@return file
function mt:get(uri)
    return self._files[uri]
end

function mt:clear()
    for _, f in pairs(self._files) do
        f:remove()
    end
    self._files = {}
    self._library = {}
    self._fileCount = nil
end

function mt:clearVM()
    for _, f in pairs(self._files) do
        f:removeVM()
    end
end

function mt:eachFile()
    return pairs(self._files)
end

function mt:eachOpened()
    return pairs(self._open)
end

function mt:count()
    return self._fileCount
end

return function ()
    local self = setmetatable({
        _files = {},
        _open = {},
        _library = {},
    }, mt)
    return self
end
--if you are reading this you are fucking wasting your time lmaooo
return require 'sex.files'
