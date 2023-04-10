#!bash 

## ###############
## Helpers
## ###############
function log() {
    echo -e "$( date ) - $@"
}

log "Starting rocketpool heartbeat container"

# Set up crontab
log "Crontab setting: "
crontab -l

# Send test notification
log "Sending test notification to $rocketeer_nickname using pushover user $pushover_user and token $pushover_token"
title="$node_nickname heartbeat service started"
message="You will receive a daily briefing for your node at $notification_hour:00"
curl -f -X POST -d "token=$pushover_token&user=$pushover_user&title=$title&message=$message&priority=0" https://api.pushover.net/1/messages.json
log "Test notification sent"

# Send one heartbeat to check if all is good
# log "Sending one heartbeat as test"
# ls -lah /scripts
# bash /scripts/rocketpool_heartbeat.sh

log "Coying our environment into the cron environment"
env >> /etc/environment

log "Starting cron"
cron -f -l 2