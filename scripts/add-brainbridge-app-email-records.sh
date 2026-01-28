#!/bin/bash
set -e

# Add email records to brainbridge.app Route53 hosted zone
# This must be run BEFORE changing nameservers to Route53

HOSTED_ZONE_ID="Z0886717BPNWIHS2PKZD"

echo "Adding email records to brainbridge.app hosted zone..."

# Add MX records
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch '{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "brainbridge.app",
      "Type": "MX",
      "TTL": 3600,
      "ResourceRecords": [
        {"Value": "1 aspmx.l.google.com"},
        {"Value": "5 alt1.aspmx.l.google.com"},
        {"Value": "5 alt2.aspmx.l.google.com"},
        {"Value": "10 alt3.aspmx.l.google.com"},
        {"Value": "10 alt4.aspmx.l.google.com"}
      ]
    }
  }]
}'

echo "✓ MX records added"

# Add SPF record
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch '{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "brainbridge.app",
      "Type": "TXT",
      "TTL": 3600,
      "ResourceRecords": [
        {"Value": "\"v=spf1 include:_spf.google.com ~all\""}
      ]
    }
  }]
}'

echo "✓ SPF record added"

# Add DKIM record
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch '{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "google._domainkey.brainbridge.app",
      "Type": "TXT",
      "TTL": 3600,
      "ResourceRecords": [
        {"Value": "\"v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAkQiqVfcYF3Zo2ZsWZ+m2+PbC4vtZeyIKinAaIMaufuixhFpmwMhD56WHAbYQTRhIF80apm48DGkYvktOLRuF+RTc9eEiUqgehi+6CE0huLaaGbGqy03Nfvi7p0z/OtTofA4xHjCkbB+o3SyEqTOn9doeacIhjLFsGx2bkPj1g1gOqF5hDs3teUrtszoBDkBiY\" \"z0RnXsg8SOtYUzAsRwW3bm/xaHR3L39AlwSdUAp4/qmTGyUiR/ojJg5Id3Avjhms0R6neuPP66kXAOyzGe7xnAYJWZ96LB2oH+zQYk5xsDQAoW0A+A4+GmrsnTfORTTQsSmzFAndsh2J5BkTyFz5wIDAQAB\""}
      ]
    }
  }]
}'

echo "✓ DKIM record added"

# Add DMARC record
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch '{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "_dmarc.brainbridge.app",
      "Type": "TXT",
      "TTL": 3600,
      "ResourceRecords": [
        {"Value": "\"v=DMARC1; p=reject; rua=mailto:postmaster@brainbridge.app, mailto:dmarc@brainbridge.app; pct=100; adkim=s; aspf=s\""}
      ]
    }
  }]
}'

echo "✓ DMARC record added"

echo ""
echo "==========================================
"
echo "✅ All email records added to Route53!"
echo "==========================================
"
echo ""
echo "Route53 nameservers for brainbridge.app:"
aws route53 get-hosted-zone --id "$HOSTED_ZONE_ID" --query 'DelegationSet.NameServers' --output table
echo ""
echo "⚠️  IMPORTANT: Update nameservers at your registrar to these Route53 nameservers"
echo "⚠️  Current nameservers (will be replaced):"
dig brainbridge.app NS +short
