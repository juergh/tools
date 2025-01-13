#!/bin/bash -u

MAX_PRCNT=70
MIN_PRCNT=60

SHELLY1_NAME=shelly1-98cdac0c9cdf.fritz.box

function shelly1()
{
	local name=${1} action=${2:-}

	if [ -z "${action}" ] ; then
		curl -s http://"${name}"/settings | python3 -c """
import json
import sys

try:
    ison = json.load(sys.stdin).get('relays', [{}])[0].get('ison')
except json.decoder.JSONDecodeError:
    ison = None

if ison is None:
    print('unknown')
elif ison:
    print('on')
else:
    print('off')
"""
	else
		curl -s http://"${name}"/relay/0?turn="${action}"
		sleep 2
	fi
}

function out()
{
	trap - EXIT INT TERM HUP
	shelly1 "${SHELLY1_NAME}" on >/dev/null
	exit
}

trap out EXIT INT TERM HUP

full=$(cat /sys/class/power_supply/BAT1/charge_full)

while true ; do
	now=$(cat /sys/class/power_supply/BAT1/charge_now)
	now_prcnt=$((100 * now / full))
	echo
	echo "Current charge: ${now_prcnt} %"

	relay=$(shelly1 "${SHELLY1_NAME}")
	online=$(cat /sys/class/power_supply/ACAD/online)

	if [ ${now_prcnt} -le ${MIN_PRCNT} ] && [ "${online}" -eq 0 ] && [ "${relay}" = "off" ] ; then
		shelly1 "${SHELLY1_NAME}" on >/dev/null
	elif [ ${now_prcnt} -ge ${MAX_PRCNT} ] && [ "${online}" -eq 1 ] && [ "${relay}" = "on" ] ; then
		shelly1 "${SHELLY1_NAME}" off >/dev/null
	fi

	relay2=$(shelly1 "${SHELLY1_NAME}")
	online2=$(cat /sys/class/power_supply/ACAD/online)

	if [ "${relay}" = "${relay2}" ] ; then
		echo "Shelly1 relay:  ${relay}"
	else
		echo "Shelly1 relay:  ${relay} -> ${relay2}"
	fi

	if [ "${online}" = "${online2}" ] ; then
		echo "AC online:      ${online}"
	else
		echo "AC online:      ${online} -> ${online2}"
	fi

	if [ "${relay2}" = "on" ] && [ "${online2}" -eq 0 ] ; then
		echo "-- Not plugged in"
		exit
	fi

	if [ "${relay2}" = "off" ] && [ "${online2}" -eq 1 ] ; then
		echo "-- Not plugged in"
		exit
	fi

	if [ "${relay}" != "${relay2}" ] && [ "${online}" = "${online2}" ] ; then
		echo "-- Not plugged in"
		exit
	fi

	sleep 60
done
