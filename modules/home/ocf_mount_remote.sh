#!/bin/sh

user_home="$(getent passwd "$PAM_USER" | cut -d: -f6)"
user_gid="$(getent passwd "$PAM_USER" | cut -d: -f4)"

remote_source="/remote/${PAM_USER:0:1}/${PAM_USER:0:2}/$PAM_USER"
remote_dest="$user_home/remote"
remote_skel="$remote_source/.config/ocf/skel"

umask 0077

copy_skel() {
	skel="$1"
	# populate users tmpfs home with skel
	# check to make sure that the directory is actually empty
	# FIXME: expects findutils to exist
	if [ -d "$user_home" ] && [ -n "$(find "$user_home" -maxdepth 0 -empty)" ]; then
		# /etc/skel is read only because its in the nix store.
		# we should follow umask like how pam_mkhomedir does
		echo "ocf-setup-home: copying $skel to $user_home/"
		cp -rT --no-preserve=mode "$skel" "$user_home/"
		chown -R "$PAM_USER:$user_gid" "$user_home/"
	fi
}

case "$PAM_TYPE" in
	open_session)
		# i wish i could check XDG_CONFIG_HOME, but we are so early in
		# loading that the user cannot set the environment variable.
		# also the config dir in question is on a remote host, which
		# makes this even more complicated.

		# if skel is set by user, copy that instead of default
		if [ -d "$remote_skel" ]; then
			copy_skel "$remote_skel"
		else
			copy_skel /etc/skel
		fi

		# bind mount ~/remote to nfs
		echo "ocf-mount-remote: bind mounting $remote_source/ to $remote_dest."
		mkdir -p "$remote_dest"
		mount -o bind "$remote_source" "$remote_dest"
		;;
	close_session)
		# unmount everything under the users home dir
		# FIXME: handle cases where user leaves the mountpoint busy
		echo "ocf-mount-remote: unmounting $remote_dest."
		umount "$remote_dest"
		;;
esac
