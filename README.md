# AWS Cloud WAN Multi-Region Terraform Example

## What is Cloud WAN? 

AWS Cloud WAN is a service that let's you bridge your on premises networks
to AWS VPCs, and provides network policy management capabilities. You use Cloud WAN 
to create a core network, and then network edges that are connected to your global network, 
such as VPNs and VPCs. You can configure different segments, for production networks and
development networks for example, or to serve different sets of users.

## How it works?

- The main.tf file contains a simple configuration for us-east-1 and us-west-2
- The global network acts as a container for the network objects Terraform provisions
- The VPC and Transit Gateway are provisioned and VPC attachment is created
- The VPC, Transit Gateway, Global Network, Core Network, Policy Document, and Edges are
provisioned and peered via Network Manager

## Things to consider 

- Scale out to additional VPCs, Transit Gateway attachments, and register the Transit
Gateways, then peer them with Network Manager to the core network in the same region that
the Transit Gateway is deployed
- Configure IAM roles for deployment
- Configure VPC route tables, NACLs, and Transit Gateway policy

