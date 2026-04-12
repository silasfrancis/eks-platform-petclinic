locals {
  irsa_roles = {
    app_secrets = {
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
        resources = [
          "arn:aws:secretsmanager:*:*:secret:${var.app_secret_name}*"
        ]
      }
    }

    loki = {
      namespace = "monitoring"
      sas       = ["loki-sa"]
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

    cloudwatch_exporter = {
      namespace = "monitoring"
      sas       = ["cloudwatch-exporter-sa"]
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

  cluster_store = {
    namespace = "external-secrets"
    sas       = ["cluster-config-sa"]

    policy = {
      actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      resources = [
        "arn:aws:secretsmanager:*:*:secret:${var.cluster_config_secret_name}*"
      ]
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
  }
}