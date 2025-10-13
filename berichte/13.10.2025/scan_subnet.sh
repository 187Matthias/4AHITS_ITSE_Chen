#!/usr/bin/env bash
# scan_subnet.sh
# Scannt ein /24 IPv4-Subnet (z.B. 192.168.1.0/24) und gibt nur die aktiven Hosts aus.
# Ausgabeformat: "<IP>  <rtt in ms>"
#
# Nutzung:
#   ./scan_subnet.sh 192.168.1.0/24
#   ./scan_subnet.sh 192.168.1.0/24  # optionaler 2. Parameter: Concurrency (default 100)
#
# Hinweis: Dieses Skript ist primär für Linux (GNU ping). Für macOS sind Timeout-Flags abweichend.

set -uo pipefail

SUBNET="$1"
CONCURRENCY="${2:-100}"    # Anzahl paralleler Pings (Standard 100)
TIMEOUT="${3:-1}"          # timeout in Sekunden für eine Antwort (ping -W)

# --- Hilfsfunktionen ---
usage() {
  cat <<EOF
Usage: $0 <subnet> [concurrency] [timeout]
Example: $0 192.168.1.0/24 200 1
Only /24 subnets are supported (e.g. 192.168.1.0/24) or prefix like "192.168.1."
EOF
  exit 1
}

# Prüfe Input
if [[ -z "$SUBNET" ]]; then
  usage
fi

# Unterstützt Formen:
# - 192.168.1.0/24
# - 192.168.1.    (dann wird das gleiche interpretiert wie 192.168.1.0/24)
if [[ "$SUBNET" =~ ^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\.0/24$ ]]; then
  PREFIX="${BASH_REMATCH[1]}"
elif [[ "$SUBNET" =~ ^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})\.$ ]]; then
  PREFIX="${BASH_REMATCH[1]}"
elif [[ "$SUBNET" =~ ^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})/24$ ]]; then
  PREFIX="${BASH_REMATCH[1]}"
else
  echo "Fehler: Nur /24 Subnets oder Präfix 'a.b.c.' werden unterstützt."
  usage
fi

# Basic validation der Oktette
IFS='.' read -r a b c <<< "$PREFIX"
for oct in "$a" "$b" "$c"; do
  if (( oct < 0 || oct > 255 )); then
    echo "Fehler: ungültige IP-Oktette in Prefix: $PREFIX"
    exit 1
  fi
done

# Funktion: ping und bei Erfolg ausgeben (IP und RTT)
ping_and_report() {
  local ip="$1"
  # -c 1 : 1 Paket
  # -W $TIMEOUT : wait timeout seconds for reply (Linux)
  # -n : numeric output (keine Namensauflösung)
  # Wir lesen stdout/stderr, prüfen Exit-Code, parsen RTT falls vorhanden
  out=$(ping -c 1 -W "$TIMEOUT" -n "$ip" 2>/dev/null)
  if [[ $? -eq 0 ]]; then
    # Extrahiere time=xxx ms; falls nicht vorhanden, nur IP ausgeben
    # Beispiel-Line: "64 bytes from 192.168.1.1: icmp_seq=1 ttl=64 time=0.123 ms"
    rtt=$(echo "$out" | awk -F 'time=' '/time=/{print $2; exit}' | sed 's/ ms$//')
    if [[ -n "$rtt" ]]; then
      # Sauber formatierte Ausgabe: IP <TAB> RTT(ms)
      printf "%-15s\t%s ms\n" "$ip" "$rtt"
    else
      printf "%-15s\talive\n" "$ip"
    fi
  fi
}

# --- Hauptschleife ---
# Wir pingen Hosts 1..254 (Netzadresse .0 und Broadcast .255 bleiben außen)
for last in $(seq 1 254); do
  ip="$PREFIX.$last"
  # Start im Hintergrund
  ping_and_report "$ip" &

  # Concurrency-Limit: warte, bis Anzahl laufender Jobs < CONCURRENCY
  while (( $(jobs -rp | wc -l) >= CONCURRENCY )); do
    sleep 0.02
  done
done

# Warte auf alle Hintergrund-Jobs
wait

# Ende
exit 0