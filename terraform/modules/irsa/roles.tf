# IRSA (IAM Roles for Service Accounts) Configuration
#
# Defines one entry per platform component that needs AWS API access from
# within the cluster. Each entry results in:
#   - One IAM role, trusted by the EKS OIDC provider, scoped to specific
#     Kubernetes service account(s) via the trust policy condition
#   - One IAM policy granting the permissions that component needs
#   - A policy attachment binding the two together
#
# The Kubernetes side (ServiceAccount annotated with
# eks.amazonaws.com/role-arn = <role arn>) must be created separately,
# typically by the relevant Helm chart/ArgoCD application.
#

# HOW TO ADD A NEW IRSA ROLE FOR ANOTHER RESOURCE/COMPONENT
# 
# 1. Add a new key under `irsa_roles` (the key becomes part of the IAM
#    role/policy name: "${cluster_name}-<key>-irsa").
# 2. Set `namespace` to the Kubernetes namespace the workload runs in.
# 3. Set `sas` to a list of the ServiceAccount name(s) (without namespace
#    prefix) that should be allowed to assume this role.
# 4. Set `policy.actions` and `policy.resources` for the primary permission
#    set this component needs.
# 5. (Optional) Add `extra_statements` — a list of additional IAM statement
#    blocks (Effect/Action/Resource) — for permissions that don't fit the
#    single actions/resources shape above (e.g. wildcard resources, extra
#    services).
# 6. If the new policy needs an ARN/value not already passed in
#    (e.g. a new bucket or secret ARN), add a corresponding variable to
#    variables.tf and pass it from the calling module.
locals {
  irsa_roles = {
    # Petclinic microservices — read access to application secrets in Secrets Manager
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

    # Loki — read/write access to its S3 log storage bucket, plus KMS access to
    # decrypt/encrypt objects using the data storage KMS key
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

    # CloudWatch exporter — read-only access to CloudWatch metrics and resource
    # tags across the account (used to scrape AWS service metrics, e.g. RDS)
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

  # ArgoCD — read access to its Secrets Manager credentials (e.g. Git repo creds)
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

  # Platform monitoring stack — read access to its Secrets Manager credentials
  # (e.g. Grafana admin password, Slack webhook)
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

  # Platform security stack — read access to its Secrets Manager credentials 
  # (e.g cloudflare api token for cert manager cluster issuer)
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

  # Velero — backup/restore access to its S3 bucket, EBS snapshot management
  # for PV backups, and KMS access for encrypted volumes/objects
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

  # ExternalDNS (Cloudflare provider) — read access to its Secrets Manager
  # API token used to manage public DNS records
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

  # ExternalDNS (Route53 provider) — manage records in the private hosted zone,
  # plus read-only access to list/discover hosted zones
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

  # Trivy Operator — pull/inspect access to ECR repositories for vulnerability
  # scanning of container images
  trivy-operator = {
    namespace = "security"
    sas       = ["trivy-operator"]

    policy = {
      actions = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeRegistry"
      ]
      resources = ["*"]
    }
  }
  }
}