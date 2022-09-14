#!/bin/sh

export PATH=/data/git/tools:${PATH}

git-cron hourly /data/git > /data/git/git-cron-hourly.log 2>&1
