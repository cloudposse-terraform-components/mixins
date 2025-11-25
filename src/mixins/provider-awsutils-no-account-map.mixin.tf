# <-- BEGIN DOC -->
#
# This mixin is meant to be added to a terraform module that wants to use the awsutils provider.
# It assumes the standard `providers.tf` file is present in the module.
#
# <-- END DOC -->

provider "awsutils" {
  region = var.region
}
