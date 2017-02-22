#!/usr/bin/env bash

# helper script to put site in 'maintenance mode' so that update work can be done

# get mode argument
MODE=$1

# get absolute path to script (so this works both inside and outside docker)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd | sed 's/\/bin//')"

if [ $MODE = 'on' ];
then
	# check if already in maintenance mode
	if [ ! -e $DIR/public/single_cell/maintenance.html ];
	then
		echo "*** ENABLING MAINTENANCE MODE ***"
		cd $DIR/public/single_cell
		ln -s ../maintenance.html maintenance.html
	else
		echo "ERROR: Site is currently in maintenance, exiting"
	fi
elif [ $MODE = 'off' ];
then
	# check if not in maintenance mode
	if [ -e $DIR/public/single_cell/maintenance.html ];
	then
		echo "*** DISABLING MAINTENANCE MODE ***"
		rm $DIR/public/single_cell/maintenance.html
	else
		echo "ERROR: Site is not currently in maintenance, exiting"
	fi
else
	# print usage
	echo "Illegal argument: $MODE"
	echo "USAGE: bin/enable_maintenance.sh (on,off)"
fi