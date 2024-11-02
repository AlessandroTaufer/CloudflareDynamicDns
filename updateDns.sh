#!/bin/bash

# Domain name to automatically update
domain_name="${1}"
# Whether the ip should be proxied or not
proxied=false

# File containing the cloudflare credentials
config_file=$2

if [ -z $domain_name ]; then
  echo "Missing mandatory argument: DOMAIN_NAME"
  exit 1
fi

# If not specified, assume a default
if [ -z $config_file ]; then
  config_file="config.json"
fi

# Check for dependencies
dependencies=(curl jq)

for dep in "${dependencies[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        echo "$dep is not installed. Please install it"
        exit 1
    fi
done

# Read from the config file all the needed settings
config=$(cat $config_file)

zone_id=$(echo $config | jq -r .zone_id)
account_id=$(echo $config | jq -r .account_id)
cloudflare_token=$(echo $config | jq -r .token)

# Read the last value of the dns record
dns_record_ip=$(head -n 1 /tmp/dns_record_ips_used.txt)

# Retrieve the current ip
current_ip=$(curl -s https://ifconfig.me)

# I don't want to trust a single provider to possibly redirect all my records
# so i go for the multiple checks
current_ip_indepentent_check_1=$(curl -s https://ifconfig.co)
current_ip_indepentent_check_2=$(curl -s https://icanhazip.com)

# If not all the replies are matching something nasty is going on, so let's abort
if [[ $current_ip == $current_ip_indepentent_check_1 && $current_ip == $current_ip_indepentent_check_2 ]]; then
	echo "All ips are matching, the current ip is $current_ip"
else
	echo "WARNING - ip not matching, something nasty is going on: ${current_ip} - ${current_ip_indepentent_check_1} - ${current_ip_indepentent_check_2}"
	exit 1
fi

# Check if the dns record it's already pointing to that ip
if [[ $current_ip == $dns_record_ip ]]; then
	echo "Nothing to do, dns already set"
	exit 0
fi

# Get from the api the list of domains in the zone
dns_records_ids=$(curl --request GET -s \
  --url https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records \
  --header 'Content-Type: application/json' \
  --header "Authorization: Bearer $cloudflare_token")

dns_record_id=$(echo $dns_records_ids | jq -r  ".result[] | select (.name==\"$domain_name\") | .id")

data=$(jq -n --arg comment "Update on $(date)" --arg name "${domain_name}" --arg ip "$current_ip" --argjson proxied "${proxied}" ' {
  "comment": $comment,
  "name": $name,
  "proxied": $proxied,
  "settings": {},
  "tags": [],
  "ttl": 60,
  "content": $ip,
  "type": "A"
}')

# Now that we made sure the current_ip it's valid, let's update it!
request_status=$(curl -s --request PUT \
                    --url https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$dns_record_id \
                    --header 'Content-Type: application/json' \
                    --header "Authorization: Bearer $cloudflare_token"\
                    --data "$data")

# Fail if something went wrong
if [[ $(echo $request_status | jq .success) != "true" ]];
then
  echo "Update failed"
  echo $request_status
  exit 1
fi

# Add the new ip to the archive
echo $current_ip > /tmp/dns_record_ips_used.txt
echo "Dns updated successfully"

exit 0