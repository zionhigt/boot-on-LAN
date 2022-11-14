#! /bin/bash

BOOTDIST=`dirname $(readlink -f $0)`

function usage() {
	cat "$BOOTDIST/README.md"
	exit 0
}

if [[ $1 == "-h" ]] || [[ $1 == "--help" ]]; then
	usage
fi

ping_count=1
max_try=5

# GLOBAL functions
####################################################################################
function null() {
	return 0
}

function name_is_missing() {
	echo "Please provide a config name. See boot -h to get more informations about that."
	exit 1
}

function _init_context() {
	src="$HOME/.$1_dist.conf"
	if [ -f "$src" ]; then
		source "$src"
		mac="$1_mac"
		ip="$1_ip"
	else
		echo "$1 doesn't appear as a valid configuration name"
		name_is_missing
	fi
	
}

# CALLBACKS functions
####################################################################################
function _ping() {
	return `ping -c $ping_count ${!ip} | grep received | awk '{print $4;}'`
}

function _ssh() {
	echo -E ''
	echo "Awake !"
	echo "Try ssh connection ..."
	ssh "$ssh_client"
}

function wakeup() {
	sudo wakeonlan "${!mac}"
	echo -E ''
}

function _shutdown() {
	ssh -t "$ssh_client" sudo shutdown -h 0
}


# Master piece
####################################################################################
# connect(
	# $1 try: integer,
	# $2 con: function; To test if awaked, return value -eq ping_count if awaked
	# $3 connected_callback: function; Exec if connected
	# $4 fail_callback: function; Exec if not connected
	# $5 max_try: integer;
# )
function connect() {
	try="$1"
	$2
	con="$?"
	if [[ "$con" == "$ping_count" ]]; then
		$3
	else
		if [ $try -lt $5 ]; then
			load="/"
			if [ $(("$try"%2)) = 0 ]; then
				load="\\" 
			fi
			echo -ne "\rWaiting for boot. Try : $try $load"
			((try=try+1))
			connect "$try" $2 $3 $4 $5
		else
			$4
		fi
	fi
}

function interactive_conf() {
	conf=""
	# MAC
	echo "Host MAC : "
	read _mac_
	conf="$conf$1_mac=$_mac_\n"
	# IP
	echo "Host IP : "
	read _ip_
	conf="$conf$1_ip=$_ip_\n"
	# ssh client
	echo "SSH Host : "
	read _ssh_client_
	conf="$conf""ssh_client=$_ssh_client_\n"
	set 2="`echo $conf`"
}

function write() {
	interactive="$2"
	path="$3"
	if [[ "$interactive" == 1 ]]; then
		conf=""
		interactive_conf $1 conf
	else
		conf_sample=`cat $BOOTDIST/conf.sample`
		conf=${conf_sample//@@NAME@@/$1}
	fi
	echo -e "$conf" > "$path"
	echo "Config file created at $path"
}

function make_conf() {
	path="$HOME/.$1_dist.conf"
	write=1
	if [[ $# -eq 2 ]]; then
		interactive="$2"
	else
		interactive=0
	fi

	if [ -f "$path" ]; then
		echo "That file already exists."
		echo "Do you want to overwrite it ? (y/n) : "
		read overwrite
		if [[ `echo $overwrite | awk '{print tolower($0);}'` != "y" ]]; then
			write=0
		fi
	fi

	if [[ "$write" == 1 ]]; then
		write $1 $interactive $path
	fi
}

function _init() {
	interactive=0
	if [ "$2" != "-i" ]; then
		_name=$2
	else
		if [[ $# -gt 2 ]]; then
			interactive=1
			_name=$3
		else
			name_is_missing
		fi
	fi
	echo "$_name"
	make_conf "$_name" "$interactive"
	exit 0
}

# MAIN
####################################################################################

# shutdown dist helper
if [[ $1 == "shutdown" ]]; then
	if [[ $# -eq 2 ]]; then
		_init_context $2
		connect 1 _ping _shutdown null 1
		exit 0
	else
		name_is_missing
	fi
fi

# init config helper     
if [[ $1 == "init" ]]; then
	if [[ $# -gt 1 ]]; then
		_init $@
	else
		name_is_missing
	fi
fi

if [[ $# -eq 1 ]]; then
	_init_context $1
	# Send WOL request to dist
	connect 1 _ping null wakeup 1
	# Start waiting for dist is available
	connect 1 _ping _ssh null "$max_try"
	echo -E ''
else
	name_is_missing
fi
exit 0