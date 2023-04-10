#!/bin/bash 

## ###############
## Helpers
## ###############
function log() {
    echo -e "$( date ) - $@"
}

## ###############
## Configs
## ###############
# pushover_token=$PUSHOVER_TOKEN
# pushover_user=$PUSHOVER_USER
diskspace_path="/"
# node_nickname="$NODE_NICKNAME"

log "Running daily briefing for $node_nickname"

## ###############
## Hardware stats
## ###############
get_disk_used() {
    df -h $diskspace_path | grep -Po "\d+%"
}

## ###############
## Prometheus helpers
## ###############
query_prometheus() {
    query=$1
    date_filter=${2:-$(date +%s)}
    # response=$( docker exec rocketpool_grafana wget -q -O - http://prometheus:9091/api/v1/query\?query\=$query\&time\=$date_filter )
    response=$( curl -s http://prometheus:9091/api/v1/query\?query\=$query\&time\=$date_filter )
    echo $response
}

## ###############
## Update helpers
## ###############
query_prometheus_for_rp_updates() {
    echo $( query_prometheus rocketpool_version_update ) | grep -Po '\d*(?="\]\}\]\}\})'
}
query_prometheus_for_os_updates() {
    echo $( query_prometheus os_upgrades_pending ) | grep -Po '\d*(?="\]\}\]\}\})'
}

## ###############
## Balance helpers
## ###############
get_balance_at() {
    timestamp=${1:-$( date +%s )}
    response=$( query_prometheus "rocketpool_node_beacon_share%7Bjob%3D%22rocketpool%22%7D%20-%20rocketpool_node_deposited_eth%7Bjob%3D%22rocketpool%22%7D" $timestamp )
    balance_from_response=$( echo $response | grep -Po '\d*\.\d*(?="\]\}\]\}\})' )
    echo $balance_from_response
}
get_rpl_collateral_ratio() {
    response=$( query_prometheus "rocketpool_node_total_staked_rpl%7Bjob%3D%22rocketpool%22%7D%20%2A%20rocketpool_rpl_rpl_price%7Bjob%3D%22rocketpool%22%7D%20%2F%20rocketpool_node_deposited_eth%7Bjob%3D%22rocketpool%22%7D" )
    rpl_collateral_decimal=$( echo $response | grep -Po '\d*\.\d*(?="\]\}\]\}\})' )
    unrounded=$( bc -l <<< "$rpl_collateral_decimal * 100" )
    rounded_no_decimals=$( echo $unrounded | grep -Po '\d*(?=\.)' )
    echo $rounded_no_decimals
}

balance_today=$( get_balance_at $(date +%s) )
balance_yesterday=$( get_balance_at $( date -d "$date -1 days" +"%s" ) )
balance_delta=$( bc -l <<< "$balance_today-$balance_yesterday" )
balance_delta_rounded=$( echo $balance_delta | grep -Po '\d*\.\d{4}' )

## ###############
## Validator stats
## ###############
get_1d_apr() {
    response=$( query_prometheus "%28%28rocketpool_node_beacon_share%7Bjob%3D%22rocketpool%22%7D%29%20-%20%28rocketpool_node_beacon_share%7Bjob%3D%22rocketpool%22%7D%20offset%201d%20%21%3D%200%29%29%20%2F%20rocketpool_node_deposited_eth%7Bjob%3D%22rocketpool%22%7D%20%2A%20365" )
    apr_as_decimal=$( echo $response | grep -Po '\d*\.\d*(?="\]\}\]\}\})' )
    apr_as_percentage=$( bc -l <<< "$apr_as_decimal*100" )
    apr_rounded_to_2_decimals=$( echo $apr_as_percentage | grep -Po '\d*\.\d{0,2}' )
    echo $apr_rounded_to_2_decimals
}
get_upcoming_proposals() {
    response=$( query_prometheus rocketpool_beacon_upcoming_proposals )
    amount_upcoming=$( echo $response | grep -Po '\d*(?="\]\}\]\}\})' )
    echo $amount_upcoming
}
get_upcoming_sync_committee() {
    response=$( query_prometheus rocketpool_beacon_upcoming_sync_committee )
    amount_upcoming=$( echo $response | grep -Po '\d*(?="\]\}\]\}\})' )
    echo $amount_upcoming
}
get_active_sync_committee() {
    response=$( query_prometheus rocketpool_beacon_active_sync_committee )
    amount_upcoming=$( echo $response | grep -Po '\d*(?="\]\}\]\}\})' )
    echo $amount_upcoming
}

day_apr=$( get_1d_apr )
upcoming_proposals=$( get_upcoming_proposals )
upcoming_sync_committee=$( get_upcoming_sync_committee )
active_sync_committee=$( get_active_sync_committee )

## ###############
## Notification
## ###############

# Basic notification
title="$node_nickname Daily Briefing"
message="24h rewards: Ξ$balance_delta_rounded ($day_apr%25 APR)
RPL Collateral ratio: $( get_rpl_collateral_ratio )%25
Updates: $( query_prometheus_for_rp_updates ) Rocket Pool, $( query_prometheus_for_os_updates ) OS
Monitoring: $( get_disk_used )25 disk usage
"

# Active sync committee
if [ "$active_sync_committee" != "0" ]; then
    log "Sync committee active"
    warning="⚠️  Sync committee active, prioritise uptime today"$'\n'
    message="$warning$message"
fi

# Upcoming sync comittee
if [ "$upcoming_sync_committee" != "0" ]; then
    log "Sync committee expected"
    message="$message"$'\n'"$upcoming_sync_committee upcoming sync committee(s), "
fi

# Upcoming proposals
if [ "$upcoming_proposals" != "0" ]; then
    log "Proposal upcoming"
    message="$message"$'\n'"$upcoming_proposals upcoming proposal(s)"
fi


log "$title"
log "$message"

curl -f -X POST -d "token=$pushover_token&user=$pushover_user&title=$title&message=$message&priority=0" https://api.pushover.net/1/messages.json
log "Notification sent"