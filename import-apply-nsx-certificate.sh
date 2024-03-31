#!/bin/bash

# Create API call that imports the TLS certificate to NSX Manager
URI="/api/v1/trust-management/certificates?action=import"
CERTIFICATE_CHAIN_PEM=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' $CERTIFICATE_CRT)  # Creates a "one-line" PEM suitable for the request body
PRIVATE_KEY_PEM=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' $CERTIFICATE_KEY)  # Creates a "one-line" key suitable for the request body

# Template the request body
cat >$CERTIFICATE_WORKING_DIR/body.json <<EOF
{
  "display_name": "${NSX_MANAGER_FQDN}",
  "pem_encoded": "${CERTIFICATE_CHAIN_PEM}",
  "private_key": "${PRIVATE_KEY_PEM}"
}
EOF

BODY=$(cat /tmp/body.json)
RESPONSE=$(curl -v -k "https://$NSX_MANAGER_FQDN$URI" -u "$NSX_USER:$NSX_PASSWORD" -H "content-type: application/json" -d "$BODY")
CERT_ID=$(echo $RESPONSE | jq -r '.results[] | {id} | join(" ")')          # Save the NSX certificate ID for later use


# Create API call that fetches NSX Manager node UUIDs (Fetches up to 3 NSX Manager node UUIDs, if you have less nodes that's fine)
URI="/api/v1/cluster"
RESPONSE=$(curl -v -k "https://$NSX_MANAGER_FQDN$URI" -u "$NSX_USER:$NSX_PASSWORD")
NODE_UUID_01=$(echo $RESPONSE | jq -r '.nodes[0].node_uuid')
NODE_UUID_02=$(echo $RESPONSE | jq -r '.nodes[1].node_uuid')
NODE_UUID_03=$(echo $RESPONSE | jq -r '.nodes[2].node_uuid')


# Create API call that applies the TLS certificate on NSX Manager node 01
URI="/api/v1/trust-management/certificates/$CERT_ID?action=apply_certificate&service_type=API&node_id=$NODE_UUID_01"
METHOD="POST"
RESPONSE=$(curl -v -k -X $METHOD "https://$NSX_MANAGER_FQDN$URI" -u "$NSX_USER:$NSX_PASSWORD" -H "content-type: application/json")


# Create API call that applies the TLS certificate on NSX Manager node 02. Ignored if there is no node 02
URI="/api/v1/trust-management/certificates/$CERT_ID?action=apply_certificate&service_type=API&node_id=$NODE_UUID_02"
METHOD="POST"
RESPONSE=$(curl -v -k -X $METHOD "https://$NSX_MANAGER_FQDN$URI" -u "$NSX_USER:$NSX_PASSWORD" -H "content-type: application/json")


# Create API call that applies the TLS certificate on NSX Manager node 03. Ignored if there is no node 03
URI="/api/v1/trust-management/certificates/$CERT_ID?action=apply_certificate&service_type=API&node_id=$NODE_UUID_03"
METHOD="POST"
RESPONSE=$(curl -v -k -X $METHOD "https://$NSX_MANAGER_FQDN$URI" -u "$NSX_USER:$NSX_PASSWORD" -H "content-type: application/json")


# Create API call that applies the TLS certificate on NSX Manager VIP
URI="/api/v1/trust-management/certificates/$CERT_ID?action=apply_certificate&service_type=MGMT_CLUSTER"
METHOD="POST"
RESPONSE=$(curl -v -k -X $METHOD "https://$NSX_MANAGER_FQDN$URI" -u "$NSX_USER:$NSX_PASSWORD" -H "content-type: application/json")