#!/usr/bin/env bash

##################################################
# Name: entrypoint.sh
# Description: Wrapper for running Arweave Miner
##################################################

#set -x
set -e
set -u
set -o pipefail

shopt -s inherit_errexit

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
export ARWEAVE_PEERS_LOC="https://arweave.net/peers"

# Enable sync-only mode for faster weave sync.
export ARWEAVE_SYNC_ENABLED="${ARWEAVE_SYNC_ENABLED:=FALSE}"

export ARWEAVE_MINE_JOBS="${ARWEAVE_MINE_JOBS:=25}"
export ARWEAVE_SYNC_MINE_JOBS="${ARWEAVE_SYNC_MINE_JOBS:=50}"
export ARWEAVE_SYNC_JOBS="${ARWEAVE_SYNC_JOBS:=100}"

export ARWEAVE_SYNC_PERCENT_COMPLETED="${ARWEAVE_SYNC_PERCENT_COMPLETED:=95.00}"

export ARWEAVE_PORT="${ARWEAVE_PORT:=1984}"
export ARWEAVE_MONITOR_ATTEMPTS="0"
export ARWEAVE_LOG_ATTEMPTS="0"

export ARWEAVE_METRICS_LOCAL="http://localhost:${ARWEAVE_PORT}/metrics"
export ARWEAVE_METRICS_LOCAL_INDEX_DATA_SIZE
export ARWEAVE_METRICS_LOCAL_STORAGE_BLOCKS_STORED

export ARWEAVE_METRICS_PUBLIC="https://arweave.net/metrics"
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
		| grep -E "^${METRIC} " | cut -d ' ' -f2 | tr -d '[:space:]' || {
			echo "0"
		}

}

function percent() {

	local NUM_1="${1}"
	local NUM_2="${2}"

	echo "scale=2; $NUM_1/$NUM_2 * 100" | bc --mathlib | tr -d '[:space:]' || {
		echo "0"
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
if [[ "${ARWEAVE_REWARD_ADDRESS^^}" == "UNSET" ]];
then
	writeLog "ERROR" "Unable to continue as the Arweave Rewards Address is not set!"
	exit 1
fi

if [[ "${ARWEAVE_PEERS:-EMPTY}" == "EMPTY" ]];
then

	writeLog "ERROR" "No peers provided, determining the ${ARWEAVE_PEERS_NUM} fastest Arweave peers"

	# Get the fastest peers
	node "${ARWEAVE_TOOLS}/peers" --number ${ARWEAVE_PEERS_NUM} | tail -n 2 | grep peer > "${ARWEAVE_HOME}/peers.txt" || {

		writeLog "ERROR" "Failed to determine the fastest Arweave peers"
		
		# Blank the file if there was an error
		echo "" > "${ARWEAVE_HOME}/peers.txt"

	}

	# In-case the peers file is empty, grab some defaults.
	if [[ ! -s "${ARWEAVE_HOME}/peers.txt" ]];
	then

		writeLog "INFO" "No peers found, determining default peers"
		
		curl --silent --location "${ARWEAVE_PEERS_LOC}" | jq -jr '.[]|., "\n"' >> "${ARWEAVE_HOME}/peers.txt" || {
		
			writeLog "ERROR" "Failed to download Arweave peers default list"

		}
		sed -i 's/\(^.*$\)/peer \1/' "${ARWEAVE_HOME}/peers.txt" || true
	
	fi

	# Start from zero
	LINE_COUNTER=0
	
	# Read every line of the file
	while IFS="" read -r PEER || [ -n "${PEER}" ]
	do

		LINE_COUNTER=$((LINE_COUNTER+1))

		ARWEAVE_PEERS="${ARWEAVE_PEERS} ${PEER}"

		# If the desired number of peers has been reached, end the loop.
		if [[ "${LINE_COUNTER}" -eq "${ARWEAVE_PEERS_NUM}" ]];
		then
			break
		fi

	done < "${ARWEAVE_HOME}/peers.txt"

	if [[ "${ARWEAVE_PEERS:-EMPTY}" == "EMPTY" ]];
	then

		# If still no peers, explode...
		writeLog "ERROR" "Failed to setup Arweave peers, do you have connectivity to arweave.org?"
		exit 1
	
	fi
	
fi

writeLog "INFO" "Arweave configuration parameters"
writeLog "INFO" "Rewards Address: ${ARWEAVE_REWARD_ADDRESS}"
writeLog "INFO" "Home: ${ARWEAVE_HOME}"
writeLog "INFO" "Config: ${ARWEAVE_CONFIG_DIR}"
writeLog "INFO" "Data: ${ARWEAVE_DATA_DIR}"
writeLog "INFO" "Port: ${ARWEAVE_PORT}"
writeLog "INFO" "Jobs (Sync): ${ARWEAVE_SYNC_JOBS}"
writeLog "INFO" "Jobs (Sync and Mine): ${ARWEAVE_SYNC_MINE_JOBS}"
writeLog "INFO" "Jobs (Mine): ${ARWEAVE_MINE_JOBS}"
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
	
	((ARWEAVE_MONITOR_ATTEMPTS=ARWEAVE_MONITOR_ATTEMPTS+1))
	
	writeLog "INFO" "Checking weave sync status, loop ${ARWEAVE_MONITOR_ATTEMPTS}"
	
	sleep "${ARWEAVE_MONITOR_SLEEP:-60}"

	if [[ -f  "${ARWEAVE_DATA_DIR}/sync_complete" ]];
	then

		((ARWEAVE_LOG_ATTEMPTS=ARWEAVE_LOG_ATTEMPTS+1))

		writeLog "INFO" "Starting Arweave Monitor (attempt ${ARWEAVE_LOG_ATTEMPTS})"

		node "${ARWEAVE_TOOLS}/monitor" \
			--refresh-interval 60 \
			--refresh-totals 10 \
			--averages-stack 60

	else

		###############
		# Local Index
		###############
		
		ARWEAVE_METRICS_LOCAL_INDEX_DATA_SIZE="$(arweave_metric v2_index_data_size ${ARWEAVE_METRICS_LOCAL})"
		ARWEAVE_METRICS_PUBLIC_INDEX_DATA_SIZE="$(arweave_metric v2_index_data_size ${ARWEAVE_METRICS_PUBLIC})"
		ARWEAVE_METRICS_PERCENT_INDEX_DATA_SIZE="$(percent "${ARWEAVE_METRICS_LOCAL_INDEX_DATA_SIZE:-0}" "${ARWEAVE_METRICS_PUBLIC_INDEX_DATA_SIZE:-0}")"
		ARWEAVE_METRICS_SYNCED_INDEX_DATA_SIZE="$(echo "${ARWEAVE_METRICS_PERCENT_INDEX_DATA_SIZE:-0} >= ${ARWEAVE_SYNC_PERCENT_COMPLETED:-1}" | bc --mathlib)"

		writeLog "DEBUG" "\tLocal Index Data: ${ARWEAVE_METRICS_LOCAL_INDEX_DATA_SIZE:-ERROR}"
		writeLog "DEBUG" "\tPublic Index Data: ${ARWEAVE_METRICS_PUBLIC_INDEX_DATA_SIZE:-ERROR}"
		writeLog "INFO" "\tIndex Data Size: ${ARWEAVE_METRICS_PERCENT_INDEX_DATA_SIZE:-0}%"
		
		###############
		# Storage Blocks		
		###############
		
		ARWEAVE_METRICS_LOCAL_STORAGE_BLOCKS_STORED="$(arweave_metric arweave_storage_blocks_stored ${ARWEAVE_METRICS_LOCAL})"
		ARWEAVE_METRICS_PUBLIC_STORAGE_BLOCKS_STORED="$(arweave_metric arweave_storage_blocks_stored ${ARWEAVE_METRICS_PUBLIC})"
		ARWEAVE_METRICS_PERCENT_STORAGE_BLOCKS_STORED="$(percent "${ARWEAVE_METRICS_LOCAL_STORAGE_BLOCKS_STORED:-0}" "${ARWEAVE_METRICS_PUBLIC_STORAGE_BLOCKS_STORED:-0}" )"
		ARWEAVE_METRICS_SYNCED_STORAGE_BLOCKS_STORED="$(echo "${ARWEAVE_METRICS_PERCENT_STORAGE_BLOCKS_STORED:-0} >= ${ARWEAVE_SYNC_PERCENT_COMPLETED:-1}" | bc --mathlib)"

		writeLog "DEBUG" "\tLocal Storage Blocks: ${ARWEAVE_METRICS_LOCAL_STORAGE_BLOCKS_STORED:-ERROR}"
		writeLog "DEBUG" "\tPublic Storage Blocks: ${ARWEAVE_METRICS_PUBLIC_STORAGE_BLOCKS_STORED:-ERROR}"
		writeLog "INFO" "\tStorage Blocks Stored: ${ARWEAVE_METRICS_PERCENT_STORAGE_BLOCKS_STORED:-0}%"

		###############
		# Mined Blocks
		###############

		# TODO: Check logs for last block mined
		writeLog "INFO" "\tLast Block Mined: ${ARWEAVE_LAST_BLOCK_MINED:-TODO}"

		###############
		# Weave Status
		###############
		
		writeLog "DEBUG" "Synced Index: ${ARWEAVE_METRICS_SYNCED_INDEX_DATA_SIZE:-ERROR}"
		writeLog "DEBUG" "Synced Blocks: ${ARWEAVE_METRICS_SYNCED_STORAGE_BLOCKS_STORED:-ERROR}"

		if [[ "${ARWEAVE_METRICS_SYNCED_INDEX_DATA_SIZE:-0}" -eq 1 ]] \
		|| [[ "${ARWEAVE_METRICS_SYNCED_STORAGE_BLOCKS_STORED:-0}" -eq 1 ]];
		then

			# Close enough, let's go!

			writeLog "INFO" "Weave sync reached ${ARWEAVE_SYNC_PERCENT_COMPLETED}% complete!" > "${ARWEAVE_DATA_DIR}/sync_complete" || {
				writeLog "ERROR" "Failed to create sync_complete file"
				exit 1	
			}

			writeLog "INFO" "Weave sync reached ${ARWEAVE_SYNC_PERCENT_COMPLETED}% complete, restarting Arweave container in mining mode..."
			
			"${ARWEAVE_HOME}/bin/stop" || exit 1

			sleep 30

			exit 0

		else
		
			writeLog "INFO" "Weave sync in progress..."
		
		fi

	fi

	writeLog "DEBUG" "End checking weave sync status, loop ${ARWEAVE_MONITOR_ATTEMPTS}"
	
done
