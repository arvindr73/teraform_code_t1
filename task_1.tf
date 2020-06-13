
provider "aws" {
	profile = "terraform_1"
	region = "us-east-1"
}

// launch key-pair

resource "aws_key_pair" "deployer" {
  key_name   = "my-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD3F6tyPEFEzV0LX3X8BsXdMsQz1x2cEikKDEY0aIj41qgxMCP/iteneqXSIFZBp5vizPvaoIR3Um9xK7PGoW8giupGn+EPuxIA4cDM4vzOqOkiMPhz5XK0whEjkVzTo4+S0puvDZuwIsdiW9mxhJc7tgBNL0cYlWSYVkz4G/fslNfRPW5mYAM49f4fhtxPb5ok4Q2Lg9dPKVHO/Bgeu5woMc7RY0p1ej6D4CKFE6lymSDJpW0YHX/wqE9+cfEauh7xZcG0q9t2ta6F6fmX0agvpFyZo8aFbXeUBr7osSCJNgvavWbM/06niWrOvYX2xwWdhXmXSrbX8ZbabVohBK41"
}


// create security group

resource "aws_security_group" "mysg-tf1" { 

  name        = "mysg-tf1" 
  description = "Allow traffic from port 80 & 22" 
  vpc_id      = "vpc-9a8e92e0" 
 
  ingress { 
    description = "HTTP" 
    from_port   = 80 
    to_port     = 80 
    protocol    = "tcp" 
    cidr_blocks = ["0.0.0.0/0"] 
  } 
  
 ingress { 
    description = "SSH" 
    from_port   = 22 
    to_port     = 22 
    protocol    = "tcp" 
    cidr_blocks = ["0.0.0.0/0"] 
  } 
 
  egress { 
    from_port   = 0 
    to_port     = 0 
    protocol    = "-1" 
    cidr_blocks = ["0.0.0.0/0"] 
}

 tags = { 
    Name = "mysecgrp-sg" 
  } 
} 
 
// launch EC2 instance with the ket-pair & security group created above
// web.sh contains all the yum commands for httpd & php downloads as well as service start.

resource "aws_instance" "my_instance" {
ami = "ami-09d95fab7fff3776c"
instance_type = "t2.micro"
key_name = "my-key"
security_groups = ["${aws_security_group.mysg-tf1.name }"] 
user_data = "${file("web.sh")}"
tags = {
  Name = "Terraform"
  } 
}



// launch EBS volume of 1 GB

resource "aws_ebs_volume" "ebs_volume" {
     size = "1"
    availability_zone = aws_instance.my_instance.availability_zone
  }


// attach EBS volume to above EC2 instance

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.ebs_volume.id}"
  instance_id = "${aws_instance.my_instance.id}"
  force_detach = true
}


// create S3 bucket in same region

resource "aws_s3_bucket" "my_first_t_bucket" {
  bucket = "arvind-test-bucket"
  acl    = "private"
  region = "us-east-1"
 
  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}


// capture public I.P. of EC2 instance

resource "null_resource" "pubid"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.my_instance.public_ip} > publicipa.txt"
  	}
}


// launch website

resource "null_resource" "launch"  {
depends_on = [
    aws_volume_attachment.ebs_att,
  ]
      provisioner "local-exec" {      
	    command = "iexplore  ${aws_instance.my_instance.public_ip}"
  	}
}



