# Upgrade from 4.2.0 to 5.0.0

This is a major refactor that pulls the core Vault logic into its own submodule. Therefore this upgrade will require moving around some state so that data is retained.

## Upgrade process

Before we get started, and **before** you bump the version in the module, ensure that `terraform plan` will not make any changes. We'll be scraping the plan output to see what should be moved around in the state.

First, we'll need to upgrade the provider:

```
terraform init
```

Next what we're going to do is see, in your implementation what is attempting to change. Since we shouldn't have any other changes, these changes will be due to the movement of the Vault resources to a submodule. Therefore we must move each of them to it's new heirarchy in the state.

### Get the commands

In this directory, we've provided a simple script that will determine what changes should likely be made. Since everyone's terraform deployments are slightly different we make no guarantees this will work for everyone. This is why the command doesn't actually execute the commands but rather generates them so you can play with them as you see fit. It generates `-dry-run` commands unless explicitly specified otherwise.


First let's see what the commands will look like. `cd` into the top level directory where you run your `terraform plan` and copy the `gen_upgrade_commands.rb` from this directory into the directory you're working in to make referencing simple.

```
./gen_upgrade_commands.rb
===> Executing with -dry-run. To actually run, execute:
===>   upgrade-v5.0.rb -no-dry-run | bash
terraform state mv -dry-run 'module.vault.google_compute_forwarding_rule.external[0]' 'module.vault.module.cluster.google_compute_forwarding_rule.external[0]'
terraform state mv -dry-run 'module.vault.google_compute_http_health_check.vault[0]' 'module.vault.module.cluster.google_compute_http_health_check.vault[0]'
...
```

### Dry Run

Make sure that all of those commands look good to you, then you can run the following since, as you can tell from above, it's in dry run mode so there's no risk here:

```
./gen_upgrade_commands.rb | bash
Would move "module.vault.google_compute_forwarding_rule.external[0]" to "module.vault.module.cluster.google_compute_forwarding_rule.external[0]"
Would move "module.vault.google_compute_http_health_check.vault[0]" to "module.vault.module.cluster.google_compute_http_health_check.vault[0]"
...
```

### For real this time

Only run the following if the dry run didn't produce any errors:

```
./gen_upgrade_commands.rb -no-dry-run | bash
Move "module.vault.google_compute_forwarding_rule.external[0]" to "module.vault.module.cluster.google_compute_forwarding_rule.external[0]"
Successfully moved 1 object(s).
Move "module.vault.google_compute_http_health_check.vault[0]" to "module.vault.module.cluster.google_compute_http_health_check.vault[0]"
Successfully moved 1 object(s).
...
```

Now you should be able to run the plan and see no changes!

```
$ terraform plan
...
------------------------------------------------------------------------

No changes. Infrastructure is up-to-date.

This means that Terraform did not detect any differences between your
configuration and real physical resources that exist. As a result, no
actions need to be performed.
```
