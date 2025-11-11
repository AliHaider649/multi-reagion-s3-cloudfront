#!/bin/bash
# Invalidate CloudFront cache

DIST_ID=$1
PATHS=${2:-"/*"}

if [ -z "$DIST_ID" ]; then
  echo "Usage: ./invalidate.sh <E4SRG3TQ17WEJ> <paths>"
  exit 1
fi

aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "$PATHS"
echo "✅ CloudFront cache invalidated"
