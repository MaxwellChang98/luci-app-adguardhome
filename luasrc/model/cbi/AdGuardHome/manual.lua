local m, s, o
local fs = require("nixio.fs")
local uci = require("luci.model.uci").cursor()
local sys = require("luci.sys")
local http = require("luci.http")

function gen_template_config()
	local d = ""
	for cnt in io.lines("/tmp/resolv.conf.auto") do
		local b = string.match(cnt, "^[^#]*nameserver%s+([^%s]+)$")
		if b then
			d = d .. "  - " .. b .. "\n"
		end
	end

	local f = io.open("/usr/share/AdGuardHome/AdGuardHome_template.yaml", "r")
	if not f then
		return ""
	end

	local tbl = {}
	while true do
		local a = f:read("*l")
		if not a then
			break
		end
		if a == "#bootstrap_dns" or a == "#upstream_dns" then
			a = d
		end
		tbl[#tbl + 1] = a
	end
	f:close()

	return table.concat(tbl, "\n")
end

m = Map("AdGuardHome")
m.title = translate("Manual Configuration")
m.description = translate("Edit AdGuardHome YAML configuration directly")
m:section(SimpleSection).template = "AdGuardHome/AdGuardHome_manual_shell"

local configpath = uci:get("AdGuardHome", "AdGuardHome", "configpath")
local binpath = uci:get("AdGuardHome", "AdGuardHome", "binpath")

s = m:section(TypedSection, "AdGuardHome")
s.anonymous = true
s.addremove = false

o = s:option(TextValue, "escconf")
o.rows = 66
o.wrap = "off"
o.rmempty = true
o.cfgvalue = function(self, section)
	return fs.readfile("/tmp/AdGuardHometmpconfig.yaml") or fs.readfile(configpath) or gen_template_config() or ""
end
o.validate = function(self, value)
	fs.writefile("/tmp/AdGuardHometmpconfig.yaml", value:gsub("\r\n", "\n"))
	if fs.access(binpath) then
		if sys.call(binpath .. " -c /tmp/AdGuardHometmpconfig.yaml --check-config 2> /tmp/AdGuardHometest.log") == 0 then
			return value
		end
	else
		return value
	end
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "AdGuardHome", "manual"))
	return nil
end
o.write = function(self, section, value)
	fs.move("/tmp/AdGuardHometmpconfig.yaml", configpath)
end
o.remove = function(self, section, value)
	fs.writefile(configpath, "")
end

o = s:option(DummyValue, "")
o.anonymous = true
o.template = "AdGuardHome/yamleditor"
if not fs.access(binpath) then
	o.description = translate("WARNING: No core binary found, config will not be validated before apply")
end

if fs.access("/tmp/AdGuardHometmpconfig.yaml") then
	local c = fs.readfile("/tmp/AdGuardHometest.log")
	if c and c ~= "" then
		o = s:option(TextValue, "")
		o.readonly = true
		o.rows = 5
		o.rmempty = true
		o.name = ""
		o.cfgvalue = function()
			return fs.readfile("/tmp/AdGuardHometest.log")
		end
	end
end

function m.on_commit(map)
	local ucitracktest = uci:get("AdGuardHome", "AdGuardHome", "ucitracktest")
	if ucitracktest == "1" then
		return
	elseif ucitracktest == "0" then
		luci.sys.exec("/etc/init.d/AdGuardHome reload &")
	else
		fs.writefile("/var/run/AdGlucitest", "")
	end
end

return m
