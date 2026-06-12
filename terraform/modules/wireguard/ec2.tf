# WireGuard Server — EC2 Instance
#
# Single EC2 instance running the WireGuard VPN server, on an ARM64
# (Graviton) Amazon Linux 2023 AMI. source_dest_check is disabled since this
# instance routes traffic on behalf of other hosts (VPN clients ↔ TGW). EBS
# root volume is encrypted with the default AWS-managed EBS key. 
# The server is configured via Ansible over AWS SSM (see ssm access file for ssm access entry config).


# Latest Amazon Linux 2023 ARM64 AMI
data "aws_ssm_parameter" "al2023_arm" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_instance" "wireguard_server" {
  ami = data.aws_ssm_parameter.al2023_arm.value
  instance_type = "t4g.micro"
  subnet_id = var.public_subnet_id
  vpc_security_group_ids  = [aws_security_group.wireguard_server.id]
  iam_instance_profile = aws_iam_instance_profile.wireguard_server_profile.name 
  # Required for this instance to forward/route traffic between the WireGuard
  # client subnet and the rest of the network — disables the default
  # "traffic must be to/from this ENI" check
  source_dest_check = false

  # Enforces IMDSv2 (token required) to mitigate SSRF-based credential theft
  metadata_options {
    http_tokens                 = "required"  
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
  }
  root_block_device {
    encrypted   = true
    kms_key_id  = "alias/aws/ebs"
    volume_size = 10
    volume_type = "gp3"
    delete_on_termination = true
  }

  tags = merge({
    Name = "wireguard-server"
  }, var.extended_tags)

  lifecycle {
    # prevent_destroy = true
  }
}