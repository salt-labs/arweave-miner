#!/usr/bin/env bash

##################################################
# Name: entrypoint.sh
# Description: Wrapper for running Arweave Miner
##################################################

#set -x
set -e
set -u
set -o pipefail

export SCRIPT=${0##*/}

export LOGLEVEL="${LOGLEVEL:=INFO}"

# Where the mining rewards are sent to
export ARWEAVE_REWARD_ADDRESS="${ARWEAVE_REWARD_ADDRESS:=UNSET}"

export ARWEAVE_HOME="${ARWEAVE_HOME:=/arweave}"
export ARWEAVE_TOOLS="${ARWEAVE_HOME}/utilities/arweave-tools"

export ARWEAVE_CONFIG_DIR="${ARWEAVE_CONFIG_DIR:=$ARWEAVE_HOME/config}"
export ARWEAVE_DATA_DIR="${ARWEAVE_DATA_DIR:=/data}"

# Provide your own peers or auto-discover the defined number of peers
export ARWEAVE_PEERS="${ARWEAVE_PEERS:=EMPTY}"
export ARWEAVE_PEERS_NUM="${ARWEAVE_PEERS_NUM:=50}"

# Enable sync-only mode for faster weave sync.
export ARWEAVE_SYNC_ENABLED="${ARWEAVE_SYNC_ENABLED:=FALSE}"

export ARWEAVE_MINE_JOBS="${ARWEAVE_MINE_JOBS:=25}"
export ARWEAVE_SYNC_MINE_JOBS="${ARWEAVE_SYNC_MINE_JOBS:=50}"
export ARWEAVE_SYNC_JOBS="${ARWEAVE_SYNC_JOBS:=100}"

export ARWEAVE_SYNC_PERCENT_COMPLETED="${ARWEAVE_SYNC_PERCENT_COMPLETED:=95.00}"

export ARWEAVE_PORT="${ARWEAVE_PORT:=1984}"
export ARWEAVE_LOG_ATTEMPTS="0"

export ARWEAVE_METRICS_LOCAL="http://localhost:${ARWEAVE_PORT}/metrics"
export ARWEAVE_METRICS_LOCAL_INDEX_DATA_SIZE
export ARWEAVE_METRICS_LOCAL_STORAGE_BLOCKS_STORED

export ARWEAVE_METRICS_PUBLIC="http://arweave.net/metrics"
export ARWEAVE_METRICS_PUBLIC_INDEX_DATA_SIZE
export ARWEAVE_METRICS_PUBLIC_STORAGE_BLOCKS_STORED

export RANDOMX_JIT=""
export ERL_EPMD_ADDRESS="127.0.0.1"
export NODE_NAME="arweave@127.0.0.1"

export ARWEAVE_MONITOR_SLEEP="${ARWEAVE_MONITOR_SLEEP:=300}"

#########################
# Functions
#########################

function arweave_metric() {

	local METRIC="${1}"
	local URL="${2}"

	curl \
		--silent \
		--location \
		"${URL}" \
		| grep -E "^${METRIC}" | cut -d ' ' -f2 | cut -d ' ' -f1 | tr -d '[:space:]' || {
			echo "0" | tr -d '[:space:]'
		}

}

function percent() {

	local NUM_1="${1}"
	local NUM_2="${2}"

	echo "scale=2; $NUM_1/$NUM_2 * 100" | bc --mathlib | tr -d '[:space:]' || {
		echo "0" | tr -d '[:space:]'
	}

}

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
	
		${ARWEAVE_HOME}/bin/arweave --"${1}" || { 
			writeLog "ERROR" "Failed to show Arweave version!"
			exit 1
		}
		
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
	writeLog "ERROR" "Arweave Rewards Address is not set!"
	exit 1
fi

if [[ "${ARWEAVE_PEERS:-EMPTY}" == "EMPTY" ]];
then

	writeLog "ERROR" "No peers provided, determining ${ARWEAVE_PEERS_NUM} fastest Arweave peers"
	ARWEAVE_PEERS=$(node "${ARWEAVE_TOOLS}/peers" --number ${ARWEAVE_PEERS_NUM} | tail -n 2 | grep peer)

fi

writeLog "INFO" "Arweave configuration parameters"
writeLog "INFO" "Rewards Address: ${ARWEAVE_REWARD_ADDRESS}"
writeLog "INFO" "Home: ${ARWEAVE_HOME}"
writeLog "INFO" "Config: ${ARWEAVE_CONFIG_DIR}"
writeLog "INFO" "Data: ${ARWEAVE_DATA_DIR}"
writeLog "INFO" "Port: ${ARWEAVE_PORT}"
writeLog "INFO" "Jobs (Sync mode): ${ARWEAVE_SYNC_JOBS}"
writeLog "INFO" "Jobs (Mine mode): ${ARWEAVE_MINE_JOBS}"
writeLog "INFO" "Jobs (Sync and Mine mode): ${ARWEAVE_SYNC_MINE_JOBS}"
writeLog "INFO" "Peers: ${ARWEAVE_PEERS}"

bin/check-nofile || {
	writeLog "ERROR" "Failed to check ulimit"
	exit 1
}

# Determine if a first boot full sync is required
if [[ -f  "${ARWEAVE_DATA_DIR}/sync_complete" ]];
then
	
	writeLog "INFO" "Launching Arweave in Mine mode..."

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

elif [[ "${ARWEAVE_SYNC_ENABLED^^}" == "TRUE" ]];
then

	writeLog "INFO" "Launching Arweave in Sync mode..."
	
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

else

	writeLog "INFO" "Launching Arweave in Sync & Mine mode..."
	
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
			sync_jobs "${ARWEAVE_SYNC_MINE_JOBS}" \
			${ARWEAVE_PEERS}

fi

while true;
do
	
	sleep "${ARWEAVE_MONITOR_SLEEP}"

	if [[ -f  "${ARWEAVE_DATA_DIR}/sync_complete" ]];
	then

		((ARWEAVE_LOG_ATTEMPTS=ARWEAVE_LOG_ATTEMPTS+1))

		writeLog "INFO" "Starting Arweave Monitor (attempt ${ARWEAVE_LOG_ATTEMPTS})"

		node "${ARWEAVE_TOOLS}/monitor" \
			--refresh-interval 60 \
			--refresh-totals 10 \
			--averages-stack 60

	else

		writeLog "INFO" "Obtaining Weave sync status..."

		# Local Index
		ARWEAVE_METRICS_LOCAL_INDEX_DATA_SIZE="$(arweave_metric v2_index_data_size ${ARWEAVE_METRICS_LOCAL})"
		ARWEAVE_METRICS_PUBLIC_INDEX_DATA_SIZE="$(arweave_metric v2_index_data_size ${ARWEAVE_METRICS_PUBLIC})"
		ARWEAVE_METRICS_PERCENT_INDEX_DATA_SIZE="$(percent "${ARWEAVE_METRICS_LOCAL_INDEX_DATA_SIZE:-0}" "${ARWEAVE_METRICS_PUBLIC_INDEX_DATA_SIZE:-0}")"
		ARWEAVE_METRICS_SYNCED_INDEX_DATA_SIZE="$(echo "${ARWEAVE_PERCENT_INDEX_DATA_SIZE:-0} >= ${ARWEAVE_SYNC_PERCENT_COMPLETED:-1}" | bc --mathlib)"

		writeLog "DEBUG" "Local Index Data: ${ARWEAVE_METRICS_LOCAL_INDEX_DATA_SIZE:-ERROR}"
		writeLog "DEBUG" "Public Index Data: ${ARWEAVE_METRICS_PUBLIC_INDEX_DATA_SIZE:-ERROR}"
		writeLog "INFO" "Index Data Size: ${ARWEAVE_METRICS_PERCENT_INDEX_DATA_SIZE:-0}%"
		
		# Storage Blocks		
		ARWEAVE_METRICS_LOCAL_STORAGE_BLOCKS_STORED="$(arweave_metric arweave_storage_blocks_stored ${ARWEAVE_METRICS_LOCAL})"
		ARWEAVE_METRICS_PUBLIC_STORAGE_BLOCKS_STORED="$(arweave_metric arweave_storage_blocks_stored ${ARWEAVE_METRICS_PUBLIC})"
		ARWEAVE_METRICS_PERCENT_STORAGE_BLOCKS_STORED="$(percent "${ARWEAVE_METRICS_LOCAL_STORAGE_BLOCKS_STORED:-0}" "${ARWEAVE_METRICS_PUBLIC_STORAGE_BLOCKS_STORED:-0}" )"
		ARWEAVE_METRICS_SYNCED_STORAGE_BLOCKS_STORED="$(echo "${ARWEAVE_PERCENT_STORAGE_BLOCKS_STORED:-0} >= ${ARWEAVE_SYNC_PERCENT_COMPLETED:-1}" | bc --mathlib)"

		writeLog "DEBUG" "Local Storage Blocks: ${ARWEAVE_METRICS_LOCAL_STORAGE_BLOCKS_STORED:-ERROR}"
		writeLog "DEBUG" "Public Storage Blocks: ${ARWEAVE_METRICS_PUBLIC_STORAGE_BLOCKS_STORED:-ERROR}"
		writeLog "INFO" "Storage Blocks Stored: ${ARWEAVE_METRICS_PERCENT_STORAGE_BLOCKS_STORED:-0}%"

		if [[ ${ARWEAVE_METRICS_SYNCED_INDEX_DATA_SIZE:-0} -eq 1 ]] \
		|| [[ ${ARWEAVE_METRICS_SYNCED_STORAGE_BLOCKS_STORED:-0} -eq 1 ]];
		then

			# Close enough, let's go!

			writeLog "INFO" "Weave sync reached ${ARWEAVE_SYNC_PERCENT_COMPLETED}% complete!" > "${ARWEAVE_DATA_DIR}/sync_complete" || {
				writeLog "ERROR" "Failed to create sync_complete file"
				exit 1	
			}

			writeLog "INFO" "Weave sync reached ${ARWEAVE_SYNC_PERCENT_COMPLETED}% complete, restarting Arweave container in mining mode..."
			
			"${ARWEAVE_HOME}/bin/stop" || exit 0
		
		fi

	fi
	
done
