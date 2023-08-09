# --- GENERAL --- #
location            = "UK South"
resource_group_name = "tl-transit-vnet-dedicated"
name_prefix         = ""
tags = {
  "CreatedBy"   = "Palo Alto Networks"
  "CreatedWith" = "Terraform"
  "StoreStatus" = "DND"
}



# --- VNET PART --- #
vnets = {
  "transit" = {
    name          = "tl-transit"
    address_space = ["10.0.0.0/25"]
    network_security_groups = {
      "management" = {
        name = "tl-mgmt-nsg"
        rules = {
          vmseries_mgmt_allow_inbound = {
            priority                   = 100
            direction                  = "Inbound"
            access                     = "Allow"
            protocol                   = "Tcp"
            source_address_prefixes    = ["137.83.233.0/24"] # TODO: whitelist public IP addresses that will be used to manage the appliances
            source_port_range          = "*"
            destination_address_prefix = "10.0.0.0/28"
            destination_port_ranges    = ["22", "443"]
          }
        }
      }
      "public" = {
        name = "tl-public-nsg"
      }
      "private" = {
        name = "tl-private-nsg"
        rules = {
          allow_all_into_vmseries = {
            priority		       = 100
            direction 		       = "Inbound"
            access		       = "Allow"
            protocol                   = "*"
            source_address_prefix      = "*"
            source_port_range          = "*"
            destination_address_prefix = "*"
            destination_port_range     = "*"
          }
        }
      } 
    }
    route_tables = {
      "management" = {
        name = "tl-mgmt-rt"
        routes = {
          "private_blackhole" = {
            address_prefix = "10.0.0.16/28"
            next_hop_type  = "None"
          }
          "public_blackhole" = {
            address_prefix = "10.0.0.32/28"
            next_hop_type  = "None"
          }
        }
      }
      "private" = {
        name = "tl-private-rt"
        routes = {
          "default" = {
            address_prefix         = "0.0.0.0/0"
            next_hop_type          = "VirtualAppliance"
            next_hop_in_ip_address = "10.0.0.30"
          }
          "mgmt_blackhole" = {
            address_prefix = "10.0.0.0/28"
            next_hop_type  = "None"
          }
          "public_blackhole" = {
            address_prefix = "10.0.0.32/28"
            next_hop_type  = "None"
          }
        }
      }
      "public" = {
        name = "tl-public-rt"
        routes = {
          "mgmt_blackhole" = {
            address_prefix = "10.0.0.0/28"
            next_hop_type  = "None"
          }
          "private_blackhole" = {
            address_prefix = "10.0.0.16/28"
            next_hop_type  = "None"
          }
        }
      }
      "gateway" = {
        name = "tl-gateway-rt"
        routes = {
          "spoke1" = {
            address_prefix = "10.0.0.0/24"
            next_hop_type = "VirtualAppliance"
            next_hop_in_ip_address = "10.0.0.30"
          }
        }
      }
    }
    subnets = {
      "management" = {
        name                            = "tl-mgmt-snet"
        address_prefixes                = ["10.0.0.0/28"]
        network_security_group          = "management"
        route_table                     = "management"
        enable_storage_service_endpoint = true
      }
      "private" = {
        name                   = "tl-private-snet"
        address_prefixes       = ["10.0.0.16/28"]
        network_security_group = "private"
        route_table            = "private"
      }
      "public" = {
        name                   = "tl-public-snet"
        address_prefixes       = ["10.0.0.32/28"]
        network_security_group = "public"
        route_table            = "public"
      }
    }
  }
}
#spoke1_vnet = "spoke1"


# --- LOAD BALANCING PART --- #
load_balancers = {
  "public" = {
    name                              = "tl-public-lb"
    network_security_group_name       = "tl-public-nsg"
    network_security_allow_source_ips = ["137.83.233.0/24"] # Put your own public IP address here  <-- TODO to be adjusted by the customer
    avzones                           = ["1", "2", "3"]
    frontend_ips = {
      "palo-lb-app1-pip" = {
        create_public_ip = true
        in_rules = {
          "balanceHttp" = {
            protocol = "Tcp"
            port     = 80
          }
        }
      }
    }
  }
  "private" = {
    name    = "tl-private-lb"
    avzones = ["1", "2", "3"]
    frontend_ips = {
      "ha-ports" = {
        vnet_key           = "transit"
        subnet_key         = "private"
        private_ip_address = "10.0.0.30"
        in_rules = {
          HA_PORTS = {
            port     = 0
            protocol = "All"
          }
        }
      }
    }
  }
}



# --- VMSERIES PART --- #

vmseries_version = "10.2.3"
vmseries_vm_size = "Standard_DS3_v2"

vmseries = {
  "fw-in-1" = {
    name                 = "tl-inbound-firewall-01"
    add_to_appgw_backend = true
    vnet_key = "transit"
    avzone   = 1
    interfaces = [
      {
        name       = "mgmt"
        subnet_key = "management"
        create_pip = true
      },
      {
        name       = "private"
        subnet_key = "private"
      },
      {
        name              = "public"
        subnet_key        = "public"
        load_balancer_key = "public"
        create_pip        = true
      }
    ]
  }
  "fw-in-2" = {
    name                 = "tl-inbound-firewall-02"
    add_to_appgw_backend = true
    vnet_key = "transit"
    avzone   = 2
    interfaces = [
      {
        name       = "mgmt"
        subnet_key = "management"
        create_pip = true
      },
      {
        name       = "private"
        subnet_key = "private"
      },
      {
        name              = "public"
        subnet_key        = "public"
        load_balancer_key = "public"
        create_pip        = true
      }
    ]
  }
  "fw-obew-1" = {
    name = "tl-obew-firewall-01"
    vnet_key = "transit"
    avzone   = 1
    interfaces = [
      {
        name       = "mgmt"
        subnet_key = "management"
        create_pip = true
      },
      {
        name              = "private"
        subnet_key        = "private"
        load_balancer_key = "private"
      },
      {
        name       = "public"
        subnet_key = "public"
        create_pip = true
      }
    ]
  }
  "fw-obew-2" = {
    name = "tl-obew-firewall-02"
    vnet_key = "transit"
    avzone   = 2
    interfaces = [
      {
        name       = "mgmt"
        subnet_key = "management"
        create_pip = true
      },
      {
        name              = "private"
        subnet_key        = "private"
        load_balancer_key = "private"
      },
      {
        name       = "public"
        subnet_key = "public"
        create_pip = true
      }
    ]
  }
}

