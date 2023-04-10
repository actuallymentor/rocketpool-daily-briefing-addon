# Rocketpool daily briefing addon

This is an add-on to the Rocket Pool startnode stack. It sends a daily notification with basic statistics about your node, including:

- ETH generated over the last 24h
- RPL collateral ratio
- whether a sync committee is active/expected
- whether system/Rocket Pool updates are available
- percentage disk space used

The push notifications are sent using [pushover](https://pushover.net/), so you will need to have their app installed.

## Technical details

The docker container runs a cron job that queries the Prometheus statistics that are exposed by Rocket Pool. The same cronjob then sends a daily notification to your devices, using the pushover API.