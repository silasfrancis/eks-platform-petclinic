output "application_id"  { 
    value = aws_servicecatalogappregistry_application.app_registry.id 
}

output "application_arn" { 
    value = aws_servicecatalogappregistry_application.app_registry.arn 
}

output "application_tag" { 
    value = aws_servicecatalogappregistry_application.app_registry.application_tag 
}