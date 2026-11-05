output "project" {
  value = {
    provider    = "aws"
    id          = aws_organizations_account.this.id
    console_url = var.portal_url
  }
}
