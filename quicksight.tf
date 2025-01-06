#
# Provisioning AWS Quicksight Services and Resources
#

# Notes:
#
# 1. The IAM Roles/Policy depend on the SAML-PROVIDER "OKTA_Quicksight" being created but "OKTA_Quicksight". This provider may be done post-execution of this code.
# 2. The creation of the Quicksight Service and associated resource require the outputs of this TF file for SG, VPC, IAM Role, and Subnets
# 3. An IAM User for OKTA integration is required for linking the OKTA_Quicksight provider to IAM Providers and not provisioned here. Possible extension later.
# 4. OKTA_API_TOKEN should not be saved in code as it is a secret value
# 5. QUICKSIGHT_ADMIN_USER_NAME is the full admin user in the Quicksight Users list that inherets all resources during a deletion of users.
#

variable "namespace" {
  type        = string
  default     = "default"
  description = "Namespace"
}

variable "okta_api_token" {
  type        = string
  description = "This is the keys that you generate in the previous step, these keys will allow Lambda functions to make User/Group/Application API calls."
}

variable "okta_domain" {
  type        = string
  description = "This is your OKTA domain Url"
}

variable "okta_quicksight_app_id" {
  type        = string
  description = "This is the QuickSight application ID that is generated in OKTA when you create your QuickSight application in OKTA"
}

variable "quicksight_admin_user_name" {
  type        = string
  description = "This is the UserName from QuickSight for an Administrator to whom all the orphaned assets will be assigned when an Author User is deleted from QuickSight"
}

variable "quicksight_okta_oidc_provider" {
  type        = string
  description = "This is the IAM OIDC Provider for QuickSight manually generated during the Okta integration steps"
  default = "OKTA_Quicksight"
}


#
# From Federate Okta User:
# https://aws.amazon.com/blogs/business-intelligence/federate-amazon-quicksight-access-with-okta/
#

# Reader Role/Policy
resource "aws_iam_role" "quicksight_createreader_role" {
  name        = "QuickSightOktaCreateReader"
  description = "IAM Role for Quicksight CreateReader"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Effect = "Allow"
            Principal = {
                Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:saml-provider/${var.quicksight_okta_oidc_provider}"
            }
            Action = "sts:AssumeRoleWithSAML"
            Condition = {
                StringEquals = {
                    "SAML:aud" = "https://signin.aws.amazon.com/saml"
                }
            }
        }
    ]
  })
  inline_policy {
    name = "QuickSightOktaCreateReader"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid = "QuicksightOktaCreateReader"
          Effect = "Allow"
          Action = "quicksight:CreateReader"
          Resource = ["*"]
        }
      ]
    })
  }
}

# Author Role/Policy
resource "aws_iam_role" "quicksight_createauthor_role" {
  name        = "QuickSightOktaCreateAuthor"
  description = "IAM Role for Quicksight CreateAuthor"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Effect = "Allow"
            Principal = {
                Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:saml-provider/${var.quicksight_okta_oidc_provider}"
            }
            Action = "sts:AssumeRoleWithSAML"
            Condition = {
                StringEquals = {
                    "SAML:aud" = "https://signin.aws.amazon.com/saml"
                }
            }
        }
    ]
  })
  inline_policy {
    name = "QuickSightOktaCreateAuthor"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid = "QuicksightOktaCreateAuthor"
          Effect = "Allow"
          Action = "quicksight:CreateUser"
          Resource = ["*"]
        }
      ]
    })
  }
}

# Admin Role/Policy
resource "aws_iam_role" "quicksight_createadmin_role" {
  name        = "QuickSightOktaCreateAdmin"
  description = "IAM Role for Quicksight CreateAdmin"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Effect = "Allow"
            Principal = {
                Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:saml-provider/${var.quicksight_okta_oidc_provider}"
            }
            Action = "sts:AssumeRoleWithSAML"
            Condition = {
                StringEquals = {
                    "SAML:aud" = "https://signin.aws.amazon.com/saml"
                }
            }
        }
    ]
  })
  inline_policy {
    name = "QuicksightOktaCreateAdmin"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid = "QuicksightOktaCreateAdmin"
          Effect = "Allow"
          Action = "quicksight:CreateAdmin"
          Resource = ["*"]
        }
      ]
    })
  }
}

# Federated Role/Policy
# TODO: Add missing Federate IAM Role


#
# Necessary Quicksight resource being provisioned
#

# Quicksight SG for access to VPC resources

resource "aws_security_group" "quicksight_sg" {
  name        = "quicksight-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = var.vpc_id
  tags = {
    Name = "quicksight_sg"
  }
}

# TODO FIX CIDR RANGE for VPN and VPC range
resource "aws_vpc_security_group_ingress_rule" "allow_inbound_tls_ipv4" {
  security_group_id = aws_security_group.quicksight_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

# TODO FIX CIDR RANGE for VPN and VPC range
resource "aws_vpc_security_group_ingress_rule" "allow_inbound_remoteSQLServer" {
  security_group_id = aws_security_group.quicksight_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 1433
  ip_protocol       = "tcp"
  to_port           = 1433
}

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound_traffic" {
  security_group_id = aws_security_group.quicksight_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


# Quicksight IAM Role/Policy for VPC Connection

resource "aws_iam_role" "quicksight-vpc-service-account" {
  name        = "QuickSightVPCConnectionRole"
  description = "IAM Role for Quicksight VPC Connection Execution Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "quicksight.amazonaws.com"
        }
      }
    ]
  })
  inline_policy {
    name = "quicksight-vpc-service-account"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "ec2:CreateNetworkInterface",
            "ec2:ModifyNetworkInterfaceAttribute",
            "ec2:DeleteNetworkInterface",
            "ec2:DescribeSubnets",
            "ec2:DescribeSecurityGroups"
          ]
          Resource = ["*"]
        }
      ]
    })
  }
}


#
# Okta Synchromization from:
# https://aws.amazon.com/blogs/business-intelligence/sync-users-and-groups-from-okta-with-amazon-quicksight/
#

resource "aws_lambda_layer_version" "lambda_layer" {
  compatible_architectures = ["arm64", "x86_64"]
  compatible_runtimes      = ["python3.7", "python3.8", "python3.9"]
  s3_bucket                = "adhocdatabucket"
  s3_key                   = "request_packages.zip"
  description              = "This layer provides all the required request objects to be able to make API calls to Okta"
  layer_name               = "request_packages"
}

resource "aws_lambda_function" "oktagroupsync" {
  function_name = "okta-group-sync"
  role          = aws_iam_role.oktagroupsyncrole.arn
  runtime       = "python3.9"
  timeout       = 900
  memory_size   = 1024
  handler       = "lambda_function.lambda_handler"
  s3_bucket     = "adhocdatabucket"
  s3_key        = "okta-group-sync.zip"
  layers        = [aws_lambda_layer_version.lambda_layer.arn]

  environment {
    variables = {
      namespace              = var.namespace
      okta_api_token         = var.okta_api_token
      okta_domain            = "https://${var.okta_domain}"
      okta_quicksight_app_id = var.okta_quicksight_app_id
    }
  }
}

resource "aws_iam_role" "oktagroupsyncrole" {
  name = "okta-group-sync-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  inline_policy {
    name = "quicksight_group_sync_policy_for_okta"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
          Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/okta-*:*"
        },
        {
          Effect   = "Allow"
          Action   = ["quicksight:CreateGroup", "quicksight:ListGroups", "quicksight:DeleteGroup"]
          Resource = "arn:aws:quicksight:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:group/default/*"
        }
      ]
    })
  }
}

resource "aws_lambda_function" "oktausersync" {
  function_name = "okta-user-sync"
  role          = aws_iam_role.oktausersyncrole.arn
  runtime       = "python3.9"
  timeout       = 900
  memory_size   = 1024
  handler       = "lambda_function.lambda_handler"
  s3_bucket     = "adhocdatabucket"
  s3_key        = "okta-user-sync.zip"
  layers        = [aws_lambda_layer_version.lambda_layer.arn]

  environment {
    variables = {
      namespace              = var.namespace
      okta_api_token         = var.okta_api_token
      okta_domain            = "https://${var.okta_domain}"
      okta_quicksight_app_id = var.okta_quicksight_app_id
    }
  }
}

resource "aws_iam_role" "oktausersyncrole" {
  name = "okta-user-sync-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  inline_policy {
    name = "quicksight_user_sync_policy_for_okta"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
          Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/okta-*:*"
        },
        {
          Effect   = "Allow"
          Action   = [
            "quicksight:CreateReader", "quicksight:CreateUser", "quicksight:DeleteUser", "quicksight:DeleteGroupMembership",
            "quicksight:ListUserGroups", "quicksight:DescribeUser", "quicksight:CreateAdmin", "quicksight:CreateGroupMembership",
            "quicksight:ListUsers", "quicksight:UpdateUser", "quicksight:DeleteUserByPrincipalId", "quicksight:RegisterUser",
            "iam:ListAttachedRolePolicies", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:ListRolePolicies", "iam:GetRolePolicy"
          ]
          Resource = [
            "arn:aws:quicksight:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:user/default/*",
            "arn:aws:quicksight:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:group/default/*",
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/QuickSightOktaReaderRole",
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/QuickSightOktaAuthorRole",
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/QuickSightOktaAdminRole",
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/QuickSightOktaCreateReaderPolicy",
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/QuickSightOktaCreateAuthorPolicy",
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/QuickSightOktaCreateAdminPolicy"
          ]
        }
      ]
    })
  }
}

resource "aws_lambda_function" "oktauserdeprovisioning" {
  function_name = "okta-user-deprovisioning"
  role          = aws_iam_role.oktauserdeprovisioningrole.arn
  runtime       = "python3.9"
  timeout       = 900
  memory_size   = 1024
  handler       = "lambda_function.lambda_handler"
  s3_bucket     = "adhocdatabucket"
  s3_key        = "okta-user-deprovisioning.zip"
  layers        = [aws_lambda_layer_version.lambda_layer.arn]

  environment {
    variables = {
      namespace                  = var.namespace
      okta_api_token             = var.okta_api_token
      okta_domain                = "https://${var.okta_domain}"
      okta_quicksight_app_id     = var.okta_quicksight_app_id
      transfer_assets_to         = var.quicksight_admin_user_name
      quicksight_admin_iam_role  = aws_iam_role.quicksight_createadmin_role.arn
      quicksight_author_iam_role = aws_iam_role.quicksight_createauthor_role.arn
      quicksight_reader_iam_role = aws_iam_role.quicksight_createreader_role.arn
    }
  }
}

resource "aws_iam_role" "oktauserdeprovisioningrole" {
  name = "okta-user-deprovisioning-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  inline_policy {
    name = "okta-user-deprovisioning-policy-for-okta"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
          Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/okta-*:*"
        },
        {
          Effect   = "Allow"
          Action   = [
            "quicksight:ListDashboards", "quicksight:UpdateThemePermissions", "quicksight:DescribeUser", "quicksight:ListDataSets",
            "quicksight:ListUsers", "quicksight:DescribeDataSetPermissions", "quicksight:UpdateDataSetPermissions", "quicksight:ListAnalyses",
            "quicksight:ListDataSources", "quicksight:UpdateDataSourcePermissions", "quicksight:UpdateAnalysisPermissions",
            "quicksight:DescribeDataSourcePermissions", "quicksight:DeleteUser", "quicksight:UpdateDashboardPermissions",
            "quicksight:DescribeAnalysisPermissions", "quicksight:DescribeThemePermissions", "quicksight:ListThemes",
            "quicksight:DescribeDashboardPermissions"
          ]
          Resource = [
            "arn:aws:quicksight:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:user/default/*",
            "arn:aws:quicksight:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:group/default/*",
            "arn:aws:quicksight:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:analysis/*",
            "arn:aws:quicksight:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dashboard/*",
            "arn:aws:quicksight:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:theme/*",
            "arn:aws:quicksight:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dataset/*",
            "arn:aws:quicksight:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:datasource/*"
          ]
        }
      ]
    })
  }
}

resource "aws_sfn_state_machine" "OktaQuickSightSync" {
  name     = "OktaQuickSightSync"
  role_arn = aws_iam_role.StateMachineRole.arn

  definition = jsonencode({
    Comment = "A description of my state machine"
    StartAt = "Quicksight-Okta-Group-Sync"
    States = {
      "Quicksight-Okta-Group-Sync" = {
        Type    = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.oktagroupsync.arn
        }
        Retry = [{
          ErrorEquals = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
          IntervalSeconds = 2
          MaxAttempts = 6
          BackoffRate = 2
        }]
        Next = "Quicksight-Okta-User-Sync"
      }
      "Quicksight-Okta-User-Sync" = {
        Type    = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.oktausersync.arn
        }
        Retry = [{
          ErrorEquals = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
          IntervalSeconds = 2
          MaxAttempts = 6
          BackoffRate = 2
        }]
        Next = "Quicksight-Okta-User-Deprovisioning"
      }
      "Quicksight-Okta-User-Deprovisioning" = {
        Type    = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.oktauserdeprovisioning.arn
        }
        Retry = [{
          ErrorEquals = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
          IntervalSeconds = 2
          MaxAttempts = 6
          BackoffRate = 2
        }]
        End = true
      }
    }
  })
}

resource "aws_iam_role" "StateMachineRole" {
  name = "StateMachineRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = {
        Service = "states.amazonaws.com"
      }
    }]
  })

  inline_policy {
    name = "OktaQSInvokeTaskFunctions"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = [
          aws_lambda_function.oktagroupsync.arn,
          aws_lambda_function.oktausersync.arn,
          aws_lambda_function.oktauserdeprovisioning.arn
        ]
      }]
    })
  }

  inline_policy {
    name = "DeliverToCloudWatchLogPolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogDelivery", "logs:GetLogDelivery", "logs:UpdateLogDelivery", "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries", "logs:PutLogEvents", "logs:PutResourcePolicy", "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }]
    })
  }
}

resource "aws_iam_role" "EventsRuleRole" {
  name = "EventsRuleRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = {
        Service = "events.amazonaws.com"
      }
    }]
  })

  inline_policy {
    name = "StartOktaQSStateMachinePolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = aws_sfn_state_machine.OktaQuickSightSync.arn
      }]
    })
  }
}

resource "aws_cloudwatch_event_rule" "OktaQSSyncEventRule" {
  name                = "OktaQSSyncEventsRule"
  schedule_expression = "cron(0 12 * * ? *)"
  state               = "DISABLED"

  target {
    arn = aws_sfn_state_machine.OktaQuickSightSync.arn
    id  = "OktaQSSync"
    role_arn = aws_iam_role.EventsRuleRole.arn
  }
}

#
# External S3 Bucket Dependency for Lambda Functions
#

# TODO: Create an S3 bucket to host these files as static known resourecs...

# request_packages.zip
# https://adhocdatabucket.s3.us-east-1.amazonaws.com/request_packages.zip
# okta-user-sync.zip
# https://adhocdatabucket.s3.us-east-1.amazonaws.com/okta-user-sync.zip
# okta-group-sync.zip
# https://adhocdatabucket.s3.us-east-1.amazonaws.com/okta-group-sync.zip
# okta-user-deprovisioning.zip
# https://adhocdatabucket.s3.us-east-1.amazonaws.com/okta-user-deprovisioning.zip


#
# Outputs for manual provisioning of Quicksight Service
#

output "quicksight-vpc-id" {
  description = "Quicksight VPC Connection VPC ID"
  value       = var.vpc_id
}
output "quicksight-sg-id" {
  description = "Quicksight VPC Connection Security Group IDs"
  value       = aws_security_group.quicksight_sg.id
}

output "quicksight-iam-role" {
  description = "Quicksight VPC Connection Execution Role"
  value       = aws_iam_role.quicksight-vpc-service-account.name
}

output "quicksight-subnet-ids" {
  description = "Quicksight VPC Connection Subnet IDs"
  value       = var.compute_subnet_ids
}