command_not_found_handler() {
	local cmd="$1"
	echo "zsh: command not found: $cmd"
	echo "waddles: if a command is not found, try prepending it with a comma to run it as if it were installed!"
	echo "\t, commandtorun --argument"
}
