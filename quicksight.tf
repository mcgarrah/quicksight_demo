# Quicksight Module
module "quicksight" {
  source                        = "./modules/quicksight"
  #version                      = "0.0.0"
  quicksight_namespace          = "default"
  okta_api_token                = var.okta_api_token
  okta_domain                   = "mcgarrah.okta.com"
  okta_quicksight_app_id        = "0bal26or5eCQPHrOq2x4"
  quicksight_admin_user_name    = "mcgarrah@mcgarrah.org"
  quicksight_okta_oidc_provider = "OKTA_Quicksight"
  vpc_id                        = var.vpc_id
  vpc_subnet_ids                = var.vpc_subnet_ids
  #sync_cron_express             = "cron(0 12 * * ? *)"
  #sync_enabled                  = "ENABLED"
  #existing_oktassouser_arn      = "arn:aws:iam::123456789012:user/OktaSSOUser"
}

# Protecting as Secret
variable "okta_api_token" {}
