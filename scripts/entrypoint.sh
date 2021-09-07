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
export LOGLEVEL="$LOGLEVEL:=INFO}"

# Arweave
export ARWEAVE_HOME="${ARWEAVE_HOME:=/arweave}"
export ARWEAVE_REWARDS_ADDRESS="${ARWEAVE_REWARDS_ADDRESS:=UNSET}"
export ARWEAVE_PEERS="peer 188.166.200.45 peer 188.166.192.169 peer 163.47.11.64 peer 139.59.51.59 peer 138.197.232.192"
export ARWEAVE_CONFIG_DIR="${ARWEAVE_CONFIG_DIR:=$ARWEAVE_HOME/config}"
export ARWEAVE_DATA_DIR="${ARWEAVE_DATA_DIR:=/data}"
export ARWEAVE_SYNC_JOBS="${ARWEAVE_SYNC_JOBS:=3}"

export RANDOMX_JIT=""
export ERL_EPMD_ADDRESS="127.0.0.1"
export NODE_NAME="arweave@127.0.0.1"

# Arweave Utilities
export ARWEAVE_TOOLS_REPO="https://github.com/francesco-adamo/arweave-tools"

export ARWEAVE_PROCESS_NAMES=(
	beam.smp
)

#########################
# Pre-reqs
#########################

# Import the required functions
# shellcheck source=functions.sh
source "/scripts/functions.sh" || {
	echo "Failed to source dependant functions!"
	exit 1
}

checkLogLevel "${LOGLEVEL}" || {
	writeLog "ERROR" "Failed to check the log level"
	exit 1
}

checkReqs || {
	writeLog "ERROR" "Failed to check all requirements"
	exit 1
}

if [[ ${1-} ]];
then
	PARAMS="$1"
else
	PARAMS="none"
fi

case "${PARAMS}" in

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

if [[ "${ARWEAVE_REWARDS_ADDRESS^^}" == "UNSET" ]];
then
	echo "Arweave Rewards Address is not set!"
	exit 1
fi

echo -e "Cloning Arweare tools"

git clone "${ARWEAVE_TOOLS_REPO}" "${ARWEAVE_HOME}/utilities/arweave-tools" || {
	writeLog "WARNING" "Failed to clone latest Arweave Tools repository"
}

echo -e "Arweave configuration parameters"

echo -e "\tRewards Address: ${ARWEAVE_REWARDS_ADDRESS}"
echo -e "\tHome: ${ARWEAVE_HOME}"
echo -e "\tPeers: ${ARWEAVE_PEERS}"
echo -e "\tConfig: ${ARWEAVE_CONFIG_DIR}"
echo -e "\tData: ${ARWEAVE_DATA_DIR}"
echo -e "\tSync Jobs: ${ARWEAVE_SYNC_JOBS}"

bin/check-nofile || {
	writeLog "ERROR" "Failed to check ulimit"
	exit 1
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
		${ARWEAVE_PEERS}

while sleep 60;
do

	for ARWEAVE_PROCESS in ${ARWEAVE_PROCESS_NAMES[*]};
	do

		echo -e "Checking ${ARWEAVE_PROCESS} status..."

		ps aux | grep "${ARWEAVE_PROCESS}" | grep -q -v grep
		ARWEAVE_PROCESS_STATUS=$?

		if [[ ${ARWEAVE_PROCESS_STATUS} -ne 0 ]]; 
		then
			echo "Process ${ARWEAVE_PROCESS} has failed, exiting!"
			exit 1
		fi

	done

done
