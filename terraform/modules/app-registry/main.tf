resource "aws_servicecatalogappregistry_application" "app_registry" {
  name        = "${var.app}"
  description = "${var.app} application"
}

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

resource "aws_servicecatalogappregistry_attribute_group_association" "app_registry_attributes_association" {
  application_id     = aws_servicecatalogappregistry_application.app_registry.id
  attribute_group_id = aws_servicecatalogappregistry_attribute_group.app_registry_attributes.id
}