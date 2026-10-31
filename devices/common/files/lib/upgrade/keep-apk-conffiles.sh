# sysupgrade keeps the conffiles that apk records with a checksum, and a package
# build records only the conffiles it ships. A conffile its service creates at
# run time, such as the login state in tailscale's /etc/tailscale/, is lost on
# every sysupgrade and in every backup. This adds each such path that exists
# and is not the image's own copy; the shipped ones stay with sysupgrade, which
# keeps them only when changed.
keep_apk_conffiles() {
	local list="$1" f

	[ -d /lib/apk/packages ] || return 0
	cat /lib/apk/packages/*.conffiles_static 2>/dev/null | cut -d' ' -f1 >"$list.shipped"
	cat /lib/apk/packages/*.conffiles 2>/dev/null | sort -u | while read -r f; do
		[ -e "$f" ] && find "$f" \( -type f -o -type l \)
	done | while read -r f; do
		cmp -s "$f" "/rom$f" || echo "$f"
	done | grep -vxF -f "$list.shipped" | cat "$list" - | sort -u >"$list.all"
	mv "$list.all" "$list"
	rm -f "$list.shipped"
}

append sysupgrade_init_conffiles keep_apk_conffiles
