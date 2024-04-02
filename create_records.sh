#!/bin/bash
set -o pipefail

# if CF_EMAIL and CF_API_KEY are not set, then we will use the API token

if [[ -n "${CF_API_KEY}" && -n "${CF_EMAIL}" ]]; then
  echo "using CF_API_KEY and CD_EMAIL for authentication"
  #AUTHORIZATION_HEADER="--header 'X-Auth-Email: ${CF_EMAIL}' --header 'X-Auth-Key: ${CF_API_KEY}'"
  AUTHORIZATION_HEADER=(--header "X-Auth-Email: ${CF_EMAIL}" --header "X-Auth-Key: ${CF_API_KEY}")
elif [[ -n "${CF_API_TOKEN}" ]]; then
  echo "using CF_API_TOKEN for authentication"
  #AUTHORIZATION_HEADER="--header 'Authorization: Bearer $CF_API_KEY'"
  AUTHORIZATION_HEADER=(--header "Authorization: Bearer $CF_API_TOKEN")
else
  echo "(CF_API_KEY, CF_EMAIL) or CF_API_TOKEN must be set" >&2
  exit 1
fi

if [[ -z "${CF_ZONE_ID}" ]]; then
  echo "CF_ZONE_ID must be set" >&2
  exit 1
fi

if [[ -z "${CF_ACCOUNT_ID}" ]]; then
  echo "CF_ACCOUNT_ID must be set" >&2
  exit 1
fi

if [[ -z "${CF_TUNNEL_ID}" ]]; then
  echo "CF_TUNNEL_ID must be set" >&2
  exit 1
fi

if [[ -z "${COMPONENTS}" ]]; then
  echo "COMPONENTS must be set" >&2
  exit 1
fi

printenv | grep -v COMPONENTS
DNS_RECORDS=$(echo $COMPONENTS | cut -d'|' -f2- | jq --raw-output 'to_entries | map({key, value: .value.ingress.hosts[].hostname}) | .[].value')

echo "DNS records that need to be created:"
echo $DNS_RECORDS


# We MUST first run the command to generate the list.
# We do this so we do not wipe what is in place and we grab what is already there, which is confirmed as follows:

echo "Retrieving initial settings"

INITIAL_SETTINGS=$(curl -s -S --fail --request GET \
    --url https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel/$CF_TUNNEL_ID/configurations \
    --header "Content-Type: application/json" \
    "${AUTHORIZATION_HEADER[@]}")

if [ $? -ne 0 ]; then
  echo "Failed to retrieve initial settings" >&2
  exit 1
fi

INITIAL_DATA=$(echo $INITIAL_SETTINGS | jq '.result.config')

echo "Initial settings:"
echo $INITIAL_SETTINGS | jq

echo "Initial data:"
echo $INITIAL_DATA | jq

# Create a record for each URL in the list
for FQDN in $DNS_RECORDS; do

    # if FQDN matches the pattern, then we skip it
    if [[ $FQDN =~ bunnyenv.com$ ]]; then
        echo "Skipping $FQDN"
        continue
    fi
    echo "creating record: $FQDN"

    # remove the domain name from the FQDN
    #RECORD_NAME=$(echo $FQDN | sed 's/[.]/\n/g' | head -n -2 | paste -sd '.' -)
    RECORD_NAME=$(echo $FQDN | awk -F. 'BEGIN{OFS="."} NF{NF-=2}1')
    echo "RECORD_NAME: $RECORD_NAME"


    CREATE_RESULT=$(curl -s -S --fail --request POST \
        --url https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records \
        --header 'Content-Type: application/json' \
        "${AUTHORIZATION_HEADER[@]}" \
        --data "{ \"type\": \"CNAME\", \"name\": \"${RECORD_NAME}\", \"content\": \"${CF_TUNNEL_ID}.cfargotunnel.com\", \"proxied\": true }")

    if [ $? -ne 0 ]; then
        echo "Failed to create record for $FQDN (record may already exist)", >&2
        echo "CREATE_RESULT: $CREATE_RESULT" >&2
    else
        echo "CREATED $FQDN"
    fi

done

# Lastly, we can run this command which will make sure all the records stay:
echo "preserving initial settings"

FINAL_RESULT=$(curl -s -S --fail --request PUT \
    --url https://api.cloudflare.com/client/v4/accounts/$CF_ACCOUNT_ID/cfd_tunnel/$CF_TUNNEL_ID/configurations \
    --header 'Content-Type: application/json' \
    "${AUTHORIZATION_HEADER[@]}" \
    --data-raw "{ \"config\":  ${INITIAL_DATA}  }"    )

if [ $? -ne 0 ]; then
  echo "Failed to persist initial settings" >&2
  exit 1
fi
