#!/bin/bash
set -euo pipefail

## finalscript

"${COMPONENTS:?Variable not set}"

"${CF_API_KEY:?Variable not set}"
"${CF_ACCOUNT_ID:?Variable not set}"
"${CF_TUNNEL_ID:?Variable not set}"
"${CF_ZONE_ID:?Variable not set}"


printenv | grep -v COMPONENTSASDFASDf
DNS_RECORDS=$(echo $COMPONENTS | cut -d'|' -f2- | jq 'to_entries | map({key, value: .value.ingress.hosts[].hostname}) | .[].value')

echo "DNS records that need to be created:"
echo $DNS_RECORDS


# We MUST first run the command to generate the list.
# We do this so we do not wipe what is in place and we grab what is already there, which is confirmed as follows:

echo "Retrieving initial settings"

INITIAL_SETTINGS=$(curl -s -S --request --fail GET \
    --url https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel/$CF_TUNNEL_ID/configurations \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer $CF_API_KEY")

INITIAL_DATA=$(echo $INITIAL_SETTINGS | jq '.result.config')

echo "Initial settings:"
echo $INITIAL_SETTINGS | jq

echo "Initial data:"
echo $INITIAL_DATA | jq

# Create a record for each URL in the list
for FQDN in $DNS_RECORDS; do

    echo "creating record: $FQDN"

    # remove the domain name from the FQDN
    RECORD_NAME=$(echo $FQDN | sed 's/[.]/\n/g' | head -n -2 | paste -sd '.' -)
    echo "RECORD_NAME: $RECORD_NAME"


    CREATE_RESULT=$(curl -s -S --request --fail POST \
        --url https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records \
        --header 'Content-Type: application/json' \
        --header "Authorization: Bearer $CF_API_KEY" \
        --data "{ \"type\": \"CNAME\", \"name\": \"${RECORD_NAME}\", \"content\": \"${CF_TUNNEL_ID}.cfargotunnel.com\", \"proxied\": true }")

    echo "CREATED $FQDN"

done

# Lastly, we can run this command which will make sure all the records stay:
echo "preserving initial settings"

FINAL_RESULT=$(curl -s -S --request --fail PUT \
    --url https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel/$CF_TUNNEL_ID/configurations \
    --header 'Content-Type: application/json' \
    --header "Authorization: Bearer $CF_API_KEY" \
    --data-raw "{ \"config\":  ${INITIAL_DATA}  }"    )