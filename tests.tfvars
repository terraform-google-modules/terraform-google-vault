# Just required ones

project_id = "gcp-demo-project"

kms_keyring = "gcp-demo-keyring"

storage_lifecycle_rules = [{
  action = [{
      type = "Delete"
  }]
  condition = [{
      age = 60
      with_state = "ARCHIVED"
  }]
}]
