package main

import (
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"strings"

	"github.com/warehouse-13/simplessh"
	"github.com/weaveworks-liquidmetal/liquid-metal-acceptance-tests/cmd/pkg/tf"
)

const (
	defaultKey    = "keys/lm-ed"
	defaultUser   = "root"
	cmdScript     = "cmd/e2e.sh"
	capmvmRepo    = "https://github.com/weaveworks-liquidmetal/cluster-api-provider-microvm"
	defaultBranch = "main"
)

type connectOpts struct {
	connectAddress string
	privateKeyPath string
	user           string
	overrideCmd    string
	tfStateFile    string
	command        cmdOpts
}

type cmdOpts struct {
	flintlockHosts string
	repo           string
	branch         string
	version        string
}

func main() {
	opts := connectOpts{}

	flag.StringVar(&opts.tfStateFile, "state-file", tf.DefaultStateFile, "Path to terraform state file from which to derive host addresses. (optional)")
	flag.StringVar(&opts.connectAddress, "address", "", "IP address of host to run SSH command on. (optional)")
	flag.StringVar(&opts.privateKeyPath, "private-key", defaultKey, "Path to file containing private key for connection address. (optional)")
	flag.StringVar(&opts.command.flintlockHosts, "flintlock-hosts", "", "Comma separated list of flintlock server addresses with ports. (optional)")
	flag.StringVar(&opts.command.repo, "repo", "", "URL of non-default CAPMVM repository to clone for tests. (optional)")
	flag.StringVar(&opts.command.branch, "branch", "", "Branch within CAPMVM repository to clone for tests. (optional)")
	flag.StringVar(&opts.command.version, "version", "", "Version of CAPMVM to test against. (optional)")
	flag.StringVar(&opts.overrideCmd, "command", "", "Non-standard command to run on the target machine. (optional)")
	flag.StringVar(&opts.user, "user", defaultUser, "User to run command as. (optional)")

	flag.Parse()

	if !isSet(opts.connectAddress) || !isSet(opts.command.flintlockHosts) {
		addr, hosts, err := tf.GetOutputs(opts.tfStateFile)
		if err != nil {
			fmt.Println(err)
			os.Exit(1)
		}

		opts.connectAddress = addr
		opts.command.flintlockHosts = strings.Join(hosts, ",")
	}

	if err := opts.validate(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	if err := executeRemoteCommand(opts); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

func isSet(val string) bool {
	return val != ""
}

func (o connectOpts) validate() error {
	if o.connectAddress == "" {
		return errors.New("address is required")
	}

	if o.command.flintlockHosts == "" {
		return errors.New("flintlock-hosts is required")
	}

	if _, err := os.Stat(o.privateKeyPath); os.IsNotExist(err) {
		return fmt.Errorf("private-key must be an existing file: %w", err)
	}

	return nil
}

func executeRemoteCommand(opts connectOpts) error {
	client, err := simplessh.ConnectWithKeyFile(opts.connectAddress, opts.user, opts.privateKeyPath)
	if err != nil {
		return fmt.Errorf("Could not connect to management host %w", err)
	}

	defer client.Close()

	cmd := opts.overrideCmd

	if cmd == "" {
		cmd, err = buildCmd(opts.command)
		if err != nil {
			return err
		}
	}

	log.Printf("Running command as user '%s' on machine '%s':\n%s\n", opts.user, opts.connectAddress, cmd)
	if err := client.ExecStream(cmd, os.Stdout); err != nil {
		return err
	}

	return nil
}

func buildCmd(opts cmdOpts) (string, error) {
	dat, err := ioutil.ReadFile(cmdScript)
	if err != nil {
		return "", err
	}

	repo := capmvmRepo
	branch := defaultBranch

	script := string(dat)

	script = strings.Replace(script, "ADDRESSES", opts.flintlockHosts, 1)

	if opts.version != "" {
		branch = opts.version
	} else {
		if opts.repo != "" {
			repo = opts.repo
		}

		if opts.branch != "" {
			branch = opts.branch
		}
	}

	script = strings.Replace(script, "REPO", repo, 1)
	script = strings.Replace(script, "BRANCH", branch, 1)

	return script, nil
}
