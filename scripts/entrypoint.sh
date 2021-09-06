#!/usr/bin/env bash

##################################################
# Name: entrypoint.sh
# Description: Wrapper for running Arweave Miner
##################################################

set -e
set -u
set -o pipefail

# Get a script name for the logs
export SCRIPT=${0##*/}

# Common
export LOGLEVEL="${INPUT_LOGLEVEL:=INFO}"

# Arweave
export ARWEAVE_HOME="${ARWEAVE_HOME:=/arweave}"
export ARWEAVE_REWARDS_ADDRESS="${ARWEAVE_REWARDS_ADDRESS}"
export ARWEAVE_PEERS="peer 188.166.200.45 peer 188.166.192.169 peer 163.47.11.64 peer 139.59.51.59 peer 138.197.232.192"
export ARWEAVE_CONFIG_DIR="${ARWEAVE_CONFIG_DIR:=$ARWEAVE_HOME/config}"
export ARWEAVE_DATA_DIR="${ARWEAVE_DATA_DIR:=/data}"
export ARWEAVE_SYNC_JOBS="${ARWEAVE_SYNC_JOBS:=3}"

export RANDOMX_JIT=
export ERL_EPMD_ADDRESS=127.0.0.1
export NODE_NAME='arweave@127.0.0.1'

# Arweave Utilities
export ARWEAVE_TOOLS_REPO="https://github.com/francesco-adamo/arweave-tools"

#########################
# Pre-reqs
#########################

# Import the required functions
# shellcheck source=functions.sh
source "/scripts/functions.sh" || { echo "Failed to source dependant functions!" ; exit 1 ; }

checkLogLevel "${LOGLEVEL}" || { writeLog "ERROR" "Failed to check the log level" ; exit 1 ; }

checkReqs || { writeLog "ERROR" "Failed to check all requirements" ; exit 1 ; }

# Used if the CI is running a simple test
case "${1,,}" in

	version )
		${ARWEAVE_HOME}/bin/arweave --"${1}" || { writeLog "ERROR" "Failed to show Arweave version!" ; exit 1 ; }
		exit 0
	;;

	*help | *usage )
		usage
		exit 0
	;;

esac

#########################
# Main
#########################

# Enable job control
set -m

# Check the minimum required variables are populated
checkVarEmpty "ARWEAVE_REWARDS_ADDRESS" "Arweave Rewards Address" && exit 1

git clone "${ARWEAVE_TOOLS_REPO}" "${ARWEAVE_HOME}/utilities/arweave-tools" || {
	writeLog "WARNING" "Failed to clone latest Arweave Tools repository"
}

echo -e "Launching Erlang Virtual Machine..."

"${ARWEAVE_HOME}/bin/arweave" \
	daemon \
	+Ktrue \
	+A20 \
	+SDio20 \
	+sbwtvery_long \
	+sbwtdcpuvery_long \
	+sbwtdiovery_long \
	+swtvery_low  \
	+swtdcpuvery_low \
	+swtdiovery_low \
	+Bi \
	-run \
	ar \
	main \
		data_dir "${ARWEAVE_DATA_DIR}" \
		sync_jobs "${ARWEAVE_SYNC_JOBS}" \
		mine \
		mining_addr "${ARWEAVE_REWARDS_ADDRESS}" \
		"${ARWEAVE_PEERS}"

#echo -e "Tailing logs"

#"${ARWEAVE_HOME}/bin/logs" -f

while sleep 60; do

	echo -e "Checking Arweave status..."

	#ps aux | grep my_first_process | grep -q -v grep
	#PROCESS_1_STATUS=$?

	#ps aux | grep my_second_process | grep -q -v grep
	#PROCESS_2_STATUS=$?

	# If the greps above find anything, they exit with 0 status
	# If they are not both 0, then something is wrong
	#if [[ ${PROCESS_1_STATUS} -ne 0 ]] || [[ ${PROCESS_2_STATUS} -ne 0 ]]; 
	#then
	#  echo "One of the processes has failed!"
	#  exit 1
	#fi

done
