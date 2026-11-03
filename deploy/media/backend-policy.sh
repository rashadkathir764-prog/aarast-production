#!/bin/sh

write_aarast_backend_media_policy() {
  policy_bucket=$1
  policy_output=$2

  printf '{
  "Version":"2012-10-17",
  "Statement":[
    {
      "Effect":"Allow",
      "Action":["s3:GetBucketLocation"],
      "Resource":["arn:aws:s3:::%s"]
    },
    {
      "Effect":"Allow",
      "Action":["s3:PutObject","s3:GetObject","s3:DeleteObject"],
      "Resource":[
        "arn:aws:s3:::%s/user-avatar/*",
        "arn:aws:s3:::%s/provider-logo/*",
        "arn:aws:s3:::%s/provider-cover/*",
        "arn:aws:s3:::%s/service-image/*",
        "arn:aws:s3:::%s/provider-portfolio/*",
        "arn:aws:s3:::%s/guest-invitation-card/*",
        "arn:aws:s3:::%s/chat-image/*"
      ]
    }
  ]
}
' \
    "$policy_bucket" \
    "$policy_bucket" \
    "$policy_bucket" \
    "$policy_bucket" \
    "$policy_bucket" \
    "$policy_bucket" \
    "$policy_bucket" \
    "$policy_bucket" >"$policy_output"
}
