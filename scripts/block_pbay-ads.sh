#!/bin/bash

# ┌────────────────────────────────────────────────────────────────────────────────┐
# │                                                                                │
# │   block pirate bay tracking/ads servers                                        │
# │                                                                                │
# │   Guillaume Plante  <guillaumeplante.qc@gmail.com>                             │
# └────────────────────────────────────────────────────────────────────────────────┘

# List of hosts to block
hosts=(
    "torrindex.net"    
    "assets.bwbx.io"
    "bwbx.io"
    "securepubads.g.doubleclick.net"
    "g.doubleclick.net"
    "doubleclick.net"
    "vi.ml314.com"
    "ml314.com"
    "onautcatholi.xyz"
    "exdynsrv.com"
    "ricewaterhou.xyz"
    "js.wpadmngr.com"
    "italarizege.xyz"
    "abservinean.com"
    "a.exdynsrv.com"
    "a.exosrv.com"
    "cdn.engine.spotscenered.info"
    "syndication.exdynsrv.com"
    "d1n3aexzs37q4s.cloudfront.net"
    "iconcardinal.com"
    "cipledecline.buzz"
    "www.viled.cfd"
)

# Function to resolve hostnames to IP addresses and block traffic using ufw
block_host() {
    host=$1
    # Resolve the hostname to an IP address
    ip=$(dig +short $host | tail -n 1)
    
    if [ -z "$ip" ]; then
        echo "Unable to resolve IP for $host"
    else
        # Block incoming and outgoing traffic to the resolved IP
        echo "Blocking IP: $ip ($host)"
        sudo ufw deny in from $ip
        sudo ufw deny out to $ip
    fi
}

# Iterate over each host and block it
for host in "${hosts[@]}"; do
    block_host "$host"
done

# Reload UFW to apply changes
sudo ufw reload
