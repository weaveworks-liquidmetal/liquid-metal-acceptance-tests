# Cmd

This is a small helper tool to run the Acceptance tests (LMATS) on remote
Equinix infrastructure.

This tool will change when we have built the scheduler component.

This tool will go away when I have figured out some more networking for the infra.

## What and why

There are 2 reasons it exists:
1. To save time on networking complexity during my initial stab at these tests,
  I chose not to set it up so that the CAPI management cluster could be run
  from outside the Equinix infra network.
  _Technically_ it could be since the flintlock servers are bound to a public
  interface, but the next hurdle then would have been the control plane
  load balancer address: I would have had to figure out a way to dynamically reserve
  an IPv4 address and then ensure that it was allocated to the workload cluster.
  This is not easy to do in Equinix.
  Alternatively, I would have had to automate a VPN to route the private subnets
  of the infra, which again is a pain. At some point I will get to solving these.
2. Until we develop the dynamic scheduler, we need to inject the individual
  flintlock server IPs into any CAPMVM workload cluster template. This is a pain
  to do with CAPI/clusterctl and naturally these IPs are not known ahead of time
  (although I could do something with DNS I suppose? But then would I have to deal
  with records not being updated in time for the test?). So the tests are built
  to receive the IPs and then alter the template; this tool handles the extraction,
  formatting and pass-through of the created infra IPs from the Terraform output
  to the tests. See [here][capmvm-e2e] for more on how the e2es work.

So for now, the tests are triggered locally but actually run from within one of
the Equinix machines.

The sequence of events is as follows:
- The tool is built and called from the Makefile (`make e2e`)
- It processes and validates any given flags
- It parses the `../terraform/terraform.tfstate` file for the `outputs.host_ips`
  and `outputs.management_ip`
- The `host_ips` are formatted ready for use as flintlock addresses by the tests
- The command to run over SSH is built from `e2e.sh` template
- A connection to the `management_ip` is opened using the keys created by the terraform
  provisioning script
- The command is executed
  - Clone CAPMVM at the set version/repo/branch
  - `cd` and start tests
  - `cd ..` and remove the directory
- All output is streamed back in real time

## How to use

The tool is most often called from the root Makefile:

```bash
make build-e2e # creates the binary
make e2e # executes the tool
```

The tool has various flags, none of which need to be set:

```
Usage of ./cmd/bin/e2e:
  -address string
        IP address of host to run SSH command on. (optional)
  -branch string
        Branch within CAPMVM repository to clone for tests. (optional)
  -command string
        Non-standard command to run on the target machine. (optional)
  -flintlock-hosts string
        Comma separated list of flintlock server addresses with ports. (optional)
  -private-key string
        Path to file containing private key for connection address. (optional) (default "keys/lm-ed")
  -repo string
        URL of non-default CAPMVM repository to clone for tests. (optional)
  -state-file string
        Path to terraform state file from which to derive host addresses. (optional) (default "terraform/terraform.tfstate")
  -user string
        User to run command as. (optional) (default "root")
  -version string
        Version of CAPMVM to test against. (optional)
```

These can be passed either to the binary directly:

```bash
./cmd/bin/e2e -repo foo
```

Or when calling the `make` command (preferred):

```bash
make e2e E2E_ARGS="-repo foo"
```

Some flags have an order of precedence:
- If `-version` is set, `-repo` and `-branch` will be ignored
- If `-flintlock-hosts` OR `-address` are set, the tool will not look up the
  required connection/test info from the terraform output.

[capmvm-e2e]: https://github.com/weaveworks-liquidmetal/cluster-api-provider-microvm/test/e2e
