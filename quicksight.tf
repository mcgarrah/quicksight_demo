# Quicksight Module
module "quicksight" {
  source                        = "./modules/quicksight"
  #version                      = "0.0.0"
  quicksight_namespace          = "default"
  okta_api_token                = var.okta_api_token
  okta_domain                   = "https://auth.mcgarrah.org"
  okta_quicksight_app_id        = "TOBEREPLACED"
  quicksight_admin_user_name    = "mcgarrah@mcgarrah.org"
  quicksight_okta_oidc_provider = "OKTA_Quicksight"
  vpc_id                        = var.vpc_id
  vpc_subnet_ids                = var.vpc_subnet_ids
}

# Protecting as Secret
variable "okta_api_token" {}

#
# TODO: Make the schedule and state variables for module
#

# resource "aws_cloudwatch_event_rule" "OktaQSSyncEventRule" {
#   name                = "OktaQSSyncEventsRule"
#   schedule_expression = "cron(0 12 * * ? *)"
#   state               = "DISABLED"
#   # Leave the scheduled event disabled until testing
#   #state               = "ENABLED"
# }
