variable "old_instance_id" {
  description = "ID of the old instance to copy details from and detach resources"
  type        = string
}

# Fetch details of the old EC2 instance
data "aws_instance" "old_instance" {
  instance_id = var.old_instance_id
}

# Fetch the Elastic IP associated with the old instance
data "aws_eip" "old_eip" {
  instance = var.old_instance_id
}

# Create a new EC2 instance with the same network configuration as the old instance
resource "aws_instance" "new_instance" {
  ami                         = data.aws_instance.old_instance.ami
  instance_type               = data.aws_instance.old_instance.instance_type
  subnet_id                   = data.aws_instance.old_instance.subnet_id
  vpc_security_group_ids      = data.aws_instance.old_instance.vpc_security_group_ids
  associate_public_ip_address = data.aws_instance.old_instance.associate_public_ip_address

  tags = {
    Name = "NewInstance"
  }
}



# Detach each EBS volume from the old instance
resource "aws_volume_attachment" "detach_ebs_volumes" {
  for_each    = { for vol in data.aws_instance.old_instance.ebs_block_device : vol.volume_id => vol }
  device_name = each.value.device_name
  volume_id   = each.value.volume_id
  instance_id = var.old_instance_id
  force_detach = true
}

# Detach the Elastic IP from the old instance
resource "aws_eip_association" "detach_eip" {
  instance_id   = var.old_instance_id
  allocation_id = data.aws_eip.old_eip.id

  lifecycle {
    prevent_destroy = false
  }

}

# Attach each detached EBS volume to the new instance
resource "aws_volume_attachment" "attach_ebs_volumes" {
  for_each    = { for vol in data.aws_instance.old_instance.ebs_block_device : vol.volume_id => vol }
  device_name = each.value.device_name
  volume_id   = each.value.volume_id
  instance_id = aws_instance.new_instance.id
  depends_on = [aws_volume_attachment.detach_ebs_volumes]
}

# Attach the Elastic IP to the new instance
resource "aws_eip_association" "attach_eip" {
  instance_id   = aws_instance.new_instance.id
  allocation_id = data.aws_eip.old_eip.id
  depends_on    = [aws_eip_association.detach_eip]
}
