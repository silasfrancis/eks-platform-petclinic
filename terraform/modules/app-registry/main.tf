# AppRegistry Application
#
# Registers the platform as an AWS Service Catalog AppRegistry application,
# with an attribute group capturing metadata about the project (owner, repo,
# language, framework). The application_tag produced here is consumed by
# every environment's root module (via remote state) and merged into
# extended_tags, so all resources across the platform are tagged with this
# application's identity for cost allocation and resource grouping.


# The top-level application entry in AppRegistry
resource "aws_servicecatalogappregistry_application" "app_registry" {
  name        = "${var.app}"
  description = "${var.app} application"
}

# Custom metadata attributes describing the application
resource "aws_servicecatalogappregistry_attribute_group" "app_registry_attributes" {
  name        = "${var.app}-attributes"
  description = "Metadata for ${var.app} application"

  attributes = jsonencode({
    owner     = var.owner
    repo      = var.repo
    language  = var.language
    framework = var.framework
  })

  tags = aws_servicecatalogappregistry_application.app_registry.application_tag
}

# Links the attribute group to the application
resource "aws_servicecatalogappregistry_attribute_group_association" "app_registry_attributes_association" {
  application_id     = aws_servicecatalogappregistry_application.app_registry.id
  attribute_group_id = aws_servicecatalogappregistry_attribute_group.app_registry_attributes.id
}