output "project" {
  value = {
    provider    = "aws"
    id          = aws_organizations_account.this.id
    console_url = var.portal_url
    grants      = [for arn in var.permission_set_arns : "group ${var.group_display_name} has ${arn}"]
  }
}
