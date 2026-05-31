# Copyright (C) 2018-2019 Lienol
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-adguardhome
PKG_VERSION:=2.1
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-adguardhome
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=LuCI app for AdGuard Home
	PKG_MAINTAINER:=https://github.com/rufengsuixing/luci-app-adguardhome
	PKGARCH:=all
	DEPENDS:=+!wget&&!curl:wget
endef

define Package/luci-app-adguardhome/description
	LuCI support for AdGuard Home
	Supports OpenWrt 24.10 and earlier (opkg), and OpenWrt 25.12+ (APK).
	Compatible with FW3 and FW4 firewalls.
endef

define Build/Prepare
endef

define Build/Compile
endef

define Package/luci-app-adguardhome/conffiles
/usr/share/AdGuardHome/links.txt
/etc/config/AdGuardHome
endef

define Package/luci-app-adguardhome/install
	# Install Lua controller and model (CBI)
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/model/cbi/AdGuardHome
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/AdGuardHome
	cp -pR ./luasrc/controller/*.lua $(1)/usr/lib/lua/luci/controller/
	cp -pR ./luasrc/model/cbi/AdGuardHome/*.lua $(1)/usr/lib/lua/luci/model/cbi/AdGuardHome/
	cp -pR ./htdocs/luci-static/resources/view/AdGuardHome/*.htm $(1)/usr/lib/lua/luci/view/AdGuardHome/

	# Install htdocs (View templates and static resources for OpenWrt 25.12+)
	$(INSTALL_DIR) $(1)/htdocs/luci-static/resources
	cp -pR ./htdocs/luci-static/resources/* $(1)/htdocs/luci-static/resources/

	# Install root files (init.d, config, scripts)
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_DIR) $(1)/usr/share/AdGuardHome
	cp -pR ./root/etc/init.d/* $(1)/etc/init.d/
	cp -pR ./root/etc/config/* $(1)/etc/config/
	cp -pR ./root/etc/uci-defaults/* $(1)/etc/uci-defaults/
	cp -pR ./root/usr/share/AdGuardHome/* $(1)/usr/share/AdGuardHome/

	# Install i18n
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/i18n
	po2lmo ./po/zh-cn/AdGuardHome.po $(1)/usr/lib/lua/luci/i18n/AdGuardHome.zh-cn.lmo
endef

define Package/luci-app-adguardhome/postinst
#!/bin/sh
	/etc/init.d/AdGuardHome enable >/dev/null 2>&1
	enable=$(uci get AdGuardHome.AdGuardHome.enabled 2>/dev/null)
	if [ "$enable" == "1" ]; then
		/etc/init.d/AdGuardHome reload
	fi
	rm -f /tmp/luci-indexcache
	rm -f /tmp/luci-modulecache/*
exit 0
endef

define Package/luci-app-adguardhome/prerm
#!/bin/sh
	# Support both opkg (OpenWrt <25.12) and APK (OpenWrt >=25.12)
	if [ -z "${IPKG_INSTROOT}" ] && [ -d /etc/init.d ]; then
		 /etc/init.d/AdGuardHome disable 2>/dev/null
		 /etc/init.d/AdGuardHome stop 2>/dev/null
		 uci -q batch <<-EOF >/dev/null 2>&1
		delete ucitrack.@AdGuardHome[-1]
		commit ucitrack
	EOF
	fi
exit 0
endef

$(eval $(call BuildPackage,luci-app-adguardhome))
