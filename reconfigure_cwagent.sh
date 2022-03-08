#!/bin/bash
set -euo pipefail

sudo systemctl stop amazon-cloudwatch-agent.service
sudo rm -f /opt/aws/amazon-cloudwatch-agent/logs/*

sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -s -a fetch-config -m onPremise -c file:/vagrant/cwagent-config.json

sudo systemctl status amazon-cloudwatch-agent.service


