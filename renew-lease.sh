#!/bin/bash -ex

vault renew "$(jq -r '.lease_id' creds.json)"
