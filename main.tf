Action:
1. Create a new Terraform project and initialize it using the following code:
terraform {
 required_providers {
   aws = {
     source = "hashicorp/aws"
     version = "3.60.0"
   }
   kubernetes = {
     source = "hashicorp/kubernetes"
     version = "2.6.1"
   }
 }
 required_version = ">= 1.0.0"
}
provider "aws" {
 region = "us-east-1"
}
provider "kubernetes" {}
2. Create an IAM role for the EKS cluster using the following code:
resource "aws_iam_role" "eks" {
 name = "eks-role"
 assume_role_policy = jsonencode({
   Version = "2012-10-17"
   Statement = [
     {
       Effect = "Allow"
       Principal = {
         Service = "eks.amazonaws.com"
       }
       Action = "sts:AssumeRole"
     }
   ]
 })
}
3. Create an IAM policy for the EKS cluster using the following code:
resource "aws_iam_policy" "eks" {
 name       = "eks-policy"
 description = "Allows access to EKS"
 policy = jsonencode({
   Version = "2012-10-17"
   Statement = [
     {
       Effect   = "Allow"
       Action   = [
         "eks:DescribeCluster"
       ]
       Resource = "*"
     },
     {
       Effect   = "Allow"
       Action   = [
         "eks:ListClusters"
       ]
       Resource = "*"
     }
   ]
 })
}
4. Create an EKS cluster using the following code:
resource "aws_eks_cluster" "eks" {
 name = "eks-cluster"
 role_arn = aws_iam_role.eks.arn
 vpc_config {
   subnet_ids = aws_subnet.private.*.id
 }
 depends_on = [
   aws_iam_policy_attachment.eks
 ]
}
5. Create an IAM policy attachment for the EKS cluster using the following code:
resource "aws_iam_policy_attachment" "eks" {
 name = "eks-attachment"
 policy_arn = aws_iam_policy.eks.arn
 roles = [aws_iam_role.eks.name]
}
6. Create a Launch Configuration for the worker nodes using the following code:
resource "aws_launch_configuration" "worker" {
 name_prefix = "worker-config-"
 image_id = data.aws_ami.eks.id
 instance_type = "t3.micro"
 iam_instance_profile = aws_iam_instance_profile.worker.name
 security_groups = [aws_security_group.worker.id]
 user_data = <<-EOF
             #!/bin/bash
             echo 'export KUBECONFIG=/etc/kubernetes/kubeconfig.yaml' >> /etc/profile.d/kubeconfig.sh
             curl -o /etc/kubernetes/kubeconfig.yaml ${aws_eks_cluster.eks.endpoint}/kubeconfig
             EOF
 lifecycle {
   create_before_destroy = true
 }
}
7. Create an IAM instance profile for the worker nodes using the following code:
resource "aws_iam_role" "worker" {
 name = "worker-role"
 assume_role_policy = jsonencode({
   Version = "2012-10-17"
   Statement = [
     {
       Effect = "Allow"
       Principal = {
         Service = "ec2.amazonaws.com"
       }
       Action = "sts:AssumeRole"
     }
   ]
 })
}
resource "aws_iam_instance_profile" "worker" {
 name = "worker-profile"
 role = aws_iam_role.worker.name
}
8. Create a security group for the worker nodes using the following code:
resource "aws_security_group" "worker" {
 name_prefix = "worker-sg-"
 ingress {
   from_port  = 0
   to_port    = 65535
   protocol   = "tcp"
   cidr_blocks = [aws_vpc.default.cidr_block]
 }
 egress {
   from_port  = 0
   to_port    = 0
   protocol   = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
}
9. Create a data source to retrieve the latest EKS worker node AMI using the following code:
data "aws_ami" "eks" {
 filter {
   name  = "name"
   values = ["amazon-eks-node-*-latest-*"]
 }
 most_recent = true
 owners = ["602401143452"]
}
10. Create a Kubernetes provider to connect to the EKS cluster using the following code:
provider "kubernetes" {
 host                  = aws_eks_cluster.eks.endpoint
 cluster_ca_certificate = base64decode(aws_eks_cluster.eks.certificate_authority.0.data)
 token                 = data.aws_eks_cluster_auth.eks.token
}
11 Create a Kubernetes configuration to connect to the EKS cluster using the following code:
data "aws_eks_cluster_auth" "eks" {
 name = aws_eks_cluster.eks.name
}
resource "kubernetes_config_map" "config_map_aws_auth" {
 metadata {
   name = "aws-auth"
 }
 data = {
   mapRoles = <<-YAML
     - rolearn: ${aws_iam_role.worker.arn}
       username: system:node:{{EC2PrivateDNSName}}
       groups:
         - system:bootstrappers
         - system:nodes
   YAML
 }
}
12. Create a Kubernetes deployment for the sample microservices application using the following code:
resource "kubernetes_deployment" "example" {
 metadata {
   name = "example"
 }
 spec {
   replicas = 3
   selector {
     match_labels = {
       app = "example"
     }
   }
   template {
     metadata {
       labels = {
         app = "example"
       }
     }
     spec {
       container {
         name = "example"
         image = "nginx:latest"
         port {
           container_port = 80
         }
       }
     }
   }
 }
}
