variable "env" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "codedeploy_termination_wait_time" {
  type = number
}

variable "deploy_test_postman_collection" {
  type = string
}

variable "deploy_test_postman_environment" {
  type = string
}

locals {
  name = "hw-fargate-api"
  tags = {
    env              = var.env
    data-sensitivity = "public"
    repo             = "https://github.com/byu-oit/${local.name}"
  }
}

data "aws_ecr_repository" "my_ecr_repo" {
  name = "${local.name}-${var.env}"
}

module "acs" {
  source = "github.com/byu-oit/terraform-aws-acs-info?ref=v3.2.0"
}

module "my_fargate_api" {
  source                        = "github.com/byu-oit/terraform-aws-fargate-api?ref=v3.3.0"
  app_name                      = "${local.name}-${var.env}"
  container_port                = 8080
  health_check_path             = "/health"
  codedeploy_test_listener_port = 4443
  task_policies = [
    aws_iam_policy.my_dynamo_policy.arn,
    aws_iam_policy.my_s3_policy.arn
  ]
  hosted_zone                      = module.acs.route53_zone
  https_certificate_arn            = module.acs.certificate.arn
  public_subnet_ids                = module.acs.public_subnet_ids
  private_subnet_ids               = module.acs.private_subnet_ids
  vpc_id                           = module.acs.vpc.id
  codedeploy_service_role_arn      = module.acs.power_builder_role.arn
  codedeploy_termination_wait_time = var.codedeploy_termination_wait_time
  role_permissions_boundary_arn    = module.acs.role_permissions_boundary.arn
  tags                             = local.tags

  primary_container_definition = {
    name  = "${local.name}-${var.env}"
    image = "${data.aws_ecr_repository.my_ecr_repo.repository_url}:${var.image_tag}"
    ports = [8080]
    environment_variables = {
      DYNAMO_TABLE_NAME = aws_dynamodb_table.my_dynamo_table.name,
      BUCKET_NAME       = aws_s3_bucket.my_s3_bucket.bucket
    }
    secrets = {
      "SOME_SECRET" = "/${local.name}/${var.env}/some-secret"
    }
    efs_volume_mounts = null
  }

  autoscaling_config = {
    min_capacity = 1
    max_capacity = 2
  }

  codedeploy_lifecycle_hooks = {
    BeforeInstall         = null
    AfterInstall          = null
    AfterAllowTestTraffic = module.postman_test_lambda.lambda_function.function_name
    BeforeAllowTraffic    = null
    AfterAllowTraffic     = null
  }
}

resource "aws_dynamodb_table" "my_dynamo_table" {
  name         = "${local.name}-${var.env}"
  hash_key     = "my_key_field"
  billing_mode = "PAY_PER_REQUEST"
  tags         = local.tags
  attribute {
    name = "my_key_field"
    type = "S"
  }
}

resource "aws_iam_policy" "my_dynamo_policy" {
  name        = "${local.name}-dynamo-${var.env}"
  path        = "/"
  description = "Access to dynamo table"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:BatchGet*",
                "dynamodb:DescribeStream",
                "dynamodb:DescribeTable",
                "dynamodb:Get*",
                "dynamodb:Query",
                "dynamodb:Scan",
                "dynamodb:BatchWrite*",
                "dynamodb:Update*",
                "dynamodb:PutItem"
            ],
            "Resource": "${aws_dynamodb_table.my_dynamo_table.arn}"
        }
    ]
}
EOF
}

# -----------------------------------------------------------------------------
# START OF S3
# Note that in my_fargate_api, we also added a policy and environment variable
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "my_s3_bucket_logs" {
  bucket = "${local.name}-${var.env}-logs"
  acl    = "log-delivery-write"
  tags   = local.tags
}

resource "aws_s3_bucket" "my_s3_bucket" {
  bucket = "${local.name}-${var.env}"
  tags   = local.tags
  logging {
    target_bucket = aws_s3_bucket.my_s3_bucket_logs.id
    target_prefix = "log/"
  }
  versioning {
    enabled = true
  }
  //  lifecycle {
  //    prevent_destroy = true
  //  }
  lifecycle_rule {
    id                                     = "AutoAbortFailedMultipartUpload"
    enabled                                = true
    abort_incomplete_multipart_upload_days = 10
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "default" {
  bucket                  = aws_s3_bucket.my_s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_policy" "my_s3_policy" {
  name        = "${local.name}-s3-${var.env}"
  description = "A policy to allow access to s3 to this bucket: ${aws_s3_bucket.my_s3_bucket.bucket}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": [
        "${aws_s3_bucket.my_s3_bucket.arn}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:DeleteObjectVersion",
        "s3:DeleteObject",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.my_s3_bucket.arn}/*"
      ]
    }
  ]
}
EOF
}

# -----------------------------------------------------------------------------
# END OF S3
# Note that in my_fargate_api, we also added a policy and environment variable
# -----------------------------------------------------------------------------

module "postman_test_lambda" {
  source   = "github.com/byu-oit/terraform-aws-postman-test-lambda?ref=v3.1.0"
  app_name = "${local.name}-${var.env}"
  postman_collections = [
    {
      collection  = var.deploy_test_postman_collection
      environment = var.deploy_test_postman_environment
    }
  ]
  role_permissions_boundary_arn = module.acs.role_permissions_boundary.arn
  tags                          = local.tags
}

output "url" {
  value = module.my_fargate_api.dns_record.name
}

output "codedeploy_app_name" {
  value = module.my_fargate_api.codedeploy_deployment_group.app_name
}

output "codedeploy_deployment_group_name" {
  value = module.my_fargate_api.codedeploy_deployment_group.deployment_group_name
}

output "codedeploy_appspec_json_file" {
  value = module.my_fargate_api.codedeploy_appspec_json_file
}
