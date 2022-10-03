# LMATS (Liquid Metal Acceptance Tests)

<!--
To update the TOC, install https://github.com/kubernetes-sigs/mdtoc
and run: mdtoc -inplace README.md
-->

<!-- toc -->
- [What they test](#what-they-test)
- [How they work](#how-they-work)
- [How to run...](#how-to-run)
  - [Locally (option 1)](#locally-option-1)
    - [Tunables](#tunables)
  - [Locally (option 2)](#locally-option-2)
  - [Locally (option 3)](#locally-option-3)
  - [In CI](#in-ci)
<!-- /toc -->

## What they test

The LMATS are the highest level test suite for the Liquid Metal project. Thus they
ensure that the basic behaviour exposed to a user does what it should.

They ensure that the 2 key components of Liquid Metal ([flintlock][flintlock]
and [CAPMVM][capmvm]) work properly together.

They run daily as a Github Action. See [here][actions] for runs and results.

## How they work

This repo contains the infrastructure config and "trigger points" for running the
LMATS on a non-local (as in not on your computer) bare-metal environment.
The test code itself for now lives in [CAPMVM][capmvm-e2e].

There are 2 main parts to this repo:
- [`terraform/`][tf] which contains manifests for provisioning bare-metal infrastructure
   and configuring flintlock using the [Liquid Metal Equinix module][tf-mod].
- [`cmd/`][tool] which triggers the execution of the tests.

The sequence of events for a full run is:
- Terraform section...
  - Check capacity of Equinix for requested device types and select metro with
    sufficient space
  - Generate SSH keys for use during infrastructure provisioning and later test
    execution
  - Create Equinix project
  - Create 1 host to act as the CAPI management cluster and network "hub"
  - Create 2 further hosts to run flintlock _can be overridden_
  - Bootstrap some rudimentary networking
  - Provision flintlock
  - Prepare the "management" host to run CAPI
- Test runner section (over SSH to the management host)...
  - Prepare configuration based on the output of the Terraform step and any
    action inputs
  - Clone CAPMVM on the management host
  - Change into the directory and run the e2e tests
- E2E section (streamed over SSH from the management host)...
  - Create a kind cluster
  - Initialise the cluster with required CAPI controllers
  - Generate a template for the CAPMVM workload cluster
  - Apply the workload cluster yaml to the kind cluster
  - Ensure all supplied flintlock hosts have been used
  - Deploy an application to the workload cluster
- Teardown

## How to run...

This system is primarily intended to be used by:
- CI (we cannot enable KVM in action runners, so we have to do a lot of infra
  provisioning)
- People who do not want, do not have, or have totally borked their local flintlock /
  general Liquid Metal environment on their own computer

It is possible, although not really advisable or necessary, to run it locally and
there are a few options for doing so.

### Locally (option 1)

To run the LMATS against non-local bare-metal infrastructure, first clone and
change into this repo:

```bash
git clone https://github.com/weaveworks-liquidmetal/liquid-metal-acceptance-tests
cd liquid-metal-acceptance-tests
```

Install some python reqs:

```bash
cd scripts
pip3 install -r requirements.txt
```

Set the required environment variables:

```bash
export METAL_AUTH_TOKEN=
export METAL_ORG_ID=
```

_If you are a quicksilver team-member, or part of Weaveworks, these credentials
can be found in 1Pass. Ask Claudia if you are not sure where._

Call the Make command:

```bash
make all
```

This process is quite lengthy, you are looking at 10-20 mins. The test section
alone can take up to 5 mins to run (I am working on making that faster).

To work in steps, or to run the tests several times with the same infrastructure,
you can call the individual targets:

```bash
make tf-up
make e2e # add any flags here as E2E_ARGS="--foo bar" see 'Tunables' below for more
make tf-down
```

If run in stages like this, the `make e2e` command can be run several times.
Always remember to tear down the infra (`make tf-down`) at the end of the day.

#### Tunables

The following configuration options/variables can be changed via the environment:
- `PROJECT_NAME`: change the name of the project to be created in Equinix (default:
  `"liquid-metal-acceptance-tests"`. Note that project names in Equinix are not
  unique, so if you wish to use an existing project, setting this will not work.
- `FLINTLOCK_VERSION`: change the version of flintlock used in the tests (default:
  [latest][flintlock-releases]).
- `DEVICE_COUNT`: change the number of bare-metal hosts which will run flintlock
  (default: `2`).
- `DEVICE`: change the type of Equinix devices (default: `c3.small.x86`).
- `E2E_ARGS`: append flags to the test command:
  - `-version`: the version of CAPMVM to use in the tests (if set will override
    `repo` and `branch`). Must match exactly the tag name of the release, eg: `v0.1.0`.
  - `-repo`: the URL to a repo (fork) of CAPMVM to use in the tests.
  - `-branch`: the name of a branch to use in the tests. Can be used in combination
    with `repo` or alone to target a branch of the upstream repo.
  - These flags are properties of the test runner. For more information on how
    that works and what other flags are available, see the [tool readme][tool].

For example, to run the LMATS against version `v0.1.0` of Flintlock and against
a branch on my fork of CAPMVM:

```
export FLINTLOCK_VERSION=v0.1.0
make all E2E_ARGS="--repo https://github.com/Callisto13/cluster-api-provider-microvm --branch e2e"
```

### Locally (option 2)

If you are not interested in running the tests against a bare-metal host so far
away, you can simply run the E2Es in CAPMVM without any of this. You wont need
to clone this repo, but you will need two others and will need to put a bit more
work into setting up.

_Note this will only be applicable to people running Linux._

See the CAPMVM e2e docs [here][capmvm-e2e] for how to do this.

### Locally (option 3)

The last option is for those who have borked or just don't want to set up their
flintlock, but they perhaps want to iterate on a local version of CAPMVM. Here we
have a mix of both worlds, where you use the LMATS to provision flintlock on remote
Equinix hosts, and then tell the local E2Es where those hosts are.

Clone this repo:

```bash
git clone https://github.com/weaveworks-liquidmetal/liquid-metal-acceptance-tests
cd liquid-metal-acceptance-tests
```

Install some python reqs:

```bash
cd scripts
pip3 install -r requirements.txt
```

Set the required environment variables:

```bash
export METAL_AUTH_TOKEN=
export METAL_ORG_ID=
```

Create the Equinix infrastructure:

```bash
make tf-up
# take note of the 'host_ips' in the terraform output
```

TODO: there is some additional networking needed here to ensure that CAPMVM can
access the load balancer address of the created workload cluster. I will add it
at some point. https://github.com/weaveworks-liquidmetal/liquid-metal-acceptance-tests/issues/5

Then clone CAPMVM:

```bash
git clone https://github.com/weaveworks-liquidmetal/cluster-api-provider-microvm
cd cluster-api-provider-microvm
```

Follow the CAPMVM [e2e docs][capmvm-e2e] from "Run the tests" onwards.

When you are done, don't forget to destroy the infrastructure:

```bash
make tf-down
```

### In CI

The LMATS will run every day automatically, but they can also be triggered manually
and configured to run with a combination of component versions.

_Note: this option is only available to members of Weaveworks._

Navigate to the [actions tab][actions].

Select the `Run workflow` on the right.

To run with the default settings, click the green `Run workflow` button.

Otherwise you can configure any/all of the below before triggering:
- `flintlock_version`: the version of flintlock to use in the tests.
- `capmvm_version`: the version of CAPMVM to use in the tests (if set will override
  `capmvm_repo` and `capmvm_branch`). Must match exactly the tag name of the release, eg: `v0.1.0`.
- `capmvm_repo`: the URL to a repo (fork) of CAPMVM to use in the tests.
- `capmvm_branch`: the name of a branch to use in the tests. Can be used in combination
  with `capmvm_repo` or alone to target a branch of the upstream repo.

It can take up to 20 mins to provision the infra and run the tests. The result will
be posted in the `#team-quicksilver` slack channel.

If anything goes wrong there is a step in the action to remove all the infra.
I will be exposing an option to keep things around if needed.

[flintlock]: https://github.com/weaveworks-liquidmetal/flintlock
[capmvm]: https://github.com/weaveworks-liquidmetal/cluster-api-provider-microvm
[capmvm-e2e]: https://github.com/weaveworks-liquidmetal/cluster-api-provider-microvm/tree/main/test/e2e
[flintlock-releases]: https://github.com/weaveworks-liquidmetal/flintlock/releases
[tool]: /cmd
[tf]: /terraform
[actions]: https://github.com/weaveworks-liquidmetal/liquid-metal-acceptance-tests/main/workflows/nightly_e2e.yml
[tf-mod]: https://registry.terraform.io/modules/weaveworks-liquidmetal/liquidmetal/equinix/latest
