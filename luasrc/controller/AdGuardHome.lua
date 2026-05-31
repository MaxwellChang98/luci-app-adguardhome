module("luci.controller.AdGuardHome", package.seeall)

local fs = require("nixio.fs")
local http = require("luci.http")
local uci = require("luci.model.uci").cursor()
local json = require("luci.jsonc")

function index()
	entry({"admin", "services", "AdGuardHome"},
		alias("admin", "services", "AdGuardHome", "base"),
		_("AdGuard Home"), 10).dependent = true
	entry({"admin", "services", "AdGuardHome", "base"},
		cbi("AdGuardHome/base", {refresh = 1}),
		_("Base Setting"), 1).leaf = true
	entry({"admin", "services", "AdGuardHome", "log"},
		form("AdGuardHome/log"),
		_("Log"), 2).leaf = true
	entry({"admin", "services", "AdGuardHome", "manual"},
		cbi("AdGuardHome/manual", {refresh = 1}),
		_("Manual Config"), 3).leaf = true
	entry({"admin", "services", "AdGuardHome", "status"},
		call("act_status")).leaf = true
	entry({"admin", "services", "AdGuardHome", "check"},
		call("check_update")).leaf = true
	entry({"admin", "services", "AdGuardHome", "doupdate"},
		call("do_update")).leaf = true
	entry({"admin", "services", "AdGuardHome", "getlog"},
		call("get_log")).leaf = true
	entry({"admin", "services", "AdGuardHome", "dodellog"},
		call("do_dellog")).leaf = true
	entry({"admin", "services", "AdGuardHome", "reloadconfig"},
		call("reload_config")).leaf = true
	entry({"admin", "services", "AdGuardHome", "gettemplateconfig"},
		call("get_template_config")).leaf = true
end

function get_template_config()
	local d = ""
	for cnt in io.lines("/tmp/resolv.conf.auto") do
		local b = string.match(cnt, "^[^#]*nameserver%s+([^%s]+)$")
		if b then
			d = d .. "  - " .. b .. "\n"
		end
	end

	local f = io.open("/usr/share/AdGuardHome/AdGuardHome_template.yaml", "r")
	if not f then
		http.prepare_content("text/plain; charset=utf-8")
		http.write("")
		return
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

	http.prepare_content("text/plain; charset=utf-8")
	http.write(table.concat(tbl, "\n"))
end

function reload_config()
	fs.remove("/tmp/AdGuardHometmpconfig.yaml")
	http.prepare_content("application/json")
	http.write('{}')
end

function act_status()
	local e = {}
	local binpath = uci:get("AdGuardHome", "AdGuardHome", "binpath")
	if binpath and fs.access(binpath) then
		local ret = luci.sys.call("pgrep -f " .. binpath .. " >/dev/null 2>&1")
		e.running = (ret == 0)
	else
		e.running = false
	end

	local redirect_state = fs.readfile("/var/run/AdGredir")
	e.redirect = (redirect_state == "1")

	http.prepare_content("application/json")
	http.write(json.stringify(e))
end

function do_update()
	fs.writefile("/var/run/lucilogpos", "0")
	http.prepare_content("application/json")
	http.write('{}')

	local force = luci.http.formvalue("force")
	local arg = (force == "1") and "force" or ""

	if fs.access("/var/run/update_core") then
		if arg == "force" then
			luci.sys.exec("kill $(pgrep -f /usr/share/AdGuardHome/update_core.sh) 2>/dev/null; " ..
				"sh /usr/share/AdGuardHome/update_core.sh " .. arg .. " >/tmp/AdGuardHome_update.log 2>&1 &")
		end
	else
		luci.sys.exec("sh /usr/share/AdGuardHome/update_core.sh " .. arg .. " >/tmp/AdGuardHome_update.log 2>&1 &")
	end
end

function get_log()
	local logfile = uci:get("AdGuardHome", "AdGuardHome", "logfile")
	if not logfile or logfile == "" then
		http.prepare_content("text/plain; charset=utf-8")
		http.write("no log available\n")
		return
	end

	if logfile == "syslog" then
		if not fs.access("/var/run/AdGuardHomesyslog") then
			luci.sys.exec("/usr/share/AdGuardHome/getsyslog.sh &")
			luci.sys.exec("sleep 1")
		end
		logfile = "/tmp/AdGuardHometmp.log"
		fs.writefile("/var/run/AdGuardHomesyslog", "1")
	elseif not fs.access(logfile) then
		http.prepare_content("text/plain; charset=utf-8")
		http.write("")
		return
	end

	http.prepare_content("text/plain; charset=utf-8")

	local fdp = 0
	if fs.access("/var/run/lucilogreload") then
		fdp = 0
		fs.remove("/var/run/lucilogreload")
	else
		local pos = fs.readfile("/var/run/lucilogpos")
		fdp = tonumber(pos) or 0
	end

	local f = io.open(logfile, "r")
	if not f then
		http.write("")
		return
	end

	f:seek("set", fdp)
	local a = f:read(2048000) or ""
	local new_pos = f:seek()
	f:close()

	fs.writefile("/var/run/lucilogpos", tostring(new_pos))
	http.write(a)
end

function do_dellog()
	local logfile = uci:get("AdGuardHome", "AdGuardHome", "logfile")
	if logfile and logfile ~= "" and logfile ~= "syslog" then
		fs.writefile(logfile, "")
	end
	http.prepare_content("application/json")
	http.write('{}')
end

function check_update()
	http.prepare_content("text/plain; charset=utf-8")

	local fdp = 0
	local pos = fs.readfile("/var/run/lucilogpos")
	fdp = tonumber(pos) or 0

	local f = io.open("/tmp/AdGuardHome_update.log", "r")
	if not f then
		http.write("")
		return
	end

	f:seek("set", fdp)
	local a = f:read(2048000) or ""
	local new_pos = f:seek()
	f:close()

	fs.writefile("/var/run/lucilogpos", tostring(new_pos))

	if fs.access("/var/run/update_core") then
		http.write(a)
	else
		http.write(a .. "\0")
	end
end
