#!/bin/bash -ex

vault revoke "$(jq -r '.lease_id' creds.json)"
