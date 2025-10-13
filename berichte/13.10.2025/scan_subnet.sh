#!/bin/bash
if [ -z "$1" ]; then
  echo "Usage: $0 <subnet-prefix>  (e.g. 192.168.1)"
  exit 1
fi
SUBNET=$1
echo "Scanning $SUBNET.0/24 ..."
for i in {1..254}; do
  IP="$SUBNET.$i"
  if ping -c 1 -W 1 -n -q "$IP" &>/dev/null; then
    echo "Host aktiv: $IP"
  fi
done
echo "Scan abgeschlossen."
