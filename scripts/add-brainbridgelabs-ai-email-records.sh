#!/bin/bash
set -e

# Add email records to brainbridgelabs.ai Route53 hosted zone
# This must be run AFTER CDK deployment creates the hosted zone
# Run this BEFORE changing nameservers at the registrar

if [ -z "$1" ]; then
  echo "Usage: $0 <HOSTED_ZONE_ID>"
  echo ""
  echo "Get the hosted zone ID from CDK deployment output"
  exit 1
fi

HOSTED_ZONE_ID="$1"

echo "Adding email records to brainbridgelabs.ai hosted zone $HOSTED_ZONE_ID..."

# Add MX records
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch '{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "brainbridgelabs.ai",
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

# Add SPF records (multiple TXT records)
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch '{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "brainbridgelabs.ai",
      "Type": "TXT",
      "TTL": 3600,
      "ResourceRecords": [
        {"Value": "\"v=spf1 include:dc-aa8e722993._spfm.brainbridgelabs.ai ~all\""},
        {"Value": "\"v=spf1 include:zcsend.net ~all\""},
        {"Value": "\"google-site-verification=OVXxhyc19tktHfY61OqCwGyqxv8X2X2qtSpFwagl_FM\""}
      ]
    }
  }]
}'

echo "✓ SPF and Google verification records added"

# Add DKIM record
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch '{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "google._domainkey.brainbridgelabs.ai",
      "Type": "TXT",
      "TTL": 3600,
      "ResourceRecords": [
        {"Value": "\"v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAw7N/xoXaL18Bc7NQ3I8ff5b+tfLXRQsjQDpvn8Y0H/yJOgDRoVBlyIlbMY7F7+GCTVgqf1UBzJxoupyFHkDBKonRC9sYECZEGCoAuduFBonwOiZ/kXcBsGSKE8ukBjVwpfjTd4IZBgB8UsbXcwbE08IVL4a5irZiqWF1owccct4eE4gubx9LAe878r6G8GUwr\" \"ehz/mw6K9HnZvf5/rm5nJ155guAX5B3M/ig7F+SgyO38vnPNQf56rCWpWGzElLMxUn9w8CgYwwZt+X1IsD5f3rWQBgJxRGzZK9MMLcZZPRZ68ai4KFtXGXM8rdwYoyw8w6/G6NV8ixBgKtnW4sY/QIDAQAB\""}
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
      "Name": "_dmarc.brainbridgelabs.ai",
      "Type": "TXT",
      "TTL": 3600,
      "ResourceRecords": [
        {"Value": "\"v=DMARC1; p=none;\""}
      ]
    }
  }]
}'

echo "✓ DMARC record added"

echo ""
echo "=========================================="
echo "✅ All email records added to Route53!"
echo "=========================================="
echo ""
echo "Route53 nameservers for brainbridgelabs.ai:"
aws route53 get-hosted-zone --id "$HOSTED_ZONE_ID" --query 'DelegationSet.NameServers' --output table
echo ""
echo "⚠️  IMPORTANT: Update nameservers at GoDaddy to these Route53 nameservers"
echo "⚠️  This will migrate DNS from GoDaddy to Route53"
