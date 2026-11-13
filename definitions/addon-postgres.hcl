# A PostgreSQL database for a service on the platform. Every service that
# attaches the add-on on one gcp binding shares a Cloud SQL instance in the
# platform's project, and gets a database of its own there, which only its
# runtime identity (run-<service>) can use, with IAM database
# authentication: no password exists. Anvil creates the instance with the
# first tenant and deletes it with the last.
#
# Anvil creates each database over a connection to the instance, as an
# admin service account its identity impersonates, so the server needs
# network access to the instance (docs/gcp-setup.md in anvil).
addon "postgres" {
  title       = "PostgreSQL database"
  deployments = ["gcp"]

  # How instances are run, for every service
  # (settings "addon_postgres" { ... } in the server's configuration).
  settings {
    tier              = optional(string, "db-f1-micro")
    database_version  = optional(string, "POSTGRES_16")
    high_availability = optional(bool, false)
  }

  instance {
    provider "google" {
      source = "hashicorp/google"
      config = {
        project = binding.project_id
        region  = binding.region
      }
    }

    component "server" {
      module = "../components/cloudsql-instance"
      inputs = {
        name              = anvil.name
        project_id        = binding.project_id
        region            = binding.region
        tier              = settings.tier
        database_version  = settings.database_version
        high_availability = settings.high_availability
      }
    }

    outputs = component.server.instance
  }

  tenant {
    provider "postgresql" {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.25"
      config = {
        scheme                              = "gcppostgres"
        host                                = instance.connection_name
        port                                = 5432
        database                            = "postgres"
        username                            = instance.admin_user
        gcp_iam_impersonate_service_account = instance.admin_service_account
        superuser                           = false
      }
    }

    component "database" {
      module = "../components/cloudsql-tenant"
      inputs = {
        service    = anvil.name
        project_id = instance.project_id
        instance   = instance.name
        admin_user = instance.admin_user
      }
    }

    # Repository variables for CI, beside the gcp deployment's: the service
    # connects with the Cloud SQL connector as its runtime identity.
    exports = {
      ANVIL_DB_INSTANCE = instance.connection_name
      ANVIL_DB_NAME     = component.database.database.name
      ANVIL_DB_USER     = component.database.database.user
    }
  }

  lifecycle {
    # The service's database: a detach or force delete drops it.
    stateful = ["database.postgresql_database.this"]
  }
}
