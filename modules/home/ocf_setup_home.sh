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

		# bind mount ~/remote to nfs
		# FIXME: check if ocf.nfs.mount.asRemote is true before doing this
		remote_source="/remote/${PAM_USER:0:1}/${PAM_USER:0:2}/$PAM_USER"
		remote_dest="$user_home/remote"
		echo "ocf-setup-home: bind mounting $remote_source/ to $remote_dest."
		mkdir -p "$remote_dest"
		mount -o bind "$remote_source" "$remote_dest"

		# TODO: run desktoprc here
		;;
	close_session)
		# unmount everything under the users home dir
		umount --recursive "$USER_HOME"
		;;
esac
