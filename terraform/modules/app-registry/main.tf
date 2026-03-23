resource "aws_servicecatalogappregistry_application" "app_registry" {
  name        = "${var.app}-${var.env}"
  description = "${var.app}-${var.env} application"
}

resource "aws_servicecatalogappregistry_attribute_group" "app_registry_attributes" {
  name        = "${var.app}-${var.env}-attributes"
  description = "Metadata for ${var.app}-${var.env}"

  attributes = jsonencode({
    owner     = var.owner
    repo      = var.repo
    language  = var.language
    framework = var.framework
    env       = var.env
  })

  tags = aws_servicecatalogappregistry_application.app_registry.application_tag
}

resource "aws_servicecatalogappregistry_attribute_group_association" "app_registry_attributes_association" {
  application_id     = aws_servicecatalogappregistry_application.app_registry.id
  attribute_group_id = aws_servicecatalogappregistry_attribute_group.app_registry_attributes.id
}