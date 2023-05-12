
# AWS 프로바이더 설정
provider "aws" {
  region = "ap-northeast-2"
}

# VPC 생성
resource "aws_vpc" "Eli-test-kubernetes_vpc" {
  cidr_block = "172.30.0.0/16"
  tags = {
    Name = "eks-vpc"
  }
}

# 서브넷 생성
resource "aws_subnet" "kubernetes_subnet_a_pb" {
  vpc_id = aws_vpc.Eli-test-kubernetes_vpc.id
  cidr_block = "172.30.1.0/24"
  availability_zone = "ap-northeast-2a"
  
  tags = {
    Name = "EKS-vpc-A_PB"
  }
}

resource "aws_subnet" "kubernetes_subnet_b_pb" {
  vpc_id = aws_vpc.Eli-test-kubernetes_vpc.id
  cidr_block = "172.30.2.0/24"
  availability_zone = "ap-northeast-2b"
 
  tags = {
    Name = "EKS-vpc-B_PB"
  }
}

resource "aws_subnet" "kubernetes_subnet_c_pb" {
  vpc_id = aws_vpc.Eli-test-kubernetes_vpc.id
  cidr_block = "172.30.3.0/24"
  availability_zone = "ap-northeast-2c"
  
  tags = {
    Name = "EKS-vpc-C_PB"
  }
}

resource "aws_subnet" "kubernetes_subnet_a_pv" {
  vpc_id = aws_vpc.Eli-test-kubernetes_vpc.id
  cidr_block = "172.30.4.0/24"
  availability_zone = "ap-northeast-2a"
  tags = {
  "kubernetes.io/cluster/terraform-eks-cluster" = "shared"
  Name = "EKS-VPC-A_PB"
  }
}

resource "aws_subnet" "kubernetes_subnet_b_pv" {
  vpc_id = aws_vpc.Eli-test-kubernetes_vpc.id
  cidr_block = "172.30.5.0/24"
  availability_zone = "ap-northeast-2b"
  tags = {
  "kubernetes.io/cluster/terraform-eks-cluster" = "shared"
  Name = "EKS-VPC-B_PB"
  }
}

resource "aws_subnet" "kubernetes_subnet_c_pv" {
  vpc_id = aws_vpc.Eli-test-kubernetes_vpc.id
  cidr_block = "172.30.6.0/24"
  availability_zone = "ap-northeast-2c"
  tags = {
  "kubernetes.io/cluster/terraform-eks-cluster" = "shared"
  Name = "EKS-VPC-C_PB"
  }
}


# 인터넷 게이트웨이 생성
resource "aws_internet_gateway" "kubernetes_igw" {
  vpc_id = aws_vpc.Eli-test-kubernetes_vpc.id  
}

# NATgw 생성
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_gw_eip.id
  subnet_id = aws_subnet.kubernetes_subnet_a_pb.id
}

resource "aws_eip" "nat_gw_eip" {
  vpc = true
}

# 라우팅 테이블 생성
resource "aws_route_table" "kubernetes_route_table" {
  vpc_id = aws_vpc.Eli-test-kubernetes_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kubernetes_igw.id
  }
}

# 프라이빗 서브넷에 대한 라우팅 테이블 생성
resource "aws_route_table" "private_subnet_route_table" {
  vpc_id = aws_vpc.Eli-test-kubernetes_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
}

# 프라이빗 서브넷에 NAT Gateway 연결
resource "aws_route_table_association" "private_subnet_nat_association_a" {
  subnet_id      = aws_subnet.kubernetes_subnet_a_pv.id
  route_table_id = aws_route_table.private_subnet_route_table.id
}

resource "aws_route_table_association" "private_subnet_nat_association_b" {
  subnet_id      = aws_subnet.kubernetes_subnet_b_pv.id
  route_table_id = aws_route_table.private_subnet_route_table.id
}

resource "aws_route_table_association" "private_subnet_nat_association_c" {
  subnet_id      = aws_subnet.kubernetes_subnet_c_pv.id
  route_table_id = aws_route_table.private_subnet_route_table.id
}
# 서브넷 연결
resource "aws_route_table_association" "kubernetes_route_table_association_a" {
  subnet_id = aws_subnet.kubernetes_subnet_a_pb.id
  route_table_id = aws_route_table.kubernetes_route_table.id
}

resource "aws_route_table_association" "kubernetes_route_table_association_b" {
  subnet_id = aws_subnet.kubernetes_subnet_b_pb.id
  route_table_id = aws_route_table.kubernetes_route_table.id
}

resource "aws_route_table_association" "kubernetes_route_table_association_c" {
  subnet_id = aws_subnet.kubernetes_subnet_c_pb.id
  route_table_id = aws_route_table.kubernetes_route_table.id
}

# 보안 그룹 생성
resource "aws_security_group" "kubernetes_security_group" {
  name = "kubernetes_security_group"
  vpc_id = aws_vpc.Eli-test-kubernetes_vpc.id
  description = "Security group for Kubernetes cluster"

  ingress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["172.30.0.0/16"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "kubernetes_security_group_bastion" {
  name = "kubernetes_security_group_bastion"
  vpc_id = aws_vpc.Eli-test-kubernetes_vpc.id
  description = "Security group for Kubernetes cluster Bastion"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 키페어 설정
resource "aws_key_pair" "eli_key_pair" {
  key_name   = "eli_k8s"
  public_key = file("/Users/mzc01-kimih/hello-cdk/workspace/terraform/team-aws-account/eli_k8s.pub")
}

# 쉘 스크립트 넣어주기
data "template_file" "user_data" {
  template = file("/Users/mzc01-kimih/devops/script/bastion.sh")
}

# EC2 인스턴스 생성
resource "aws_instance" "kubernetes_Bastion" {
ami = "ami-04cebc8d6c4f297a3"
instance_type = "t3.large"
subnet_id = aws_subnet.kubernetes_subnet_a_pb.id
associate_public_ip_address = true
vpc_security_group_ids = [aws_security_group.kubernetes_security_group_bastion.id]
key_name = aws_key_pair.eli_key_pair.key_name
user_data = data.template_file.user_data.rendered
tags = {
Name = "kubernetes-bastion"
}
}

# IAM Role을 생성하고
resource "aws_iam_role" "terraform-eks-cluster" {
  name = "terraform-eks-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# 위에서 생성한 IAM Role에 policy를 추가한다.
resource "aws_iam_role_policy_attachment" "terraform-eks-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.terraform-eks-cluster.name
}

# 위에서 생성한 IAM Role에 policy를 추가한다.
resource "aws_iam_role_policy_attachment" "terraform-eks-cluster-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.terraform-eks-cluster.name
}

# security group을 생성하고
resource "aws_security_group" "terraform-eks-cluster" {
  name        = "terraform-eks-cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.Eli-test-kubernetes_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-eks-cluster"
  }
}

# security group의 ingress 룰을 추가한다.
resource "aws_security_group_rule" "terraform-eks-cluster-ingress-workstation-https" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.terraform-eks-cluster.id
  to_port           = 443
  type              = "ingress"
}

# 마지막으로 cluster를 생성
resource "aws_eks_cluster" "terraform-eks-cluster" {
  name     = "terraform-eks-cluster"
  role_arn = aws_iam_role.terraform-eks-cluster.arn
  version = "1.26"

  enabled_cluster_log_types = ["api"]

  vpc_config {
    security_group_ids = [aws_security_group.terraform-eks-cluster.id]
    subnet_ids         = [aws_subnet.kubernetes_subnet_a_pv.id, aws_subnet.kubernetes_subnet_b_pv.id, aws_subnet.kubernetes_subnet_c_pv.id]
    endpoint_private_access = true
    endpoint_public_access = false
  }

  depends_on = [
    aws_iam_role_policy_attachment.terraform-eks-cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.terraform-eks-cluster-AmazonEKSVPCResourceController,
  ]
}

# 여기서는 EC2관련 IAM Role을 생성해주고
resource "aws_iam_role" "terraform-eks-node" {
  name = "terraform-eks-node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# 위에서 생성한 IAM Role에 Policy를 추가한다
resource "aws_iam_role_policy_attachment" "terraform-eks-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.terraform-eks-node.name
}

# 위에서 생성한 IAM Role에 Policy를 추가한다
resource "aws_iam_role_policy_attachment" "terraform-eks-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.terraform-eks-node.name
}

# 위에서 생성한 IAM Role에 Policy를 추가한다
resource "aws_iam_role_policy_attachment" "terraform-eks-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.terraform-eks-node.name
}

# 마지막으로 Node Group을 생성한다.
resource "aws_eks_node_group" "terraform-eks-c5-large" {
  cluster_name    = aws_eks_cluster.terraform-eks-cluster.name
  node_group_name = "terraform-eks-c5-large"
  node_role_arn   = aws_iam_role.terraform-eks-node.arn
  subnet_ids      = [aws_subnet.kubernetes_subnet_a_pv.id, aws_subnet.kubernetes_subnet_b_pv.id, aws_subnet.kubernetes_subnet_c_pv.id]
  disk_size = 20

  labels = {
    "role" = "terraform-eks-c5-large"
  }

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 4
  }
  instance_types = ["c5.large"]
  
  depends_on = [
    aws_iam_role_policy_attachment.terraform-eks-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.terraform-eks-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.terraform-eks-node-AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = {
    "Name" = "${aws_eks_cluster.terraform-eks-cluster.name}-terraform-eks-c5-large-Node"
  }
}

# 출력
output "kubernetes_Bastion_ips" {
value = [
aws_instance.kubernetes_Bastion.public_ip,
]
}


