locals {
  irsa_roles = {
    app-secrets = {
      namespace = "petclinic"
      sas       = [
        "config-server-sa", 
        "customers-service-sa", 
        "visits-service-sa", 
        "vets-service-sa", 
        "genai-service-sa", 
        "db-migration-sa"
      ]
      policy    = {
        actions   = [
          "secretsmanager:GetSecretValue", 
          "secretsmanager:DescribeSecret", 
          "secretsmanager:GetResourcePolicy", 
          "secretsmanager:ListSecretVersionIds"
        ]
        resources = var.app_secrets_arn
      }
    }

    loki = {
      namespace = "monitoring"
      sas       = ["loki"]
      policy    = {
        actions   = [
          "s3:ListBucket", 
          "s3:GetObject", 
          "s3:PutObject", 
          "s3:DeleteObject"
        ]
        resources = [
          var.loki_bucket_arn, 
          "${var.loki_bucket_arn}/*"
        ]
      }
      extra_statements = [{
        Effect   = "Allow"
        Action   = [
          "kms:GenerateDataKey", 
          "kms:Decrypt"
        ]
        Resource = [var.data_storage_kms_key_arn]
      }]
    }

    cloud-watch-exporter = {
      namespace = "monitoring"
      sas       = ["cloudwatch-exporter"]
      policy    = {
        actions   = [
          "cloudwatch:GetMetricData", 
          "cloudwatch:GetMetricStatistics", 
          "cloudwatch:ListMetrics", 
          "tag:GetResources"
        ]
        resources = ["*"]
      }
    }

  argocd-secrets = {
    namespace = "argocd"
    sas       = ["argocd-sa"]

    policy = {
      actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      resources = var.argocd_secrets_arn
    }
  }

  platform-monitoring-secrets = {
    namespace = "monitoring"
    sas       = ["platform-monitoring-sa"]

    policy = {
      actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      resources = var.platform_monitoring_secrets_arn
    }
  }

  platform-security-secrets = {
    namespace = "security"
    sas       = ["platform-security-sa"]

    policy = {
      actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      resources = var.platform_security_secrets_arn
    }
  }
  velero = {
      namespace = "velero"
      sas       = ["velero"]
      policy    = {
        actions   = [
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObject",
          "s3:PutObjectTagging",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        resources = [
          "${var.velero_bucket_arn}/*"
        ]
      }
      extra_statements = [{
          Effect = "Allow"
          Action = [
            "s3:ListBucket",
            "s3:GetBucketLocation",
            "s3:ListBucketMultipartUploads"
          ]
          Resource = var.velero_bucket_arn
        },
        {
          Effect = "Allow"
          Action = [
            "ec2:DescribeVolumes",
            "ec2:DescribeSnapshots",
            "ec2:CreateTags",
            "ec2:CreateVolume",
            "ec2:CreateSnapshot",
            "ec2:DeleteSnapshot"
          ]
          Resource = "*"
        },
        {
          Effect   = "Allow"
          Action   = [
            "kms:GenerateDataKey", 
            "kms:Decrypt"
          ]
          Resource = [var.data_storage_kms_key_arn]
      }]
    }

  external-dns-secrets = {
    namespace = "istio-ingress"
    sas       = ["external-dns-cloudflare"]

    policy = {
      actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      resources = var.platform_dns_secrets_arn
    }
  }
  external-dns-route53 = {
      namespace = "istio-ingress"
      sas       = ["external-dns-route53"]
      policy    = {
        actions   = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
          
        ]
        resources = var.route53_private_zone_arn
      }
      extra_statements = [{
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListTagsForResource"
        ]
        Resource = ["*"]
      }]
    }
  }
}