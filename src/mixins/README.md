# Terraform Mixins

A Terraform mixin (inspired by the
[concept of the same name in OOP languages such as Python and Ruby](https://en.wikipedia.org/wiki/Mixin)) is a Terraform
configuration file that can be dropped into a root-level module, i.e. a component, in order to add additional
functionality.

Mixins are meant to encourage code reuse, leading to more simple components with less code repetition between component
to component.

<!-- prettier-ignore-start -->
<!-- BEGINNING OF TERRAFORM-MIXINS DOCS HOOK -->
## Mixin: `infra-state.mixin.tf`

This mixin is meant to be placed in a Terraform configuration outside the organization's infrastructure monorepo in order to:

1. Instantiate an AWS Provider using roles managed by the infrastructure monorepo. This is required because Cloud Posse's `providers.tf` pattern
requires an invocation of the `account-map` component’s `iam-roles` submodule, which is not present in a repository
outside of the infrastructure monorepo.
2. Retrieve outputs from a component in the infrastructure monorepo. This is required because Cloud Posse’s `remote-state` module expects
a `stacks` directory, which will not be present in other repositories, the monorepo must be cloned via a `monorepo` module
instantiation.

Because the source attribute in the `monorepo` and `remote-state` modules cannot be interpolated and refers to a monorepo
in a given organization, the following dummy placeholders have been put in place upstream and need to be replaced accordingly
when "dropped into" a Terraform configuration:

1. Infrastructure monorepo: `github.com/ACME/infrastructure`
2. Infrastructure monorepo ref: `0.1.0`

## Mixin: `introspection.mixin.tf`

This mixin is meant to be added to Terraform components in order to append a `Component` tag to all resources in the
configuration, specifying which component the resources belong to.

It's important to note that all modules and resources within the component then need to use `module.introspection.context`
and `module.introspection.tags`, respectively, rather than `module.this.context` and `module.this.tags`.

## Mixin: `provider-awsutils.mixin.tf`

This mixin is meant to be added to a terraform module that wants to use the awsutils provider.
It assumes the standard `providers.tf` file is present in the module.

## Mixin: `sops.mixin.tf`

This mixin is meant to be added to Terraform EKS components which are used in a cluster where sops-secrets-operator (see: https://github.com/isindir/sops-secrets-operator)
is deployed. It will then allow for SOPS-encrypted SopsSecret CRD manifests (such as `example.sops.yaml`) placed in a
`resources/` directory to be deployed to the cluster alongside the EKS component.

This mixin assumes that the EKS component in question follows the same pattern as `alb-controller`, `cert-manager`, `external-dns`,
etc. That is, that it has the following characteristics:

1. Has a `var.kubernetes_namespace` variable.
2. Does not already instantiate a Kubernetes provider (only the Helm provider is necessary, typically, for EKS components).

<!-- END OF TERRAFORM-MIXINS DOCS HOOK -->
<!-- prettier-ignore-end -->

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_datadog_configuration"></a> [datadog\_configuration](#module\_datadog\_configuration) | ../datadog-configuration/modules/datadog_keys | n/a |
| <a name="module_iam_roles"></a> [iam\_roles](#module\_iam\_roles) | ../../account-map/modules/iam-roles | n/a |
| <a name="module_introspection"></a> [introspection](#module\_introspection) | cloudposse/label/null | 0.25.0 |
| <a name="module_monorepo"></a> [monorepo](#module\_monorepo) | git::https://github.com/ACME/infrastructure.git | 0.1.0 |

## Resources

| Name | Type |
|------|------|
| [kubernetes_manifest.sops_secret](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [aws_eks_cluster_auth.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_helm_manifest_experiment_enabled"></a> [helm\_manifest\_experiment\_enabled](#input\_helm\_manifest\_experiment\_enabled) | Enable storing of the rendered manifest for helm\_release so the full diff of what is changing can been seen in the plan | `bool` | `false` | no |
| <a name="input_import_profile_name"></a> [import\_profile\_name](#input\_import\_profile\_name) | AWS Profile name to use when importing a resource | `string` | `null` | no |
| <a name="input_import_role_arn"></a> [import\_role\_arn](#input\_import\_role\_arn) | IAM Role ARN to use when importing a resource | `string` | `null` | no |
| <a name="input_kube_data_auth_enabled"></a> [kube\_data\_auth\_enabled](#input\_kube\_data\_auth\_enabled) | If `true`, use an `aws_eks_cluster_auth` data source to authenticate to the EKS cluster.<br/>Disabled by `kubeconfig_file_enabled` or `kube_exec_auth_enabled`. | `bool` | `false` | no |
| <a name="input_kube_exec_auth_aws_profile"></a> [kube\_exec\_auth\_aws\_profile](#input\_kube\_exec\_auth\_aws\_profile) | The AWS config profile for `aws eks get-token` to use | `string` | `""` | no |
| <a name="input_kube_exec_auth_aws_profile_enabled"></a> [kube\_exec\_auth\_aws\_profile\_enabled](#input\_kube\_exec\_auth\_aws\_profile\_enabled) | If `true`, pass `kube_exec_auth_aws_profile` as the `profile` to `aws eks get-token` | `bool` | `false` | no |
| <a name="input_kube_exec_auth_enabled"></a> [kube\_exec\_auth\_enabled](#input\_kube\_exec\_auth\_enabled) | If `true`, use the Kubernetes provider `exec` feature to execute `aws eks get-token` to authenticate to the EKS cluster.<br/>Disabled by `kubeconfig_file_enabled`, overrides `kube_data_auth_enabled`. | `bool` | `true` | no |
| <a name="input_kube_exec_auth_role_arn"></a> [kube\_exec\_auth\_role\_arn](#input\_kube\_exec\_auth\_role\_arn) | The role ARN for `aws eks get-token` to use | `string` | `""` | no |
| <a name="input_kube_exec_auth_role_arn_enabled"></a> [kube\_exec\_auth\_role\_arn\_enabled](#input\_kube\_exec\_auth\_role\_arn\_enabled) | If `true`, pass `kube_exec_auth_role_arn` as the role ARN to `aws eks get-token` | `bool` | `true` | no |
| <a name="input_kubeconfig_context"></a> [kubeconfig\_context](#input\_kubeconfig\_context) | Context to choose from the Kubernetes config file.<br/>If supplied, `kubeconfig_context_format` will be ignored. | `string` | `""` | no |
| <a name="input_kubeconfig_context_format"></a> [kubeconfig\_context\_format](#input\_kubeconfig\_context\_format) | A format string to use for creating the `kubectl` context name when<br/>`kubeconfig_file_enabled` is `true` and `kubeconfig_context` is not supplied.<br/>Must include a single `%s` which will be replaced with the cluster name. | `string` | `""` | no |
| <a name="input_kubeconfig_exec_auth_api_version"></a> [kubeconfig\_exec\_auth\_api\_version](#input\_kubeconfig\_exec\_auth\_api\_version) | The Kubernetes API version of the credentials returned by the `exec` auth plugin | `string` | `"client.authentication.k8s.io/v1beta1"` | no |
| <a name="input_kubeconfig_file"></a> [kubeconfig\_file](#input\_kubeconfig\_file) | The Kubernetes provider `config_path` setting to use when `kubeconfig_file_enabled` is `true` | `string` | `""` | no |
| <a name="input_kubeconfig_file_enabled"></a> [kubeconfig\_file\_enabled](#input\_kubeconfig\_file\_enabled) | If `true`, configure the Kubernetes provider with `kubeconfig_file` and use that kubeconfig file for authenticating to the EKS cluster | `bool` | `false` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region | `string` | n/a | yes |
| <a name="input_required_tags"></a> [required\_tags](#input\_required\_tags) | List of required tag names | `list(string)` | `[]` | no |
| <a name="input_sops_secrets"></a> [sops\_secrets](#input\_sops\_secrets) | List of SOPS-encrypted SopsSecret file names, as they appear within the directory specified by `sops_secrets_directory`. | `list(string)` | `[]` | no |
| <a name="input_sops_secrets_directory"></a> [sops\_secrets\_directory](#input\_sops\_secrets\_directory) | The directory (relative to the component) where the SOPS-encrypted SopsSecret CRD manifests exist.<br/><br/>This directory should *not* contain a trailing forward slash. | `string` | `"./resources"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_sops_secrets"></a> [sops\_secrets](#output\_sops\_secrets) | List of provisioned SopsSecret Kubernetes resources and their respective templated Secret objects. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->