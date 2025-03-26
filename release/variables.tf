variable "PrefixCode" {
  description = "Prefix for resource names"
  type        = string
}
variable "Region" {
  description = "AWS region for resource deployment"
  type        = string
}

variable "EnvTag" {
  description = "Environment identifier for resource tagging (e.g., dev, prod)"
  type        = string
}

variable "SolTag" {
  description = "Solution identifier for resource grouping and tagging"
  type        = string
}
variable "GeoRestriction" {
  description = "List of ISO Alpha-2 country codes for geo-restriction. Example: GB for UK, IE for Ireland. Leave empty [] for no restrictions"
  type        = list(string)
  default     = []
}