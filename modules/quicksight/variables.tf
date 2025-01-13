variable "quicksight_namespace" {
  type        = string
  default     = "default"
  description = "This is the Quicksight Namespace to place Users and Groups"
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
  default     = "OKTA_Quicksight"
}

# https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-scheduled-rule-pattern.html
variable "sync_cron_express" {
  type        = string
  description = "The EventBridge cron expression for scheduling synchronization (default at noon UTC daily)"
  default     = "cron(0 12 * * ? *)"
}

variable "sync_enabled" {
  type        = string
  description = "The EventBridge state as enabled or disabled for synchronization (default disabled)"
  default     = "DISABLED"
}

variable "vpc_id" {
  type        = string
  description = "The VPC hosting Quicksight resource"
}

variable "vpc_subnet_ids" {
  type        = list(string)
  description = "The list of VPC Subnets used by Quicksight"
}
