#!/usr/bin/env bash

##################################################
# Name: entrypoint.sh
# Description: Wrapper for running Arweave Miner
##################################################

set -e
set -u
set -o pipefail

export SCRIPT=${0##*/}

export LOGLEVEL="${LOGLEVEL:=INFO}"

export ARWEAVE_HOME="${ARWEAVE_HOME:=/arweave}"
export ARWEAVE_TOOLS="${ARWEAVE_HOME}/utilities/arweave-tools"
export ARWEAVE_REWARD_ADDRESS="${ARWEAVE_REWARD_ADDRESS:=UNSET}"
export ARWEAVE_PEERS="${ARWEAVE_PEERS:=EMPTY}"
export ARWEAVE_CONFIG_DIR="${ARWEAVE_CONFIG_DIR:=$ARWEAVE_HOME/config}"
export ARWEAVE_DATA_DIR="${ARWEAVE_DATA_DIR:=/data}"
export ARWEAVE_SYNC_JOBS="${ARWEAVE_SYNC_JOBS:=80}"
export ARWEAVE_MINE_JOBS="${ARWEAVE_SYNC_JOBS:=3}"
export ARWEAVE_PORT="${ARWEAVE_PORT:=1984}"
export ARWEAVE_LOG_ATTEMPTS="0"

export RANDOMX_JIT=""
export ERL_EPMD_ADDRESS="127.0.0.1"
export NODE_NAME="arweave@127.0.0.1"

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
checkVarEmpty "ARWEAVE_REWARD_ADDRESS" "Arweave Rewards Address" && exit 1

if [[ "${ARWEAVE_REWARD_ADDRESS^^}" == "UNSET" ]];
then
	echo "Arweave Rewards Address is not set!"
	exit 1
fi

echo -e "Determining fastest Arweave peers"

ARWEAVE_PEERS=$(node "${ARWEAVE_TOOLS}/peers" --number 50 | tail -n 2 | grep peer)
if [[ "${ARWEAVE_PEERS:-EMPTY}" == "EMPTY" ]];
then
	writeLog "ERROR" "Failed to determine fastest peers, using defaults"
	ARWEAVE_PEERS="peer 188.166.200.45 peer 188.166.192.169 peer 163.47.11.64 peer 139.59.51.59 peer 138.197.232.192"
fi

echo -e "Arweave configuration parameters"

echo -e "\tRewards Address: ${ARWEAVE_REWARD_ADDRESS}"
echo -e "\tHome: ${ARWEAVE_HOME}"
echo -e "\tConfig: ${ARWEAVE_CONFIG_DIR}"
echo -e "\tData: ${ARWEAVE_DATA_DIR}"
echo -e "\tPort: ${ARWEAVE_PORT}"
echo -e "\tSync Jobs: ${ARWEAVE_SYNC_JOBS}"
echo -e "\tPeers: ${ARWEAVE_PEERS}"

bin/check-nofile || {
	writeLog "ERROR" "Failed to check ulimit"
	exit 1
}

# Determine if a first boot full sync is required
if [[ -f  "${ARWEAVE_DATA_DIR}/sync_complete" ]];
then
	
	echo -e "Launching Arweave in Mining mode..."

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
			mine \
			mining_addr "${ARWEAVE_REWARD_ADDRESS}" \
			data_dir "${ARWEAVE_DATA_DIR}" \
			sync_jobs "${ARWEAVE_MINE_JOBS}" \
			${ARWEAVE_PEERS}

else
	
	echo -e "Launching Arweave in Syncing mode..."
	
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
			${ARWEAVE_PEERS}

fi

while true;
do

	sleep 60

	if [[ -f  "${ARWEAVE_DATA_DIR}/sync_complete" ]];
	then

		((ARWEAVE_LOG_ATTEMPTS=ARWEAVE_LOG_ATTEMPTS+1))

		echo -e "Following Arweave logs (attempt ${ARWEAVE_LOG_ATTEMPTS})"

		#"${ARWEAVE_HOME}/bin/logs" -f
		node "${ARWEAVE_TOOLS}/monitor" \
			--refresh-interval 60 \
			--refresh-totals 10 \
			--averages-stack 60

	else

		echo -e "Waiting for weave sync to complete..."

		# TODO: Complete this

		# Check sync status
		#curl http://localhost:1984/metrics	
		#v2_index_data_size
		#arweave_storage_blocks_stored

		#curl http://arweave.net/metrics
		#v2_index_data_size
		#arweave_storage_blocks_stored
        
  		# Percentage of blocks stored      
		# current / total * 100 %

		#touch "${ARWEAVE_DATA_DIR}/sync_complete" || {
		#	writeLog "ERROR" "Failed to create sync_complete file"
		#	exit 1	
		#}


	fi

done
