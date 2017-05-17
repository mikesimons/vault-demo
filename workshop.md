# What is Hashicorp Vault?
Secure secrets service

# Why?
- Secure secrets are hard
- Secrets expiry rarely used
- Secrets rotation is a PITA
- Shared secrets mean broad permissions but team / app specific credentials are a pain to manage
- Often no way to audit who has access to what

# What can it do?
 - Generic secrets
 - Dynamic secrets
 - Secrets expiration
 - Access policies
 - Authenticated access
 - Audit logs
 - Data encrypted at rest & on wire

# Vault initialization & sealing
## Initialize vault
Initialize storage, generates unseal keys, generates root token
```
vault init | tee vault-init.txt
export ROOT_TOKEN=...
```

## Try list secrets
```
vault list secret
```
Vault is sealed

## Unseal!
https://www.vaultproject.io/docs/concepts/seal.html
3 of 5 keys, any order. Can't disable this but can make it 1 key with a rekey or `vault init --key-shares=1 --key-threshold=1`
```
vault unseal <1>
vault unseal <2>
vault unseal <3>
```

## Authenticate with root token
```
vault auth
```

## Try list secerts
```
vault list secret
```
No values found


# Generic secrets

## Write a secret
```
vault write secret/github_api_key blahblahblah
```
All secrets written to the generic secret store must be key pairs (within the secret path!)
If you only have a string to store, convention says use `value=<value>`

## Write a secret
```
vault write secret/github_api_key value=blahblahblah
```
Success

## List secrets
```
vault list secret
```
Secrets listed

## Read secret
```
vault read secret/github_api_key
```
Secret shown

# Dynamic secrets
Vault also supports some much cooler secret types...

## Mount IAM secrets
In order to use other secret types we must mount them.
Specifying a path allows multiple configurations for same mount type

```
vault mount -path=my-aws aws
```

## Configure IAM secrets
```
vault write my-aws/config/root \
    access_key=$AWS_ACCESS_KEY_ID \
    secret_key=$AWS_SECRET_ACCESS_KEY \
    region=us-east-1
```

## Reduce leases for demo
```
vault write my-aws/config/lease lease=1m lease_max=10m
```

## Create read-only role
```
vault write my-aws/roles/readonly arn=arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess
```

## Get some creds!
```
vault read my-aws/creds/readonly
```

## Show that they actually work! (and expire)
```
vault read --format=json my-aws/creds/readonly > creds.json
watch -n 5 ./demo-iam-creds.sh
```

## Show user in IAM console
https://console.aws.amazon.com/iam/home?region=us-east-1#/users
Search for "vault"

## Mount mysql secrets
```
vault mount -path="mysql-a" mysql
```

## Configure mysql connection
```
vault write mysql-a/config/connection connection_url="root:root@tcp(mysql:3306)/"
```

## Shorten lease for demo
```
vault write mysql-a/config/lease lease=20s lease_max=10m
```

## Create role
```
vault write mysql-a/roles/readonly sql="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT ON *.* TO '{{name}}'@'%';"
```

## MySQL demo
```
vault read --format=json mysql-a/creds/readonly > creds.json
watch -n 5 ./demo-mysql-creds.sh
```

# Leases, renewal, revocation
All secrets have expiry.
lease=time that lease is valid from request without renewal
lease_max=maximum amount of time this cred can exist even with renewal
Once lease_max is reached a new secret must be requested

## Renewal demo
```
vault read --format=json mysql-a/creds/readonly > creds.json
watch -n 5 ./demo-mysql-creds.sh
watch -n 10 ./renew-lease.sh
```

## Revoke demo
```
vault read --format=json mysql-a/creds/readonly > creds.json
watch -n 5 ./demo-mysql-creds.sh
watch -n 10 ./renew-lease.sh
./revoke-lease.sh
```
Revocation can also be based on prefix with `-prefix` option.
Demo revokes a specific lease but we could revoke all readonly secrets or all mysql-a secrets too.

## SSH demo
```
vault mount ssh

vault write ssh/roles/otp_key_role \
  key_type=otp \
  default_user=core \
  cidr_list=$SSH_DEMO_IP/32
```

```
ssh -R 8200:localhost:8200 core@$SSH_DEMO_IP
```

Uncomment PubkeyAuthentication=no

```
ssh core@$SSH_DEMO_IP
vault ssh core@$SSH_DEMO_IP
```

# Audit logging
```
vault audit-enable file file_path=/tmp/vault_audit.log
./tail-audit-log.sh
vault read --format=json mysql-a/creds/readonly > creds.json
```

# Auth, Users & Policies

## Create a policy
https://www.vaultproject.io/docs/concepts/policies.html
```
vault policy-write team1 team1.hcl
cat team1.hcl
```

## Enable alternative auth mechanism
```
vault auth-enable userpass
```

## Add a user
```
vault write auth/userpass/users/team1-user password=pass policies=team1
```

## See auth methods
https://www.vaultproject.io/docs/auth/index.html
```
vault auth --methods
```
Auth methods are just other ways to get tokens.

## ASIDE: Token restriction capability
```
vault token-create --help
```

Tokens have renewal / revocation just like secret leases

## Auth as team1
```
vault auth -method=userpass username=team1-user password=pass
```

## Try to write secret
```
vault write secret/test value=1234
```
DENIED

## Try to write team1 secret
```
vault write secret/team1/test value=1234
```
SUCCESS

## Reauth as root
```
vault auth $ROOT_TOKEN
```

# Response wrapping
Sometimes you don't want to give someone direct access to dynamic secrets generation.
Enter response wrapping...

## Get mysql creds (as before) but wrap them this time
```
vault read -wrap-ttl=5m mysql-a/creds/readonly
vault unwrap <wrapping-token>
```

# curl
You don't need the cli client... it just makes it easier
```
curl -s -H "X-Vault-Token: $ROOT_TOKEN" http://localhost:8200/v1/my-aws/creds/readonly | jq
```

# Explanations...
## Secrets vs auth vs storage vs audit backends

## HA model
Multiple vault servers point to same storage backend
One grabs a lock and becomes active
All other vault instance issue a 307 redirect to active vault
Vault instances should be directly accessible (for redirect purposes)
But also need to be behind reverse proxy (unsealed only) to provide single endpoint

## Supported storage backends
https://www.vaultproject.io/docs/configuration/storage/index.html
Note: Only backends supporting lock aquisition are HA compatiblt

## Supported secrets backends
https://www.vaultproject.io/docs/secrets/index.html

## Supported auth backends
https://www.vaultproject.io/docs/auth/index.html

