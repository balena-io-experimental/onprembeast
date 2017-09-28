# On-premises hostapps-update demo

This is the collection of scripts and code that was tested at the Resin.io Summit 2017 with the on-premises Beast that we've built. Most of this code is "hack"-level quality, though have been tested on a smaller imitation of the beast (3 devices, as opposed to 250+).

This repo has 3 main parts:

*   the `beast` folder which has the Dockerfile to create the example altered resinOS image
*   the example scripts to run the updates on the devices
*   the latter part of the readme, which includes how to generate delta images that can be applied

## Update logic

The heavy lifting is done by the `hostapps-update` script on the device, which is called as `hostapps-update -i <image>` to update to (optionally including the `-r` flag to reboot int he end).

To be able to run in a batch way on an on-prem setup, a number of other scripts were required.

Updating a single device:

*   `hostapps-update` runs the actual update
*   it is called by `hostapps-update.sh`, that updates the dashboard progress bar during and after the update, and reboots the device (called as `./hostapps-update.sh --hostos-version <image>`)
*   this file copied onto the device and run over ssh by `hostapps-ssh-update.sh`, which can update multiple devices if needed. It's run as `./hostapps-ssh-update.sh --hostos-version <iamge> -u <device_name_or_ip>`. It has additional functions, like limiting or expanding the parallelism of the update (`-m <threads>`). It directly logs into the device to shipt the previous script and run it. If a single device or handful of devices needed to update, this is all that's needed
*   if the entire fleet within an application needs to be updated (ie. the whole Beast), use the `beast-hup.sh` helper script. It uses resin-cli to get all the devices for an application, generate the `.local` addresses from that, create the command line options for the above scripts, and call them. NOTE: use `RESINRC_RESIN_URL=resindev.io` for the on-prem setup, and don't forget to `resin login`. Call it by `./beast-hup.sh -h <image> -a <applicationname>`.

Important to note, that the update image or update delta has to be accessible by the devices, e.g. if on-premises, in the demo the images were preloaded to `registry2.resindev.io`.

## Creating the delta hostapps-update images

The deltas setup require the new container engine created at resin.io, which has a number additional functionalities. Here's how to get it up and running as of now.

### Docker setup

Clone our docker repository and switch to the currently developed branch:

```
git clone https://github.com/resin-os/docker
cd docker
git checkout 17.06-resin
```

Compile docker (need Go for that, so install it beforehand, and make sure it works!):
```
export AUTO_GOPATH=1
./hack/make.sh dynbinary-rce-docker
```

The resulting file will be in the appropriate directory:
```
cd bundles/17.06.0-dev/dynbinary-rce-docker/
```

Start the docker daemon that listens trough a socket and over a port too:
```
sudo ./dockerd -H unix:///var/run/docker.sock -H localhost:2375
```

### Deltas setup

Once you have two images you want to delta, can call the docker daemon to create a delta container. The original example is using this coffeescript, `create-delta.conffe`, which you need to modify for the starting and destination docker image name to calculate deltas between:

```
request = require 'request'

opts =
    qs:
        src: "resin/resinos-staging:2.6.0_rev2-raspberrypi3"
        dest: "imrehg/beast:grizzly"

request.post('http://localhost:2375/deltas/create', opts, (res, body) ->
    console.log(body)
)
```
and then run
```
coffee create-delta.conffe
```
It will show the SHA of the delta, and will have a `delta:delta-xxxxxxxx` delta image.

For simplicity (to remove the coffeescript dependency), I think this shell script works too, tested it locally, YMMV:
```
#!/bin/bash

# Source docker image
SRC=$1
# Destination docker image
DEST=$2

curl -i -X POST -d "src=${SRC}&dest=${DEST}" http://localhost:2375/deltas/create
# returns code 201 if successful and the delta's SHA256 value in response body
```

A more complete shell script to help with this is provided as `gen-delta.sh` in this repo.

### Testing

Can test (written from memory) by:

*   starting from an source and destination image, check sizes
*   generate delta, check size
*   push delta to dockerhub
*   docker rmi both the destination and the delta image
*   docker pull the delta image: the resulting image should be the same size and sha as the destination image was.

## Current limitations

There are some issues that need work-around (but some has PRs already), here's just to note them:

*   Number of layers should be the same ([relevant fix](https://github.com/resin-os/docker/pull/23))
*   The source and dest at the moment shouldn't share layers

E.g. creating delta between two resinOS images works becaues they both just have 1 layers, but creating
proper delta between a resinOS image + an image made by modifying it (using a Dockerfile FROM and then add changes).

In that case, need to create a squashed image, and do that with a `bare` runtime (so docker doesn't modify the files we need):

```
docker create --runtime=bare <destination_image> /bin/sh
docker export <containerID> | docker import - <squashed_destination_image>
```
and then calculate the delta from the squashed image.

## License

Copyright 2017 Resinio Ltd.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
