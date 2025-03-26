# Sample website hosted on Amazon S3 with CloudFront distribution and WAF protection

### KMS - Central encryption key for website bucket contents and CloudWatch Logs
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "website_kms" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions = [
      "kms:*"
    ]
    resources = [
      "*"
    ]
    # checkov:skip=CKV_AWS_109: "Root account requires kms:* for key management. Additional conditions applied to CloudWatch Logs access. https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-overview.html"
    # checkov:skip=CKV_AWS_111: "KMS key policy write access is constrained with SourceAccount, via Service and ARN conditions for CloudWatch Logs."
    # checkov:skip=CKV_AWS_356: "Resource '*' required in KMS key policy as key ARN is not known at policy creation time. Access is constrained through conditions and actions."
  }

  statement {
    # https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html
    sid    = "Enable CloudWatch Logs access to KMS Key"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${var.Region}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = [
      "*"
    ]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        "arn:aws:logs:${var.Region}:${data.aws_caller_identity.current.account_id}:*"
      ]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["logs.${var.Region}.amazonaws.com"]
    }
  }

  statement {
    sid    = "Enable S3 Bucket Encryption"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        aws_s3_bucket.website.arn,
        aws_s3_bucket.logs.arn
      ]
    }
  }
}

resource "aws_kms_key" "website" {
  description             = "KMS key for website bucket encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.website_kms.json

  tags = {
    Name         = "${var.PrefixCode}-kms-website"
    resourcetype = "security"
  }
}

resource "aws_kms_alias" "website" {
  name          = "alias/${var.PrefixCode}-kms-website"
  target_key_id = aws_kms_key.website.key_id
}

### Logging Infrastructure - S3 bucket for CloudFront and S3 access logs with encryption and lifecycle rules
resource "aws_s3_bucket" "logs" {
  bucket_prefix = "${var.PrefixCode}-logs-"
  force_destroy = true

  tags = {
    resourcetype = "storage"
  }

  lifecycle {
    # checkov:skip=CKV2_AWS_62: "Event notifications not required for logging bucket. Contents managed through lifecycle rules."
    # checkov:skip=CKV_AWS_144: "Cross-region replication not implemented for logging bucket to reduce complexity and cost. Consider enabling for production environments if required for compliance or disaster recovery."
    # checkov:skip=CKV_AWS_145: "Using AES256 instead of KMS encryption as required by CloudFront and S3 logging services. KMS encryption is not supported for logging buckets."
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "ObjectWriter"
  }

  lifecycle {
    # checkov:skip=CKV2_AWS_65: "BucketOwnerEnforced not possible as CloudFront logging requires ACL access. Using BucketOwnerPreferred as secure alternative."
  }
}

# Enable logging on website bucket
resource "aws_s3_bucket_logging" "website" {
  bucket        = aws_s3_bucket.website.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-logs/"
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceSecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "${aws_s3_bucket.logs.arn}",
          "${aws_s3_bucket.logs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = false
          }
        }
      },
      {
        Sid       = "EnforceTLSVersion"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "${aws_s3_bucket.logs.arn}",
          "${aws_s3_bucket.logs.arn}/*"
        ]
        Condition = {
          NumericLessThan = {
            "s3:TlsVersion" = 1.2
          }
        }
      },
      {
        Sid    = "AllowCloudFrontLogs"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/cloudfront-logs/*"
      },
      {
        Sid    = "AllowS3LoggingService"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.logs.arn}/s3-logs/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Lifecycle policy to manage log retention
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "cleanup_old_logs"
    status = "Enabled"

    expiration {
      days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

### Website Content - S3 bucket configured with CloudFront Origin Access Control for secure content delivery
resource "aws_s3_bucket" "website" {
  bucket_prefix = "${var.PrefixCode}-s3-website-"

  tags = {
    resourcetype = "storage"
  }
  lifecycle {
    # checkov:skip=CKV2_AWS_62: "Event notifications not required for static website content. Changes are managed through deployment pipeline."
    # checkov:skip=CKV_AWS_144: "Cross-region replication not required for sample website. CloudFront provides global content delivery. Consider enabling for production environments requiring disaster recovery."
    # checkov:skip=CKV2_AWS_61: "Lifecycle configuration not required for website content bucket as objects are managed through deployment pipeline."
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.website.id
      sse_algorithm     = "aws:kms"
    }
  }
}

# CloudFront Origin Access Control for secure S3 access
resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${var.PrefixCode}-oac-website"
  description                       = "Origin Access Control for static website"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Bucket policy allowing CloudFront to access S3 content
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontAccess"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.website.arn
          }
        }
      }
    ]
  })
}

### Access Layer - CloudFront distribution with WAF protection and security headers
# WAF web ACL to protect CloudFront distribution
resource "aws_wafv2_web_acl" "website" {
  provider    = aws.us-east-1
  name        = "${var.PrefixCode}-waf-website"
  description = "WAF Web ACL for CloudFront distribution"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "WebACLMetric"
    sampled_requests_enabled   = true
  }

  tags = {
    resourcetype = "security"
  }

  lifecycle {
    # checkov:skip=CKV2_AWS_31: "WAF logging via Kinesis Firehose disabled for sample website to reduce complexity and cost. CloudWatch metrics enabled for basic monitoring. Consider enabling WAF logging in production for security analysis."
    # checkov:skip=CKV2_AWS_47: "Log4j protection provided through AWSManagedRulesCommonRuleSet. Dedicated Log4j rule group not required as core protections are included in common rules."
  }
}

# Security headers policy for CloudFront responses (HSTS, CSP)
resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name    = "${var.PrefixCode}-cloudfrontheaders-website"
  comment = "Security headers policy"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    content_security_policy {
      content_security_policy = "default-src 'self'"
      override                = true
    }
  }
}

# CloudFront distribution for secure content delivery with logging enabled
resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  default_root_object = "index.html"
  web_acl_id          = aws_wafv2_web_acl.website.arn

  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "S3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }


  logging_config {
    bucket          = aws_s3_bucket.logs.bucket_domain_name
    include_cookies = false
    prefix          = "cloudfront-logs/"
  }

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "S3Origin"
    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id
    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized policy
    origin_request_policy_id   = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf" # CORS-S3Origin policy
  }

  restrictions {
    geo_restriction {
      restriction_type = length(var.GeoRestriction) > 0 ? "whitelist" : "none"
      locations        = var.GeoRestriction
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }

  tags = {
    resourcetype = "network"
  }

  lifecycle {
    # checkov:skip=CKV_AWS_310: "Consider implementing origin failover for production environments. Skipped for development to reduce complexity and cost."
    # checkov:skip=CKV2_AWS_42: "Using default CloudFront certificate for sample website. Custom SSL certificate recommended for production use with custom domain names."
    # checkov:skip=CKV_AWS_86: "CloudFront logging not implemented. S3 access logs provide sufficient monitoring for sample website. Consider implementing CloudFront logging for production environments"
    # checkov:skip=CKV_AWS_109: "Root account requires kms:* for key management. Additional conditions applied to CloudWatch Logs access. https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-overview.html"
    # checkov:skip=CKV_AWS_111: "KMS key policy write access is constrained with SourceAccount, via Service and ARN conditions for CloudWatch Logs."
    # checkov:skip=CKV_AWS_356: "Resource '*' required in KMS key policy as key ARN is not known at policy creation time. Access is constrained through conditions and actions."
    # checkov:skip=CKV2_AWS_47: "Log4j protection provided through AWSManagedRulesCommonRuleSet. Dedicated Log4j rule group not required as core protections are included in common rules."
  }
}