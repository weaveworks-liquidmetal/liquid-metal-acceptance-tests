#!/usr/bin/env python3

import packet
import os
import sys

auth_token = os.environ.get('METAL_AUTH_TOKEN')
packet_manager = packet.Manager(auth_token=auth_token)

args = sys.argv[1:]
if len(args) != 2:
    print('2 arguments (plan type, device count) required')
    sys.exit(1)

plan = args[0]
device_count = args[1]
metros  = ['ld', 'md', 'pa', 'am', 'fr']

for metro in metros:
    server = [(metro, plan, device_count)]
    if packet_manager.validate_metro_capacity(server):
        print(metro, end = '')
        sys.exit(0)

sys.exit(1)
