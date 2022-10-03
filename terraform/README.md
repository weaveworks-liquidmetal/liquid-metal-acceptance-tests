# Terraform

This dir holds the terraform manifests to provision the infrastructure
used by the Liquid Metal Acceptance Tests. It uses the liquidmetal equinix terraform
module which can be found [here][tf-mod].

> Note: there is some duplication between this terraform setup and the one I use
for demos. I am refactoring both to use common modules.

It is advised and intended for this to be used from the Makefile in the root of
the directory. Things may not work as planned if things are triggered elsewhere.

## Provision

To provision infra with this config:

```bash
export METAL_AUTH_TOKEN=
export METAL_ORG_ID=
```

_If you are a quicksilver team-member, or part of Weaveworks, these credentials
can be found in 1Pass. Ask Claudia if you are not sure where._

```bash
make tf-up
```

Then to tear down:

```bash
make tf-down
```

All `make tf-x` commands will call `scripts/tf.sh`.

### Vars

Required vars:
- `METAL_ORG_ID`
- `METAL_AUTH_TOKEN`

Optional vars:
- `FLINTLOCK_VERSION`
- `DEVICE`
- `DEVICE_COUNT`
- `PROJECT_NAME`

_Note that project names are not unique in Equinix, so you wont be able to use
an existing one here._

### Up

The up command will first delegate to `make tf-vars` which will generate a new
`terraform/terraform.tfvars.json` which is ignored by git.
This is based on the `terraform/terraform.tfvars.example.json` template which is
checked into git.
The script will use `scripts/check.py` to find a metro which has capacity for the
number and type of Equinix servers required.
It will also generate an SSH key pair which will be used while provisioning to
execute scripts on the devices as well as to run the tests.

The metro and SSH details, along with any variable overrides will be added to the
vars file.

To automate the `apply`, a plan is generated at `apply.tf`. This is then `auto-approve`d
for deployment.

By default, 3 devices will be created. One will act as the host for the test's CAPI
management cluster, as well as running a DHCP server and a NAT forwarder.
The other 2 will run flintlock servers.

Other Equinix artefacts include a VLAN with hybrid `bond`ed ports to each device
for that VLAN.

The devices are configured using the scripts in `terraform/files`. These are copied
over and then executed remotely as part of the deployment.

Management device:
- `dhcp.sh` configures and starts a DHCP server
- `vlan.sh` adds the device to the VLAN network via the `bond0` interface
- `nat.sh` sets up route forwarding between the private VLAN and the internet
- `installables.sh` installs various tools required to run or debug the tests

Flintlock hosts:
- `vlan.sh` adds the device to the VLAN network via the `bond0` interface
- `flintlock.sh` provisions the machine to run flintlock and starts the server

### Down

The down command will remove everything. If the bond port is deleted before the
devices have actually come down it may fail, so just call `make tf-down` a second
time and it will clear it.

[tf-mod]: https://registry.terraform.io/modules/weaveworks-liquidmetal/liquidmetal/equinix/latest
