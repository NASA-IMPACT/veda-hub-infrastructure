/*
  This file provides resources _per hub and role_. Each role is tied to a
  specific k8s ServiceAccount allowed to assume the role.

  - Role                 - for use by k8s ServiceAccount (user-sa, admin-sa)
  - Policy               - if extra_iam_policy is declared
  - RolePolicyAttachment - if extra_iam_policy is declared
*/

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}



locals {
  # Nested for loop, thanks to https://www.daveperrett.com/articles/2021/08/19/nested-for-each-with-terraform/
  hub_to_role_mapping = flatten([
    for hub, hub_value in var.hub_cloud_permissions : [
      for ksa_name, cloud_permissions in hub_value : {
        // Most hubs only use `user-sa`, so we use just the hub name for the IAM
        // role for user-sa. `user-sa` was also the only service account supported
        // for a long time, so this special casing reduces the amount of work
        // we needed to do to introduce other service accounts.
        iam_role_name     = ksa_name == "user-sa" ? hub : "${hub}-${ksa_name}"
        hub               = hub
        ksa_name          = ksa_name
        cloud_permissions = cloud_permissions
      }
    ]
  ])
}



data "aws_iam_policy_document" "irsa_role_assume" {
  for_each = { for index, hr in local.hub_to_role_mapping : hr.iam_role_name => hr }
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"

      identifiers = [
        "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}"
      ]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values = [
        "system:serviceaccount:${each.value.hub}:${each.value.ksa_name}"
      ]
    }
  }
}

resource "aws_iam_role" "irsa_role" {
  for_each = { for index, hr in local.hub_to_role_mapping : hr.iam_role_name => hr }
  name     = "${var.cluster_name}-${each.key}"
  tags     = var.tags

  assume_role_policy = data.aws_iam_policy_document.irsa_role_assume[each.key].json
}



resource "aws_iam_policy" "extra_user_policy" {
  for_each = { for index, hr in local.hub_to_role_mapping : hr.iam_role_name => hr if hr.cloud_permissions.extra_iam_policy != "" }
  name     = "${var.cluster_name}-${each.key}-extra-user-policy"
  tags     = var.tags

  description = "Extra permissions granted to users on hub ${each.key} on ${var.cluster_name}"
  policy      = each.value.cloud_permissions.extra_iam_policy
}

resource "aws_iam_role_policy_attachment" "extra_user_policy" {
  for_each   = { for index, hr in local.hub_to_role_mapping : hr.iam_role_name => hr if hr.cloud_permissions.extra_iam_policy != "" }
  role       = aws_iam_role.irsa_role[each.key].name
  policy_arn = aws_iam_policy.extra_user_policy[each.key].arn
}



output "kubernetes_sa_annotations" {
  value = {
    for index, hr in local.hub_to_role_mapping :
    hr.iam_role_name => "eks.amazonaws.com/role-arn: ${aws_iam_role.irsa_role[hr.iam_role_name].arn}"
  }
  description = <<-EOT
  Annotations to apply to userServiceAccount in each hub to enable cloud permissions for them.

  Helm, not terraform, control namespace creation for us. This makes it quite difficult
  to create the appropriate kubernetes service account attached to the Google Cloud Service
  Account in the appropriate namespace. Instead, this output provides the list of annotations
  to be applied to the kubernetes service account used by jupyter and dask pods in a given hub.
  This should be specified under userServiceAccount.annotations (or basehub.userServiceAccount.annotations
  in case of daskhub) on a values file created specifically for that hub.
  EOT
}
