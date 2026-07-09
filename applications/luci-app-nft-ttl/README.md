# luci-app-nft-ttl v2.0 fixed8

Adds LuCI tick/dropdown-style interface selectors for:

- LAN interfaces
- Extra wired LAN interfaces
- WAN/WAN6 interfaces

The selector auto-populates common OpenWrt interface names and detected devices from `/sys/class/net`. `auto` remains supported. If `auto` is selected together with manual interfaces, the script uses auto-detection plus the manual interfaces and strips the literal `auto` before generating nftables rules.

# luci-app-nft-ttl v1.8 fixed7

Fixed build with solid TTL64 for router/WiFi/LAN and IPv6 wired client assist.

# luci-app-nft-ttl v1.7 fixed6

OpenWrt LuCI package to set IPv4 TTL and IPv6 HopLimit using nftables/firewall4.

## Fixes

- Router terminal ping output can show solid `ttl=64`.
- WiFi/LAN client IPv4 ping output can show `ttl=64`.
- WiFi/LAN client IPv6 ping output can show `ttl=64` without breaking Router Advertisement, Neighbor Discovery or DHCPv6.
- Auto-detects LAN bridge member ports such as `lan1`, `lan2`, `eth1` when wired LAN traffic does not appear as `br-lan`.
- Writes `/tmp/nftttl_diag.log` for IPv6/LAN troubleshooting.

## Recommended UCI

```sh
uci set nftttl.ttl.enabled='1'
uci set nftttl.ttl.value='64'
uci set nftttl.ttl.ipv4='1'
uci set nftttl.ttl.ipv6='auto'
uci set nftttl.ttl.use_ingress='0'
uci set nftttl.ttl.normalize_input='1'
uci set nftttl.ttl.normalize_lan_output='1'
uci set nftttl.ttl.wan_ifaces='auto'
uci set nftttl.ttl.lan_ifaces='auto'
uci set nftttl.ttl.lan_extra_ifaces=''
uci commit nftttl
/etc/init.d/nft-custom-ttl restart
```

If WiFi IPv6 gets `ttl=64` but wired LAN does not, inspect:

```sh
cat /tmp/nftttl_diag.log
nft list table inet ttlcontrol
ip -6 addr
ip -6 route
```

Then add missing wired port manually if needed:

```sh
uci set nftttl.ttl.lan_extra_ifaces='lan1 lan2 lan3 lan4'
uci commit nftttl
/etc/init.d/nft-custom-ttl restart
```


## v2.0-fixed9 note
Interface selection fields now use compact dropdown-style DynamicList selectors instead of showing the full interface list directly on the page. Add `auto` or one/more interface names, then Save & Apply.
