terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

# Create transit gateway

module "tgw" {
  source  = "terraform-aws-modules/transit-gateway/aws"

  name        = "test-tgw"
  description = "Test transit gateway"

  enable_auto_accept_shared_attachments = false

  vpc_attachments = {
    vpc = {
      vpc_id       = module.vpc.vpc_id
      subnet_ids   = module.vpc.private_subnets
      dns_support  = true
      ipv6_support = true

      tgw_routes = [
        {
          destination_cidr_block = "10.0.0.0/16"
        },
        {
          blackhole = true
          destination_cidr_block = "40.0.0.0/20"
        }
      ]
    }
  }
  tags = {
    Purpose = "test-tgw"
  }
}

# Create VPC

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"

  name = "test-vpc"

  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]

  enable_ipv6                                    = true
  private_subnet_assign_ipv6_address_on_creation = true
  private_subnet_ipv6_prefixes                   = [0, 1, 2]
}

# Network manager resources

resource "aws_networkmanager_global_network" "test-globalnet" {
  description = "test-global-network"
}

resource "aws_networkmanager_core_network" "test-corenet" {
  global_network_id = aws_networkmanager_global_network.test-globalnet.id
  policy_document   = data.aws_networkmanager_core_network_policy_document.test-core-policy.json
  description       = "test-core-network"
}

resource "aws_networkmanager_transit_gateway_registration" "test-tgw" {
  global_network_id   = aws_networkmanager_global_network.test-globalnet.id
  transit_gateway_arn = module.tgw.ec2_transit_gateway_arn
}

resource "aws_networkmanager_transit_gateway_peering" "test-tgw-peering" {
  core_network_id     = aws_networkmanager_core_network.test-corenet.id
  transit_gateway_arn = module.tgw.ec2_transit_gateway_arn
  tags = {
    Name = "test-core-network-peering-attachment"
  }
}

# Transit gateway policy table

resource "aws_ec2_transit_gateway_policy_table" "test-tgw-policy" {
  transit_gateway_id = module.tgw.ec2_transit_gateway_id

  tags = {
    segment = "prod"
  }
}

# Associate policy table with network manager peering connection
# Use the peering attachment id

resource "aws_ec2_transit_gateway_policy_table_association" "test-core-policy" {
  transit_gateway_attachment_id   = aws_networkmanager_transit_gateway_peering.test-tgw-peering.transit_gateway_peering_attachment_id
  transit_gateway_policy_table_id = aws_ec2_transit_gateway_policy_table.test-tgw-policy.id
}

# Core network policy doc

data "aws_networkmanager_core_network_policy_document" "test-core-policy" {
  core_network_configuration {
    vpn_ecmp_support = false
    asn_ranges       = ["64512-64555"]
    edge_locations {
      location = "us-east-1"
      asn      = 64512
    }
    edge_locations {
      location = "us-west-2"
      asn      = 64513
    }
  }

  segments {
    name                          = "shared"
    description                   = "Segment for shared services"
    require_attachment_acceptance = false
  }
  segments {
    name                          = "prod"
    description                   = "Segment for prod services"
    require_attachment_acceptance = false
  }

  segment_actions {
    action     = "share"
    mode       = "attachment-route"
    segment    = "shared"
    share_with = ["*"]
  }

  attachment_policies {
    rule_number     = 100
    condition_logic = "or"

    conditions {
      type     = "tag-value"
      operator = "equals"
      key      = "segment"
      value    = "shared"
    }
    action {
      association_method = "constant"
      segment            = "shared"
    }
  }
  attachment_policies {
    rule_number     = 200
    condition_logic = "or"

    conditions {
      type     = "tag-value"
      operator = "equals"
      key      = "segment"
      value    = "prod"
    }
    action {
      association_method = "constant"
      segment            = "prod"
    }
  }
}
