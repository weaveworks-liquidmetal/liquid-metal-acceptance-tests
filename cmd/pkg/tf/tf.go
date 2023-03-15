package tf

import (
	"encoding/json"
	"io/ioutil"
)

const (
	DefaultStateFile = "terraform/terraform.tfstate"
)

type State struct {
	Outputs OutInfo `json:"outputs"`
}

type OutInfo struct {
	ManagementIp StringValue      `json:"management_ip"`
	HostIps      StringSliceValue `json:"microvm_host_ips"`
}

type StringValue struct {
	Value string `json:"value"`
}

type StringSliceValue struct {
	Value []string `json:"value"`
}

// GetOutputs will parse the terraform/terraform.tfstate for the addresses of
// the management device and the flintlockd host devices. It assumes data which
// looks like:
// {
//   "outputs": {
//     "management_ip": {
//       "value": "145.40.97.207",
//       "type": "string"
//     },
//     "microvm_host_ips": {
//       "value": [
//         "145.40.97.203",
//         "145.40.97.129"
//       ],
//       "type": [
//         "tuple",
//         [
//           "string",
//           "string"
//         ]
//       ]
//     }
//   },
// }
func GetOutputs(stateFile string) (string, []string, error) {
	dat, err := ioutil.ReadFile(stateFile)
	if err != nil {
		return "", nil, err
	}

	s := State{}
	if err := json.Unmarshal(dat, &s); err != nil {
		return "", nil, err
	}

	hosts := []string{}
	for _, h := range s.Outputs.HostIps.Value {
		hosts = append(hosts, h+":9090")
	}

	return s.Outputs.ManagementIp.Value, hosts, nil
}
