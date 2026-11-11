include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-nft-ttl
PKG_VERSION:=2.1
PKG_RELEASE:=1

PKG_MAINTAINER:=sopek <www.khiman@gmail.com>
PKG_LICENSE:=GPL-3.0

LUCI_TITLE:=TTL / IPv6 HopLimit Changer
LUCI_DESCRIPTION:=LuCI app to set IPv4 TTL and IPv6 HopLimit using nftables/firewall4.
LUCI_DEPENDS:=+luci +nftables +jsonfilter +ubus +ip-full

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=$(LUCI_TITLE)
	PKGARCH:=all
	DEPENDS:=$(LUCI_DEPENDS)
endef

define Package/$(PKG_NAME)/description
	$(LUCI_DESCRIPTION)
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/etc/hotplug.d/iface
	$(INSTALL_DIR) $(1)/etc/nftables.d
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DIR) $(1)/www/luci-static/resources/TTLcontrol
	$(CP) ./files/* $(1)/
	$(INSTALL_BIN) ./files/etc/init.d/nft-custom-ttl $(1)/etc/init.d/nft-custom-ttl
	$(INSTALL_BIN) ./files/etc/hotplug.d/iface/95-nftttl $(1)/etc/hotplug.d/iface/95-nftttl
	$(INSTALL_BIN) ./files/etc/uci-defaults/99-app-ttl $(1)/etc/uci-defaults/99-app-ttl
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
mkdir -p /etc/nftables.d /tmp
chmod +x /etc/init.d/nft-custom-ttl /etc/hotplug.d/iface/95-nftttl 2>/dev/null
/etc/init.d/nft-custom-ttl enable >/dev/null 2>&1
/etc/init.d/nft-custom-ttl restart >/dev/null 2>&1
exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/nft-custom-ttl stop >/dev/null 2>&1
/etc/init.d/nft-custom-ttl disable >/dev/null 2>&1
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
