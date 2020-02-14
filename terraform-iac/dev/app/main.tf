terraform {
  backend "s3" {
    bucket         = "terraform-state-storage-613597733241"
    dynamodb_table = "terraform-state-lock-613597733241"
    key            = "hello-world-docker-api-dev/app.tfstate"
    region         = "us-west-2"
  }
}

provider "aws" {
  version = "~> 2.42"
  region  = "us-west-2"
}

variable "image_tag" {
  type = string
}

data "aws_ecr_repository" "my_ecr_repo" {
  name = "hello-world-docker-api-dev"
}

module "my_fargate_api" {
  source              = "github.com/byu-oit/terraform-aws-standard-fargate?ref=v1.0.2"
  dept_abbr           = "oit"
  app_name            = "hello-world-api-dev" #some of these resources have a limit on the name length
  env                 = "prd"
  health_check_path   = "/health"
  image_port          = 8080
  container_image_url = "${data.aws_ecr_repository.my_ecr_repo.repository_url}:${var.image_tag}"
  vpn_to_campus       = false
  task_memory         = 1024
  task_cpu            = 512
  task_policies       = [aws_iam_policy.my_dynamo_policy.arn]

  container_env_variables = {
    DYNAMO_TABLE_NAME = aws_dynamodb_table.my_dynamo_table.name
  }

  container_secrets = {
    "SOME_SECRET" = "/hello-world-docker-api/dev/some-secret"
  }

  tags = {
    env              = "dev"
    data-sensitivity = "public"
    repo             = "https://github.com/byu-oit/hello-world-docker-api"
  }
}

////TODO: Switch to use a higher level module, maybe.
resource "aws_dynamodb_table" "my_dynamo_table" {
  name         = "hello-world-docker-api-dev"
  hash_key     = "my_key_field"
  billing_mode = "PAY_PER_REQUEST"
  attribute {
    name = "my_key_field"
    type = "S"
  }
}
//TODO: Add tags

resource "aws_iam_policy" "my_dynamo_policy" {
  name        = "hello-world-docker-api-dynamo-dev"
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

output "url" {
  value = module.my_fargate_api.dns_record
}

output "appspec" {
  value = module.my_fargate_api.codedeploy_appspec_json
}
