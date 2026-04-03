#!/bin/bash

#+--------------------------------------------------------------------------------+
#|                                                                                |
#|   check_vpn.sh                                                                 |
#|                                                                                |
#+--------------------------------------------------------------------------------+
#|   Guillaume Plante <codegp@icloud.com>                                         |
#|   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      |
#+--------------------------------------------------------------------------------+

YELLOW='\033[0;33m'
RED='\033[3;31m'
IRED='\033[4;31m'
NC='\033[0m'


# Ensure at least one expected VPN environment variable is set
if [[ -z "$VPN_EXPECTED_CITY" && -z "$VPN_EXPECTED_REGION" && -z "$VPN_EXPECTED_COUNTRY" && -z "$VPN_EXPECTED_TIMEZONE" && -z "$VPN_EXPECTED_POSTAL" ]]; then
    echo -e "${RED}FAILED:${NC} ➪ ${YELLOW} No VPN_EXPECTED_* environment variables are set.${NC}"
    exit 1
fi

echo -e "\n⚠⚠⚠ ${IRED}ENVIRONMENT VALUES${NC} ⚠⚠⚠\n${YELLOW}City${NC} ➪ ${RED}$VPN_EXPECTED_CITY\n${NC}${YELLOW}Region${NC} ➪ ${RED}$VPN_EXPECTED_REGION\n${NC}${YELLOW}Country${NC} ➪ ${RED}$VPN_EXPECTED_COUNTRY\n${NC}${YELLOW}Timezone${NC} ➪ ${RED}$VPN_EXPECTED_TIMEZONE\n${NC}${YELLOW}Postal${NC} ➪ ${RED}$VPN_EXPECTED_POSTAL${NC}"


# Fetch location data
ipinfo=$(curl -s 'http://ipinfo.io/json')

# Extract values using jq
city=$(echo "$ipinfo" | jq -r '.city')
region=$(echo "$ipinfo" | jq -r '.region')
country=$(echo "$ipinfo" | jq -r '.country')
timezone=$(echo "$ipinfo" | jq -r '.timezone')
postal=$(echo "$ipinfo" | jq -r '.postal')

# Check each environment variable only if it is set
if [[ -n "$VPN_EXPECTED_CITY" && "$VPN_EXPECTED_CITY" != "$city" ]]; then
    echo "${RED}FAILED:${NC} ➪ ${YELLOW} Expected city '$VPN_EXPECTED_CITY', but got '$city'${NC}"
    exit 1
fi

if [[ -n "$VPN_EXPECTED_REGION" && "$VPN_EXPECTED_REGION" != "$region" ]]; then
    echo "${RED}FAILED:${NC} ➪ ${YELLOW} Expected region '$VPN_EXPECTED_REGION', but got '$region'${NC}"
    exit 1
fi

if [[ -n "$VPN_EXPECTED_COUNTRY" && "$VPN_EXPECTED_COUNTRY" != "$country" ]]; then
    echo "${RED}FAILED:${NC} ➪ ${YELLOW} Expected country '$VPN_EXPECTED_COUNTRY', but got '$country'${NC}"
    exit 1
fi

if [[ -n "$VPN_EXPECTED_TIMEZONE" && "$VPN_EXPECTED_TIMEZONE" != "$timezone" ]]; then
    echo "${RED}FAILED:${NC} ➪ ${YELLOW} Expected timezone '$VPN_EXPECTED_TIMEZONE', but got '$timezone'${NC}"
    exit 1
fi

if [[ -n "$VPN_EXPECTED_POSTAL" && "$VPN_EXPECTED_POSTAL" != "$postal" ]]; then
    echo "${RED}FAILED:${NC} ➪ ${YELLOW} Expected postal '$VPN_EXPECTED_POSTAL', but got '$postal'"
    exit 1
fi

echo " ✅  VPN is correctly configured."
exit 0


