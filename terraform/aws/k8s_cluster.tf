
# AWS 프로바이더 설정
provider "aws" {
  region = "ap-northeast-2"
}

# VPC 생성
resource "aws_vpc" "Eli-test-kubernetes_vpc" {
  cidr_block = "172.30.0.0/16"
}

# 서브넷 생성
resource "aws_subnet" "kubernetes_subnet_a_pb" {
  vpc_id = aws_vpc.Eli-test-kubernetes_vpc.id
  cidr_block = "172.30.1.0/24"
  availability_zone = "ap-northeast-2a"
}

resource "aws_subnet" "kubernetes_subnet_b_pb" {
  vpc_id = aws_vpc.Eli-test-kubernetes_vpc.id
  cidr_block = "172.30.2.0/24"
  availability_zone = "ap-northeast-2b"
}

resource "aws_subnet" "kubernetes_subnet_c_pb" {
  vpc_id = aws_vpc.Eli-test-kubernetes_vpc.id
  cidr_block = "172.30.3.0/24"
  availability_zone = "ap-northeast-2c"
}

resource "aws_subnet" "kubernetes_subnet_a_pv" {
  vpc_id = aws_vpc.Eli-test-kubernetes_vpc.id
  cidr_block = "172.30.4.0/24"
  availability_zone = "ap-northeast-2a"
}

resource "aws_subnet" "kubernetes_subnet_b_pv" {
  vpc_id = aws_vpc.Eli-test-kubernetes_vpc.id
  cidr_block = "172.30.5.0/24"
  availability_zone = "ap-northeast-2b"
}

resource "aws_subnet" "kubernetes_subnet_c_pv" {
  vpc_id = aws_vpc.Eli-test-kubernetes_vpc.id
  cidr_block = "172.30.6.0/24"
  availability_zone = "ap-northeast-2c"
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

resource "aws_instance" "kubernetes_control_plane_1" {
ami = "ami-04cebc8d6c4f297a3"
instance_type = "c5.large"
subnet_id = aws_subnet.kubernetes_subnet_a_pv.id
vpc_security_group_ids = [aws_security_group.kubernetes_security_group.id]
key_name = aws_key_pair.eli_key_pair.key_name
tags = {
Name = "kubernetes-control-plane-1"
}
}

resource "aws_instance" "kubernetes_control_plane_2" {
ami = "ami-04cebc8d6c4f297a3"
instance_type = "c5.large"
subnet_id = aws_subnet.kubernetes_subnet_b_pv.id
vpc_security_group_ids = [aws_security_group.kubernetes_security_group.id]
key_name = aws_key_pair.eli_key_pair.key_name
tags = {
Name = "kubernetes-control-plane-2"
}
}

resource "aws_instance" "kubernetes_control_plane_3" {
ami = "ami-04cebc8d6c4f297a3"
instance_type = "c5.large"
subnet_id = aws_subnet.kubernetes_subnet_c_pv.id
vpc_security_group_ids = [aws_security_group.kubernetes_security_group.id]
key_name = aws_key_pair.eli_key_pair.key_name
tags = {
Name = "kubernetes-control-plane-3"
}
}

resource "aws_instance" "kubernetes_worker_1" {
ami = "ami-04cebc8d6c4f297a3"
instance_type = "c5.large"
subnet_id = aws_subnet.kubernetes_subnet_a_pv.id
vpc_security_group_ids = [aws_security_group.kubernetes_security_group.id]
key_name = aws_key_pair.eli_key_pair.key_name
tags = {
Name = "kubernetes-worker-1"
}
}

resource "aws_instance" "kubernetes_worker_2" {
ami = "ami-04cebc8d6c4f297a3"
instance_type = "c5.large"
subnet_id = aws_subnet.kubernetes_subnet_b_pv.id
vpc_security_group_ids = [aws_security_group.kubernetes_security_group.id]
key_name = aws_key_pair.eli_key_pair.key_name
tags = {
Name = "kubernetes-worker-2"
}
}

resource "aws_instance" "kubernetes_worker_3" {
ami = "ami-04cebc8d6c4f297a3"
instance_type = "c5.large"
subnet_id = aws_subnet.kubernetes_subnet_c_pv.id
vpc_security_group_ids = [aws_security_group.kubernetes_security_group.id]
key_name = aws_key_pair.eli_key_pair.key_name
tags = {
Name = "kubernetes-worker-3"
}
}

# 로드밸런서 생성

resource "aws_elb" "kubernetes_elb" {
name = "kubernetes-elb"
subnets = [
aws_subnet.kubernetes_subnet_a_pb.id,
aws_subnet.kubernetes_subnet_b_pb.id,
aws_subnet.kubernetes_subnet_c_pb.id
]
listener {
instance_port = 6443
instance_protocol = "TCP"
lb_port = 6443
lb_protocol = "TCP"
}
}

# 출력
output "kubernetes_Bastion_ips" {
value = [
aws_instance.kubernetes_Bastion.public_ip,
]
}


