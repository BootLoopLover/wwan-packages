local fs = require "nixio.fs"
local uci = require "luci.model.uci".cursor()

local function iface_exists(name)
    return name and name ~= "" and fs.access("/sys/class/net/" .. name)
end

local function add_iface_value(opt, seen, name, label)
    if not name or name == "" or seen[name] then return end
    seen[name] = true
    opt:value(name, label or name)
end

local function add_detected_iface_values(opt, include_auto)
    local seen = {}
    if include_auto then
        add_iface_value(opt, seen, "auto", translate("Auto detect"))
    end

    -- Prefer the common OpenWrt interface order so LAN/WAN selection is easy.
    local preferred = {
        "br-lan", "lan1", "lan2", "lan3", "lan4",
        "eth0", "eth1", "eth2", "wan",
        "wwan0", "wwan0_1", "usb0", "rmnet_data0", "qmimux0", "ppp0", "pppoe-wan"
    }
    for _, ifn in ipairs(preferred) do
        if ifn == "br-lan" or ifn:match("^lan") or ifn == "wan" or iface_exists(ifn) then
            add_iface_value(opt, seen, ifn)
        end
    end

    local devs = fs.dir("/sys/class/net")
    if devs then
        local list = {}
        for ifn in devs do
            if ifn ~= "lo" then list[#list + 1] = ifn end
        end
        table.sort(list)
        for _, ifn in ipairs(list) do
            add_iface_value(opt, seen, ifn)
        end
    end
end

local m = Map("nftttl", translate("TTL Settings"))

local support = m:section(SimpleSection)
support.template = "admin_support_info"

local s = m:section(NamedSection, "ttl", "ttl", translate("Settings"))
s.addremove = false
s:option(Flag, "enabled", translate("Enable"))

local val = s:option(Value, "value", translate("TTL / HopLimit Value"))
val.datatype = "range(1,255)"
val.default = 64
val.description = translate("Set IPv4 TTL and IPv6 HopLimit value. Default is 64.")

local ipv4 = s:option(Flag, "ipv4", translate("Enable IPv4 TTL"))
ipv4.default = 1

local ipv6 = s:option(ListValue, "ipv6", translate("IPv6 HopLimit mode"))
ipv6:value("auto", translate("Auto - enable only after IPv6 is up"))
ipv6:value("1", translate("Force enable"))
ipv6:value("0", translate("Disable IPv6 rule"))
ipv6.default = "auto"
ipv6.description = translate("Use Auto if IPv6 fails to come up when TTL is enabled. Auto waits for IPv6 default route/global address before loading safe HopLimit rules.")

local lan = s:option(DynamicList, "lan_ifaces", translate("LAN interfaces"))
lan.default = "auto"
lan.rmempty = false
lan.placeholder = translate("Select LAN interface")
add_detected_iface_values(lan, true)
lan.description = translate("Dropdown selector. Choose Auto for automatic LAN bridge detection, or add specific LAN interfaces/bridge ports. Auto also includes bridge member ports such as lan1/lan2 when detected.")

local lanextra = s:option(DynamicList, "lan_extra_ifaces", translate("Extra wired LAN interfaces"))
lanextra.rmempty = true
lanextra.placeholder = translate("Select extra wired LAN interface")
add_detected_iface_values(lanextra, false)
lanextra.description = translate("Optional dropdown selector. Add physical LAN ports if wired client IPv6 TTL64 is not hit while WiFi works.")

local wan = s:option(DynamicList, "wan_ifaces", translate("WAN/WAN6 interfaces"))
wan.default = "auto"
wan.rmempty = false
wan.placeholder = translate("Select WAN/WAN6 interface")
add_detected_iface_values(wan, true)
wan.description = translate("Dropdown selector. Choose Auto for automatic WAN/WAN6/default-route detection, or add specific WAN interfaces such as wwan0_1, ppp0, usb0 or pppoe-wan.")

local norm = s:option(Flag, "normalize_input", translate("Solid router ping output TTL64"))
norm.default = 1
norm.description = translate("Normalize packets entering WAN too, so router ping output shows ttl=64/hlim=64. Outgoing WAN TTL/HopLimit rewrite remains enabled separately.")

local normlan = s:option(Flag, "normalize_lan_output", translate("Solid client ping output TTL64"))
normlan.default = 1
normlan.description = translate("Normalize LAN client ping output too. IPv6 mode only rewrites ICMPv6 echo-reply so Router Advertisement, Neighbor Discovery and DHCPv6 are not broken.")

local ing = s:option(Flag, "use_ingress", translate("Aggressive LAN ingress mode"))
ing.default = 0
ing.description = translate("Default off. Enable only if egress-only TTL is not enough. Missing devices are skipped automatically.")

local plus = s:option(Flag, "ingress_plus_one", translate("Ingress +1 value"))
plus.default = 1
plus:depends("use_ingress", "1")

local persist = s:option(Flag, "persist_file", translate("Save generated nft file for debug"))
persist.default = 0

local diag = s:option(Flag, "ipv6_lan_diag", translate("Write IPv6/LAN diagnostic log"))
diag.default = 1
diag.description = translate("Writes /tmp/nftttl_diag.log with LAN/WAN devices, bridge ports, IPv6 routes and odhcpd LAN status.")

local c6 = s:option(Flag, "client_ipv6_assist", translate("IPv6 wired client assist"))
c6.default = 1
c6.description = translate("Keeps LAN RA/SLAAC/default-route settings compatible with wired clients that show IPv6 Network is unreachable. Does not modify nft TTL logic.")

local flow = s:option(Flag, "ipv6_flow_safe", translate("Smooth IPv6 re-enable flow"))
flow.default = 1
flow.description = translate("Keeps DHCPv6, link-local, multicast, Router Advertisement and Neighbor Discovery untouched. Recommended when IPv6 disappears after disable/enable or WAN6 renew.")

-- Log & Ping section
local logsec = m:section(SimpleSection)
logsec.template = "nftttl_logbox"

-- add custom actions for ping
local http = require "luci.http"
local sys = require "luci.sys"

function m.handle(action, ...)
    if action == "pingtest" then
        local res = sys.exec("printf 'IPv4 test:\n'; ping -4 -c 4 -W 1 8.8.8.8 2>&1; printf '\nIPv6 test:\n'; ping -6 -c 4 -W 1 2001:4860:4860::8888 2>&1")
        http.prepare_content("text/plain")
        http.write(res)
        return
    elseif action == "log" then
        local log_file = "/tmp/ttl_action.log"
        local data = fs.readfile(log_file) or "No log available."
        http.prepare_content("text/plain")
        http.write(data)
        return
    end
end

function m.on_commit(map)
    local enabled = uci:get("nftttl", "ttl", "enabled") or "0"
    local value   = uci:get("nftttl", "ttl", "value") or "64"
    local log_file = "/tmp/ttl_action.log"

    local function log(msg)
        local f = io.open(log_file, "a")
        if f then
            f:write(os.date("[%H:%M:%S] ") .. msg .. "\\n")
            f:close()
        end
    end

    if not value:match("^%d+$") then value = "64" end

    if enabled == "1" then
        log("TTL enabled (value " .. value .. "), applying via nft-custom-ttl...")
        os.execute("/etc/init.d/nft-custom-ttl enable >/dev/null 2>&1")
        os.execute("/etc/init.d/nft-custom-ttl restart >/dev/null 2>&1")
    else
        log("TTL disabled, stopping nft-custom-ttl...")
        os.execute("/etc/init.d/nft-custom-ttl stop >/dev/null 2>&1")
        os.execute("/etc/init.d/nft-custom-ttl disable >/dev/null 2>&1")
    end
end

return m
