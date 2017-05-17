#!/bin/bash -ex

export AWS_ACCESS_KEY_ID="$(jq -r '.data.access_key' creds.json)"
export AWS_SECRET_ACCESS_KEY="$(jq -r '.data.secret_key' creds.json)"

aws ec2 describe-instances --filter "Name=tag:Name,Values=consul*" --query="Reservations[*].Instances[*].Tags[?Key=='Name'].Value" | jq -r 'add | add | join("\n")'

