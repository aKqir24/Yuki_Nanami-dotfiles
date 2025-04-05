# Programs To Autosart nor restart
instances=("sxhkd" "dunst" "succade")

for process in {0..2}; do
	process_name=${instances[$process]}
	if pgrep -x $process_name >/dev/null; then
		echo "Instance Is Running, Restarting!!" &
		killall $process_name && exec $process_name &
	else
		exec $process_name &
		echo "Instance Is Not Running, Starting!!"
	fi
done
