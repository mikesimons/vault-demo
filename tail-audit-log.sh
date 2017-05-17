#!/bin/bash

docker exec vault_vault_a_1 tail -f /tmp/vault_audit.log > localfile &
tail -f localfile | jq --unbuffered
