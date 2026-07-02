#!/bin/sh

user_home="$(getent passwd "$PAM_USER" | cut -d: -f6)"
user_gid="$(getent passwd "$PAM_USER" | cut -d: -f4)"

umask 0077

case "$PAM_TYPE" in
	open_session)
		# populate users tmpfs home with skel
		# check to make sure that the directory is actually empty
		# FIXME: expects findutils to exist
		if [ -d "$user_home" ] && [ -n "$(find "$user_home" -maxdepth 0 -empty)" ]; then
			# /etc/skel is read only because its in the nix store.
			# we should follow umask like how pam_mkhomedir does
			echo "ocf-setup-home: copying /etc/skel to $user_home/"
			cp -rT --no-preserve=mode /etc/skel/ "$user_home/"
			chown -R "$PAM_USER:$user_gid" "$user_home/"
		fi

		# TODO: run desktoprc here
		;;
	close_session)
		;;
esac
