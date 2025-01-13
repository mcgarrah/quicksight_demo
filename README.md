# AWS Quicksight Demonstration

## Summary

A goal of this repository is to automate as much as possible from the above posts the manual steps in Terraform and convert the CloudFormation to Terraform where possible. Also, updating the Python Lambda layers and code to more current versions of libraries and runtimes is in scope as well.

This Quicksight Demo is based on the following AWS Business Intelligence Blog posts:

- [Federate Amazon QuickSight access with Okta](https://aws.amazon.com/blogs/business-intelligence/federate-amazon-quicksight-access-with-okta/)

- [Sync users and groups from Okta with Amazon QuickSight](https://aws.amazon.com/blogs/business-intelligence/sync-users-and-groups-from-okta-with-amazon-quicksight/)

- [Tutorial: Amazon QuickSight and IAM identity federation](https://docs.aws.amazon.com/quicksight/latest/user/tutorial-okta-quicksight.html)

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

``` json
resource "aws_lambda_layer_version" "lambda_layer" {
  compatible_architectures = ["arm64", "x86_64"]
  compatible_runtimes      = ["python3.7", "python3.8", "python3.9"]
```

``` json
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
