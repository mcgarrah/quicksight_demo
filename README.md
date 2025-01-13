# AWS Quicksight Demonstration

## Summary

A goal of this repository is to automate as much as possible from the above posts the manual steps in Terraform and convert the CloudFormation to Terraform where possible. Also, updating the Python Lambda layers and code to more current versions of libraries and runtimes is in scope as well.

This Quicksight Demo is based on the following AWS Business Intelligence Blog posts:

- [Federate Amazon QuickSight access with Okta](https://aws.amazon.com/blogs/business-intelligence/federate-amazon-quicksight-access-with-okta/)

- [Sync users and groups from Okta with Amazon QuickSight](https://aws.amazon.com/blogs/business-intelligence/sync-users-and-groups-from-okta-with-amazon-quicksight/)

- [Tutorial: Amazon QuickSight and IAM identity federation](https://docs.aws.amazon.com/quicksight/latest/user/tutorial-okta-quicksight.html)

## Overview

This is a Terraform Module for provisioning AWS Quicksight Services and Resources.

The code defines several AWS resources required to set up Okta integration with AWS Quicksight.

Here's a breakdown of the resources:

* **IAM Roles:**
  * `QuicksightOktaFederatedRole`: IAM role for Quicksight federation with Okta.
  * `QuicksightCreatereaderRole`: IAM role for users to create Quicksight readers.
  * `QuicksightCreateauthorRole`: IAM role for users to create Quicksight authors.
  * `QuicksightCreateAdminRole`: IAM role for users to create Quicksight admins.
  * `QuickSightVPCServiceAccountRole`: IAM role for Quicksight to access VPC resources.
  * `oktagroupsyncrole`: IAM role for the lambda function `okta-group-sync` to perform group sync between Okta and Quicksight.
  * `oktausersyncrole`: IAM role for the lambda function `okta-user-sync` to perform user sync between Okta and Quicksight.
  * `oktauserdeprovisioningrole`: IAM role for the lambda function `okta-user-deprovisioning` to deprovision users from Quicksight.
  * `StateMachineRole`: IAM role for the Step Functions State Machine that executes the Okta-Quicksight sync process.
  * `EventsRuleRole`: IAM role for the CloudWatch Event rule to trigger the Okta-Quicksight sync Step Functions State Machine.

* **Security Groups:**
  * `quicksight-sg`: Security group for Quicksight allowing inbound TLS traffic and all outbound traffic.

* **Lambda Functions:**
  * `oktagroupsync`: Lambda function to synchronize groups from Okta to Quicksight.
  * `oktausersync`: Lambda function to synchronize users from Okta to Quicksight.
  * `oktauserdeprovisioning`: Lambda function to deprovision users from Quicksight.

* **Step Functions State Machine:**
  * `OktaQuickSightSync`: State machine that orchestrates the Okta-Quicksight sync process by calling the lambda functions for group sync, user sync, and user deprovisioning.

* **CloudWatch Event Rule:**
  * `OktaQSSyncEventRule`: CloudWatch event rule that triggers the OktaQuickSightSync Step Functions State Machine based on the specified schedule.

* **IAM Permissions:**
  * `allow_cloudwatch_to_trigger`: IAM permission to allow CloudWatch to trigger the `oktagroupsync` lambda function.

**Note:** 
  * The `vpc_id` can be provided or an automatic lookup for a single VPC will be attempted.
  * The `vpc_subnet_ids` can be provided or an automatic lookup of the `vpc_id` subnets will be used.
  * The Event Bridge synchronize parameters default to `DISABLED` and noon UTC everyday. Update those to make `ENABLED`.
  * `OIDC Provider` creation for Okta is not complete. Still working on the OKTA XML file as a secret.
  * Additional work on the Python Lambda Layer and Python Lambda Code is required.

Overall, this Terraform code automates a large part of the provisioning of resources required to integrate Okta with AWS Quicksight for user and group management.

## TODO

### Manual Steps

TODO: Generate a list of manual steps required before and after running the Terraform.

### Update Lambda Layer and Lambda Runtime

The runtime and layers both need updating at some point soon. We need the manual steps to generate the ZIP files.

#### Layers information

| Library Name        | dist-info                            | PyPi URL |
| :---                | :---                                 | :---     |
| certifi             | `certifi-2022.12.7.dist-info`        | [certifi](https://pypi.org/project/certifi/) |
| charset-normalizer  | `charset_normalizer-3.1.0.dist-info` | [charset-normalizer](https://pypi.org/project/charset-normalizer/) |
| idna                | `idna-3.4.dist-info`                 | [idna](https://pypi.org/project/idna/) |
| requests            | `requests-2.28.2.dist-info`          | [requests](https://pypi.org/project/requests/) |
| urllib3             | `urllib3-1.26.15.dist-info`          | [urllib3](https://pypi.org/project/urllib3/) |

Here are the combined imports in the Python code.

``` python
import botocore
import requests
import botocore.session
import os
import json

```

#### Runtimes information

Below is the deprecation schedule for Python Lambda Runtimes.

| Name         | Identifier | Operating system    | Deprecation date | Block function create | Block function update |
| :---         | :---       | :---                | :---             | :---                  | :---                  |
| Python 3.7   | python3.7	| Amazon Linux        | Dec 4, 2023      | Jan 9, 2024           | Feb 28, 2025          |
| Python 3.8   | python3.8	| Amazon Linux 2      | Oct 14, 2024     | Feb 28, 2025          | Mar 31, 2025          |
| Python 3.9   | python3.9  | Amazon Linux 2      | Not scheduled    | Not scheduled         | Not scheduled         |
| Python 3.10  | python3.10 | Amazon Linux 2      | Not scheduled    | Not scheduled         | Not scheduled         |
| Python 3.11  | python3.11 | Amazon Linux 2      | Not scheduled    | Not scheduled         | Not scheduled         |
| Python 3.12  | python3.12 | Amazon Linux 2023   | Not scheduled    | Not scheduled         | Not scheduled         |
| Python 3.13  | python3.13 | Amazon Linux 2023   | Not scheduled    | Not scheduled         | Not scheduled         |

From: https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html (2025-01-08 5:05PM)

Segments of TF code for Lambda Layer and Lambda Function...

``` terraform
resource "aws_lambda_layer_version" "lambda_layer" {
  compatible_architectures = ["arm64", "x86_64"]
  compatible_runtimes      = ["python3.7", "python3.8", "python3.9"]
```

``` terraform
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
```
