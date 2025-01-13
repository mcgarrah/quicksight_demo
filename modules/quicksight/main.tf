#
# Provisioning AWS Quicksight Services and Resources
#

#
# Notes:
#

#
# 1. The IAM Roles/Policy depend on the SAML-PROVIDER "OKTA_Quicksight" being created but "OKTA_Quicksight". This provider may be done post-execution of this code.
# 2. The creation of the Quicksight Service and associated resource require the outputs of this TF file for SG, VPC, IAM Role, and Subnets
# 3. An IAM User for OKTA integration is required for linking the OKTA_Quicksight provider to IAM Providers and not provisioned here. Possible extension later.
# 4. OKTA_API_TOKEN should not be saved in code as it is a secret value
# 5. QUICKSIGHT_ADMIN_USER_NAME is the full admin user in the Quicksight Users list that inherets all resources during a deletion of users.
#


#
# From Federate Okta User:
#   https://aws.amazon.com/blogs/business-intelligence/federate-amazon-quicksight-access-with-okta/
#   https://docs.aws.amazon.com/quicksight/latest/user/tutorial-okta-quicksight.html
#

# Federated Role/Policy
resource "aws_iam_role" "quicksight_federated_role" {
  name        = "QuicksightOktaFederatedRole"
  description = "IAM Role for Quicksight Federation"
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
    name = "QuicksightOktaFederatedPolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid = "QuicksightOktaFederatedPolicy"
          Effect = "Allow"
          Action = "quicksight:CreateReader"
          "Resource": [
                "arn:aws:quicksight::${data.aws_caller_identity.current.account_id}:user/$${aws:userid}"
          ]
        }
      ]
    })
  }
}

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


#
# Necessary Quicksight resource being provisioned
#

# Quicksight SG for access to VPC resources

resource "aws_security_group" "quicksight_sg" {
  name        = "quicksight-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  #vpc_id      = var.vpc_id
  vpc_id      = local.dynamic_vpc_id
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
      namespace              = var.quicksight_namespace
      okta_api_token         = var.okta_api_token
      okta_domain            = "https://${var.okta_domain}"
      okta_quicksight_app_id = var.okta_quicksight_app_id
    }
  }
}

resource "aws_iam_role" "oktagroupsyncrole" {
  name = "okta-group-sync-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
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
      namespace              = var.quicksight_namespace
      okta_api_token         = var.okta_api_token
      okta_domain            = "https://${var.okta_domain}"
      okta_quicksight_app_id = var.okta_quicksight_app_id
    }
  }
}

resource "aws_iam_role" "oktausersyncrole" {
  name = "okta-user-sync-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
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
      namespace                  = var.quicksight_namespace
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
    Version = "2012-10-17"
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
  # schedule_expression = "cron(0 12 * * ? *)"
  # state               = "DISABLED"
  schedule_expression = var.sync_cron_express
  state               = var.sync_enabled 
}

resource "aws_cloudwatch_event_target" "OktaQSSyncEventTarget" {
  rule      = aws_cloudwatch_event_rule.OktaQSSyncEventRule.name
  arn       = aws_sfn_state_machine.OktaQuickSightSync.arn
  role_arn  = aws_iam_role.EventsRuleRole.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_trigger" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.oktagroupsync.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.OktaQSSyncEventRule.arn
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
# OIDC Okta Provider
#

# TODO: OIDC Provider creation for Okta

#
# NEED the OKTA XML file and IAM OIDC Provider code here... but the XML file is a secret
#


#
# AWS VPC ID retrieved and validated
#

# Check if var.vpc_id is specified
locals {
  use_provided_vpc_id = var.vpc_id != null
}

# Fetch all VPCs if var.vpc_id is not specified
data "aws_vpcs" "all" {
  count = !local.use_provided_vpc_id ? 1 : 0
}

locals {
  all_vpcs = data.aws_vpcs.all
  vpc_count = length(local.all_vpcs)
}

locals {
  dynamic_vpc_id = var.vpc_id != null ? var.vpc_id : (local.vpc_count == 1 && !local.use_provided_vpc_id) ? local.all_vpcs[0].ids[0] : null
}

# Error handling no vpc found
resource "null_resource" "error_no_vpcs" {
  provisioner "local-exec" {
    command = <<-EOT
      if [ -z "${local.dynamic_vpc_id}" ]; then
        echo "Error: No VPCs found. Please ensure at least one VPC exists in your environment or provide a vpc_id." >&2
        exit 1
      fi
    EOT
  }
}

# Error handling too many vpcs found
resource "null_resource" "error_multiple_vpcs" {
  provisioner "local-exec" {
    command = <<-EOT
      if [ "${local.vpc_count}" -gt 1 ]; then
        echo "Error: Multiple VPCs detected. Please ensure only one VPC exists in your environment or provide a vpc_id." >&2
        exit 1
      fi
    EOT
  }
}


#
# AWS VPC Subnet ID list retrieved and validated
#

# Check if var.vpc_subnet_ids is specified (assuming defined in variables.tf)
locals {
  use_provided_subnet_ids = var.vpc_subnet_ids != null && length(var.vpc_subnet_ids) > 0
}

# Condition to fetch all subnets only when var.vpc_subnet_ids is not specified
data "aws_subnets" "all" {
    filter {
    name   = "vpc-id"
    values = [local.dynamic_vpc_id]
  }
  count = !local.use_provided_subnet_ids ? 1 : 0
}

locals {
  subnet_count = length(data.aws_subnets.all) 
}

locals {
  # Use provided subnet IDs if specified
  dynamic_subnet_ids = local.use_provided_subnet_ids ? var.vpc_subnet_ids : [
    for subnet in data.aws_subnets.all : subnet.id 
    if local.subnet_count > 0 && !local.use_provided_subnet_ids
  ]
}

# Error handling no subnets found
resource "null_resource" "error_no_subnets" {
  provisioner "local-exec" {
    command = <<-EOT
      if [ -z "${join(",", local.dynamic_subnet_ids)}" ]; then
        echo "Error: No Subnets found in the specified VPC (VPC ID: ${var.vpc_id}). Please provide a list of subnet_ids." >&2
        exit 1
      fi
    EOT
  }
}


#
# Shared Outputs for AWS Quicksight Resource creation

output "quicksight-vpc-id" {
  description = "Quicksight VPC Connection VPC ID"
  value       = local.dynamic_vpc_id
}

output "quicksight-subnet-ids" {
  description = "Quicksight VPC Connection Subnet IDs"
  value       = local.dynamic_subnet_ids
}

output "quicksight-sg-id" {
  description = "Quicksight VPC Connection Security Group IDs"
  value       = aws_security_group.quicksight_sg.id
}

output "quicksight-iam-role" {
  description = "Quicksight VPC Connection Execution Role"
  value       = aws_iam_role.quicksight-vpc-service-account.name
}
