#!/bin/sh

user_home="$(getent passwd "$PAM_USER" | cut -d: -f6)"
user_gid="$(getent passwd "$PAM_USER" | cut -d: -f4)"

remote_source="/remote/${PAM_USER:0:1}/${PAM_USER:0:2}/$PAM_USER"
remote_dest="$user_home/remote"

umask 0077

case "$PAM_TYPE" in
	open_session)
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
