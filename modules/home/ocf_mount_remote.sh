#!/bin/sh

user_home="$(getent passwd "$PAM_USER" | cut -d: -f6)"
user_gid="$(getent passwd "$PAM_USER" | cut -d: -f4)"

# kerberos ticket is needed to access user's home directory
KRB5CCNAME=/tmp/krb5cc_$(id -u "$PAM_USER")

remote_source="/remote/${PAM_USER:0:1}/${PAM_USER:0:2}/$PAM_USER/"
remote_dest="$user_home/remote/"

# i wish i could check XDG_CONFIG_HOME, but we are so early in
# loading that the user cannot set the environment variable.
# also the config dir in question is on a remote host, which
# makes this even more complicated.
remote_skel="$remote_source/.config/ocf/skel/"
# TODO: add ability to have multiple overlaying skeletons that are copied in
# alphabetical order (skel.d)

umask 0077

# populate users' mounted tmpfs home with skel
copy_skel() {
	# check to make sure that the directory is actually empty
	# FIXME: expects findutils to exist
	if [ ! -d "$user_home" ] || [ ! -n "$(find "$user_home" -maxdepth 0 -empty)" ]; then
		return
	fi

	# if skel is set by user, copy that instead of default

	if su "$PAM_USER" -c "test -d \"$remote_skel\""; then
		echo "ocf-setup-home: copying $remote_skel to $user_home"
		# preserving file mode/perms is intentional
		su "$PAM_USER" -c "cp -rT \"$remote_skel\" \"$user_home\""
	else
		# /etc/skel is read only because its in the nix store.
		# we should follow umask like how pam_mkhomedir does
		echo "ocf-setup-home: copying /etc/skel/ to $user_home"
		cp -rT --no-preserve=mode /etc/skel/ "$user_home"
		chown -R "$PAM_USER:$user_gid" "$user_home"
	fi
}

mount_remote() {
	# bind mount ~/remote to nfs
	echo "ocf-mount-remote: bind mounting $remote_source to $remote_dest."
	mkdir -p "$remote_dest"
	mount -o bind "$remote_source" "$remote_dest"
}

umount_remote() {
	# unmount everything under the users home dir
	# FIXME: handle cases where user leaves the mountpoint busy
	echo "ocf-mount-remote: unmounting $remote_dest."
	umount "$remote_dest"
}

case "$PAM_TYPE" in
	open_session)
		copy_skel
		mount_remote
		;;
	close_session)
		umount_remote
		;;
esac
