
#Deployment configuration
variable "project_id" {
  type        = string
  description = "Project ID."
}

variable "deployment_prefix" {
  description = <<EOT
  The name of the deployment and VM instance.
  A string that will be used to create deployment ID and resource names. It can contain between two and five lowercase alphabet characters and digits.
  It must start with lowercase alphabet character."
  EOT

  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.deployment_prefix)) && length(var.deployment_prefix) <= 5 && length(var.deployment_prefix) >= 2
    error_message = "The deployment_prefix must be between two and five lowercase alphabet characters or digits, starting with lowercase alphabet character."
  }
  type = string
}

variable "mig_instance_type" {
  type        = string
  description = " The machine type to use to create the vSensor. Sizing requirements can be found at https://customerportal.darktrace.com/product-guides/main/vsensor-requirements."
  default     = "e2-standard-2"
}

variable "mig_ssh_user_key" {
  type        = string
  description = <<EOT
  vSensor username and public ssh key for ssh public key authentication in format 'username:ssh_public_key'.
  This will be added to the instance metadata: https://cloud.google.com/compute/docs/connect/add-ssh-keys#add_ssh_keys_to_instance_metadata.
  Example: `mig_ssh_user_key = "test:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILg6UtHDNyMNAh0GjaytsJdrUxjtLy3APXqZfNZhvCeT test"`
  EOT

  default = null

  validation {
    #The regex for the username is based on Ubuntu NAME_REGEX="^[a-z][-a-z0-9_]*\$" in /etc/adduser.conf
    #The variety of ssh key types makes it difficult to regex it without the risk to reject legitimate public key hence this is left open to any character
    condition     = var.mig_ssh_user_key == null || can(regex("^[a-z][-a-z0-9_]*:.+$", var.mig_ssh_user_key))
    error_message = "The mig_ssh_user_key cannot be empty. If you don't want ssh key to be added to the vSensors then do not provide any value for this variable."
  }

}

#Network configuration existing VPC
variable "existing_vpc_name" {
  type        = string
  description = "The existing VPC network name where the vSensors will be deployed. If `new_vpc_enable = true` this will be ignored."
  default     = ""
}

#Network configuration new VPC
variable "new_vpc_enable" {
  type        = bool
  description = "If `true` will create a new VPC network. The name of the new network will be of the form `deployment_prefix-<random-string>-`."
  default     = false
}

variable "ipv6_enable" {
  type        = bool
  description = "Enable Dual-Stack IPv6 support to vSensor for allowing packet mirroring from IPv6 enabled hosts/subnets."
  default     = false
}

variable "lb_global_access_enable" {
  type        = bool
  description = <<EOT
  Enable global access on the vSensor Internal passthrough Network Load Balancer.
  When `false` (default), only osSensors in the **same region** as the deployment can reach the load balancer IP.
  When `true`, osSensors in **any region** can reach the load balancer IP, allowing cross-region (and cross-zone) access.
  Note: enabling cross-region/cross-zone access may incur additional inter-region network egress charges for traffic between the osSensors and the vSensors.
  https://cloud.google.com/load-balancing/docs/internal#global_access
  EOT
  default     = false
}

variable "mig_subnet_cidr" {
  type        = string
  description = "Subnet range that the vSensors will be deployed in (must not overlap with bastion or other subnets in VPC)."

  validation {
    condition     = can(regex("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]).){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(/(1[7-9]|2[0-8]))$", var.mig_subnet_cidr))
    error_message = "The mig_subnet_cidr CIDR blocks must be in the form x.x.x.x/17-28."
  }

}

variable "mig_zone" {
  type        = list(string)
  description = <<EOT
  The distribution policy for the vSensors managed instance group.
  You can specify one or more values, for example ["europe-west1-b", "europe-west1-c"].
  The default (empty) means **all zones** in the region.
  EOT
  default     = []
}

variable "region" {
  type        = string
  description = "The region that the resources will be deployed into."
}

variable "mig_min_size" {
  type        = number
  description = "Minimum number of vSensor instances in the Autoscaling group."
  default     = 2
}

variable "mig_max_size" {
  type        = number
  description = "Maximum number of vSensor instances in the Autoscaling group. It is recommended to be set larger than the `mig_min_size` to allow Autoscaling and instance replacement actions to work correctly."
  default     = 3
}

#vSensor installation and configuration
variable "dt_instance_hostname" {
  type        = string
  description = "Host name of the Darktrace Master instance."
}

variable "dt_instance_port" {
  type        = number
  description = "Connection port between vSensor and the Darktrace Master instance."
  default     = 443
}

variable "sm_update_key" {
  type        = string
  description = "Secret Manager Secret Name of the vSensor update key. If you don't have one, contact your Darktrace representative."

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.sm_update_key)) && length(var.sm_update_key) < 256
    error_message = <<EOT
    Invalid Secret Manager Secret name. A secret name can contain uppercase and lowercase letters, numerals, hyphens, and underscores.
    The maximum allowed length for a name is 255 characters.
    https://cloud.google.com/secret-manager/docs/creating-and-accessing-secrets#create
    EOT
  }
}

variable "sm_push_token" {
  type        = string
  description = "Secret Manager Secret Name of the push token. The push token is used to authenticate the vSensor with the Darktrace Master instance."

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]+$", var.sm_push_token)) && length(var.sm_push_token) < 256
    error_message = <<EOT
    Invalid Secret Manager Secret name.
    A secret name can contain uppercase and lowercase letters, numerals, hyphens, and underscores.
    The maximum allowed length for a name is 255 characters.
    https://cloud.google.com/secret-manager/docs/creating-and-accessing-secrets#create
    EOT
  }
}

variable "sm_ossensor_hmac" {
  type        = string
  description = "(Optional)Secret Manager Secret Name of the hash-based message authentication code (HMAC) token to authenticate osSensors with vSensor."
  default     = ""

  validation {
    condition     = var.sm_ossensor_hmac == "" || can(regex("^[a-zA-Z0-9-_]+$", var.sm_ossensor_hmac)) && length(var.sm_ossensor_hmac) < 256
    error_message = <<EOT
    Invalid Secret Manager Secret name.
    A secret name can contain uppercase and lowercase letters, numerals, hyphens, and underscores.
    The maximum allowed length for a name is 255 characters.
    https://cloud.google.com/secret-manager/docs/creating-and-accessing-secrets#create
    EOT
  }
}

variable "ssh_iap" {
  type        = string
  description = "(Forces re-creating the vSensor) Enable or disable GCP IAP (SSH-in-Browser) ssh access to the vSensors. Accepted values are enable or disable. The default is enable. After the vSensors have been deployed, changing the value will force re-creating the vSensors in the **create before destroy** fashion."
  default     = "enable"

  validation {
    condition     = contains(["enable", "disable"], var.ssh_iap)
    error_message = "The ssh_iap can be enable or disable."
  }
}

#PCAPs storage configuration
#Logs and captured packet retention
variable "retention_time_days" {
  description = "Number of days to retain captured packets in the bucket. Longer retention will increase storage costs. Set to 0 to disable PCAPs and Storage bucket."
  type        = number
  default     = 7

  validation {
    condition     = floor(var.retention_time_days) == var.retention_time_days && var.retention_time_days >= 0
    error_message = "The number of days to retain captured packets in the bucket should be a whole number."
  }
}

#Packet mirroring
variable "mirrored_subnets" {
  type        = list(string)
  description = <<EOT
  (Optional) Names of the subnets to be mirrored. For example ["mirror-subnet-1", "mirror-subnet-2"].
  If left empty, no packet mirroring policy will be created.
  In such cases, packet mirroring policy can be manually created later, or once the module has completed, mirrored_subnets can be added and another `terraform apply` will create the policy.
  EOT
  default     = []
}

variable "mirrored_protocols" {
  type        = list(string)
  description = <<EOT
  (Optional). IP protocols to mirror.
  Possible IP protocols including ah, esp, icmp, ipip, sctp, tcp, udp, or an IP protocol number between 0 and 255.
  Example: ["tcp", "udp"] to mirror only tcp and udp protocols.
  Do not provide any value to mirror all IP protocols.
  The default is to mirror all IP protocols.
  Changing the value will force resource replacement (destroy and then create replacement).
  EOT
  default     = []

  validation {
    condition = alltrue([
      for proto in var.mirrored_protocols :
      var.mirrored_protocols == tolist([]) || can(regex("^[a-zA-Z0-9]+$", proto))
    ])
    error_message = "Error: mirrored_protocols is either empty (no value provided), or a list of alphanumeric string(s)."
  }

}

variable "mirrored_cidr_ranges" {
  type        = list(string)
  description = <<EOT
  IP CIDR ranges that apply as a filter on the source (ingress) or destination (egress) IP in the IP header.
  IPv4 and IPv6 are supported (requires `ipv6-enable`).
  Use 0.0.0.0/0, ::/0 to allow all IPv4 and IPv6 ranges.
  Example: ["10.0.0.0/24", "10.0.1.0/24"].
  The default value is "0.0.0.0/0".
  EOT
  default     = ["0.0.0.0/0"]
}

variable "mirrored_direction" {
  type        = string
  description = <<EOT
  Direction of traffic to mirror.
  Possible values are: INGRESS, EGRESS, BOTH. NOTE: any setting other than BOTH may lead to unidirectional traffic alerts on the Darktrace master instance.
  The default value is BOTH.
  EOT
  default     = "BOTH"
}

#Bastion
variable "bastion_ssh_user_key" {
  type        = string
  description = <<EOT
  (Optional) Bastion username and public ssh key for ssh public key authentication in format 'username:ssh_public_key'.
  This will be added to the instance metadata: https://cloud.google.com/compute/docs/connect/add-ssh-keys#add_ssh_keys_to_instance_metadata.
  Example: `bastion_ssh_user_key = "test:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILg6UtHDNyMNAh0GjaytsJdrUxjtLy3APXqZfNZhvCeT test"`
  EOT

  default = null

  validation {
    #The regex for the username is based on Ubuntu NAME_REGEX="^[a-z][-a-z0-9_]*\$" in /etc/adduser.conf
    #The variety of ssh key types makes it difficult to regex it without the risk to reject legitimate public key hence this is left open to any character
    condition     = var.bastion_ssh_user_key == null || can(regex("^[a-z][-a-z0-9_]*:.+$", var.bastion_ssh_user_key))
    error_message = "The bastion_ssh_user_key cannot be empty. If you don't want ssh key to be added to the Bastion then do not provide any value for this variable."
  }

}

variable "bastion_enable" {
  type        = bool
  description = <<EOT
  (Optional; applicable only if `new_vpc_enable = true`) If true a standalone/single bastion host will be installed to provide ssh remote access to the vSensors.
  A new subnet will be created for the bastion.
  EOT
  default     = false
}

variable "bastion_subnet_cidr" {
  type        = string
  description = "(Optional) Subnet CIDR range that the Bastion will be deployed in (must not overlap with vSensor or other subnets in the VPC). Example: 10.127.2.0/27. Do not provide any value if bastion is not enabled."
  default     = null

  validation {
    condition     = var.bastion_subnet_cidr == null || can(regex("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]).){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(/(1[7-9]|2[0-8]))$", var.bastion_subnet_cidr))
    error_message = "The bastion_subnet_cidr CIDR range must be in the form x.x.x.x/17-28, or no value provided."
  }

}

variable "bastion_ssh_cidr" {
  type        = list(string)
  description = "(Optional) List of Subnet CIDR ranges that the Bastion will accept SSH from. Add 35.235.240.0/20 to the list to enable GCP IAP (SSH-in-Browser) ssh access to the Bastion. Do not provide any value if bastion is not enabled."
  default     = []

  validation {
    condition = alltrue([
      for range in var.bastion_ssh_cidr :
      var.bastion_ssh_cidr == tolist([]) || can(regex("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]).){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(/([0-9]|[1-2][0-9]|3[0-2]))$", range))
    ])
    error_message = "The CIDR ranges in the bastion_ssh_cidr list must be in the form x.x.x.x/x, or do not provide any value if bastion is not enabled."
  }
}
