# App Registry
# Provides application metadata and tags used across modules on both environments and resources
# No dependencies on other modules, but provides metadata used by all other modules
module "app_registry" {
  source = "../../../modules/app-registry"

  app       = var.app
  owner     = var.owner
  repo      = var.repo
  language  = var.language
  framework = var.framework
}
