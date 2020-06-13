
provider "aws" {
	profile = "terraform_1"
	region = "us-east-1"
}

// launch key-pair

resource "tls_private_key" "key-pair" {
	algorithm = "RSA"
	rsa_bits = 4096
}


resource "local_file" "private-key" {
    content = tls_private_key.key-pair.private_key_pem
    filename = 	"lwtask1.pem"
    file_permission = "0400"
}

resource "aws_key_pair" "deployer" {
  key_name   = "lwtask1"
  public_key = tls_private_key.key-pair.public_key_openssh

}

//
// resource "aws_key_pair" "deployer" {
// key_name   = "terra-lab-1"
//  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD3F6tyPEFEzV0LX3X8BsXdMsQz1x2cEikKDEY0aIj41qgxMCP/iteneqXSIFZBp5vizPvaoIR3Um9xK7PGoW8giupGn+EPuxIA4cDM4vzOqOkiMPhz5XK0whEjkVzTo4+S0puvDZuwIsdiW9mxhJc7tgBNL0cYlWSYVkz4G/fslNfRPW5mYAM49f4fhtxPb5ok4Q2Lg9dPKVHO/Bgeu5woMc7RY0p1ej6D4CKFE6lymSDJpW0YHX/wqE9+cfEauh7xZcG0q9t2ta6F6fmX0agvpFyZo8aFbXeUBr7osSCJNgvavWbM/06niWrOvYX2xwWdhXmXSrbX8ZbabVohBK41"
// }

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
key_name = "lwtask1"
security_groups = ["${aws_security_group.mysg-tf1.name }"] 
user_data = "${file("web.sh")}"
tags = {
  Name = "Terraform RHEL Instance"
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


resource "null_resource" "part_mount"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    host     = aws_instance.my_instance.public_ip
   private_key = file("lwtask1.pem")
  }
provisioner "remote-exec" {
    inline = [
"sudo mkfs.ext4 /dev/xvdh",
"sudo mount /dev/xvdfh /var/www/html", 
"sudo rm -f /var/www/html",
"sudo git clone https://github.com/arvindr73/multicld.git /var/www/html/"
  ]
  }
}



// create S3 bucket in same region

resource "aws_s3_bucket" "my_first_t_bucket" {
  bucket = "arvind-test-bucket"
  acl    = "public-read"
  region = "us-east-1"

	
  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}


resource "aws_s3_bucket_object" "bucket-obj" {
  
  key = "image.jpg"
  bucket = aws_s3_bucket.my_first_t_bucket.bucket
  acl    = "public-read"
  
  source = "DSC06828.jpg"
}

locals {
	s3_origin_id = "S3-${aws_s3_bucket.my_first_t_bucket.bucket}"
}

// capture public I.P. of EC2 instance

resource "null_resource" "pubid"  {

depends_on = [
    null_resource.part_mount,
  ]

	provisioner "local-exec" {
	    command = "echo  ${aws_instance.my_instance.public_ip} > publicipa.txt"
  	}
}

// cloudfront distribution

resource "aws_cloudfront_distribution" "cloudfront" {

	enabled = true
	is_ipv6_enabled = true
	
	origin {
		domain_name = aws_s3_bucket.my_first_t_bucket.bucket_domain_name
		origin_id = local.s3_origin_id
	}
	
	default_cache_behavior {
    		allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    		cached_methods   = ["GET", "HEAD"]
    		target_origin_id = local.s3_origin_id

    		forwarded_values {
      			query_string = false

      			cookies {
        			forward = "none"
      			}
    		}
    		
    		viewer_protocol_policy = "allow-all"
    	}
    	
    	restrictions {
    		geo_restriction {
    			restriction_type = "none"
    		}
    	}
    	
    	viewer_certificate {
    
    		cloudfront_default_certificate = true
  	}

	connection {
    		type     = "ssh"
    		user     = "ec2-user"
    		private_key = file("lwtask1.pem")
    		host = aws_instance.my_instance.public_ip
          }
	
   	provisioner "remote-exec" {
  		
  		inline = [
  			
  			"sudo su << EOF",
            		"echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.bucket-obj.key}' width='300' height='380'>\" >> /var/www/html/index.php",
            		"EOF",	
  		]
  	}
}

// launch website

// resource "null_resource" "launch"  {
// depends_on = [
   // aws_cloudfront_distribution.cloudfront,
 // ]
   //   provisioner "local-exec" {      
//	    command = "iexplore  ${aws_instance.my_instance.public_ip}"
//  	}
// }



