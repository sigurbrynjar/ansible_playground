# Ansible Playground

We will use Docker to serve up two container nodes that will be our inventory and we can play around with Ansible.

### Install docker and docker compose

https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository

```bash
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

https://docs.docker.com/engine/install/linux-postinstall/

Configure so that we can run docker without sudo:

```bash
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
```

Log out and back in or reboot OS.

### Install Ansible

https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html

```bash
sudo apt update
sudo apt install software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible ansible-lint
```

or simply

```sh
pip install ansible
```

### Dockerfile and docker-compose.yml

The Dockerfile defines the image we want to build. We can also just specify an image from dockerhub, but it needs to at least have Python (required by apt).

Build the image and then run the containers with

```bash
docker compose build  # Pulls name ansible-test-image from docker-compose.yml
docker compose up -d
```

### Ansible inventory.ini & playbook.yml

The inventory defines node1 and node2 as worker nodes.

The playbook defines the tasks which will install curl, wget and ping.

### Run Ansible

```sh
ansible-playbook -i inventory.ini playbook.yml
```

### Create a http local server

If you want to serve up files for the containers to wget, then, from some directory with some files, run

```sh
python3 -m http.server 8000 --bind 0.0.0.0
```

The --bind 0.0.0.0 is optional, but ensures the server listens on all network interfaces, making it accessible to Docker containers.

You can see the server at localhost:8000 now.

Identify the gateway IP address that Docker exposes to containers for accessing the host on the default bridge network:

```sh
docker network inspect bridge | grep Gateway | sed -E 's/.*"Gateway": "([^"]+)".*/\1/'
```

It will likely be 172.17.0.1. If you are using a custom network it will be different and you have to inspect that instead of the default bridge.

### Attach a shell to one of the containers

Enter the container:

```sh
docker exec -it node1 bash
```

Try running any of these:

```sh
ping -c2 172.17.0.1
curl www.google.com
curl 172.17.0.1:8000
wget 172.17.0.1:8000/somefile
```

This should confirm the ansible playbook ran correctly!


## Using Ansible


List inventory:

```sh
ansible-inventory -i inventory.ini --list
```

Ping the `node_servers` group:
```sh
ansible node_servers -m ping -i inventory.ini
```

Pass the -u option with the ansible command if the username is different on the control node and the managed node(s).

If you do not want cowsay you can:

```sh
export ANSIBLE_NOCOWS=1
```

or if you want some chaos:

```sh
export ANSIBLE_COW_SELECTION=random
```

### Modules

Modules are the code or binaries that Ansible copies to and executes on each managed node (when needed) to accomplish the action defined in each Task.

Each module has a particular use, from administering users on a specific type of database to managing VLAN interfaces on a specific type of network device.

Ansible has builtin modules like `copy`, `file`, `service`, `yum`, `apt`, etc.

We can include a module like this:

```yaml
- name: Install Nginx
  hosts: webservers
  tasks:
    - name: Install Nginx using apt
      ansible.builtin.apt:
        name: nginx
        state: present
```

Here, `ansible.builtin.apt` is the module used in the task. We can simply refer to it by `apt` but it is recommended to use the FQDN (Fully Qualified Domain Name).

Modules can be built-in (shipped with Ansible) or custom.


### Plugins

Plugins are pieces of code that expand Ansible’s core capabilities. Plugins can control how you connect to a managed node (connection plugins), manipulate data (filter plugins) and even control what is displayed in the console (callback plugins).

### Collections

A collection is a bundle of related content, which may include:
- Modules
- Roles (reusable sets of tasks)
- Plugins (filters, lookups, callbacks)
- Playbooks

Collections are namespace-based (e.g., community.general or amazon.aws) and are hosted on Ansible Galaxy (galaxy.ansible.com) or can be installed locally.

https://docs.ansible.com/ansible/latest/collections/index.html


### Execution Environments (EE)

Ansible uses container images known as Execution Environments (EE) that act as control nodes. EEs remove complexity to scale out automation projects and make things like deployment operations much more straightforward.

An Execution Environment image contains the following packages as standard:
- ansible-core
- ansible-runner
- Python
- Ansible content dependencies

In addition to the standard packages, an EE can also contain:
- one or more Ansible collections and their dependencies
- other custom components

Instead of managing dependencies manually, we define them in an EE, and it ensures a consistent execution environment across different systems (local, CI/CD, production).

#### Building & Setting up an EE

We will use the `test_ee` directory to build our EE.

```sh
pip install ansible-navigator
ansible-builder build --tag postgresql_ee --container-runtime docker -f execution_environment.yml
```

See `context/Dockerfile` for the Dockerfile used.

(Why the fuck do we call the image `postgresql_ee`? This example is from the Ansible docs https://docs.ansible.com/ansible/latest/getting_started_ee/build_execution_environment.html If we look at the Dockerfile we see it is built from a Fedora image, where does Postgres come in... ??).

We should be able to use Podman instead of Docker, but I had problems with Podman. If Podman doesn't work, be sure to uninstall it completely:

```sh
pip uninstall podman
sudo apt remove podman
```

Now we can run `ansible-navigator` which is a command-line tool and a text-based user interface (TUI) for creating, reviewing, running and troubleshooting Ansible content, including inventories, playbooks, collections, documentation and container images (execution environments).

In the TUI, type `:images` and select the `postgresql_ee`.

(The TUI is weird - I don't know how to properly use it :/)

We have a playbook `test_localhost.yml` to test our EE `postgresql_ee` against localhost. The only task is to print facts about the target machine (localhost in this case).

Now run this:

```sh
ansible-navigator run test_localhost.yml --execution-environment-image postgresql_ee --mode stdout --pull-policy missing --container-options='--user=0'
```

#### Using a Prebuilt EE Docker Image

We can also use a Red Hat-supported, officially maintained Ansible EE image from Red Hat's Quay.io (a container registry):

```sh
docker pull quay.io/ansible/ansible-runner
```

Then we can run ansible with

```sh
docker run --rm -v $(pwd):/work -w /work quay.io/ansible/ansible-runner ansible-playbook test_localhost.yml
```


#### Building a Singularity/Apptainer EE Image

**NOTE** I can't get this to work.

Move over to the `apptainer_test_ee` directory.

On LUMI, we cannot use Docker/Podman since they either require running as root or doing some magic to get around it. Instead, we use Singularity/Apptainer. To install it:

```sh
# Dependencies:
sudo apt-get update && sudo apt-get install -y \
    build-essential \
    libssl-dev \
    uuid-dev \
    libgpgme11-dev \
    squashfs-tools \
    libseccomp-dev \
    pkg-config

# https://go.dev/dl/
# Go (update version and architecture if needed, but new versions may not work with this guide):
export VERSION=1.11 OS=linux ARCH=amd64 && \
    wget https://dl.google.com/go/go$VERSION.$OS-$ARCH.tar.gz && \
    sudo tar -C /usr/local -xzvf go$VERSION.$OS-$ARCH.tar.gz && \
    rm go$VERSION.$OS-$ARCH.tar.gz
  
echo 'export GOPATH=${HOME}/go' >> ~/.bashrc && \
    echo 'export PATH=/usr/local/go/bin:${PATH}:${GOPATH}/bin' >> ~/.bashrc && \
    source ~/.bashrc

go get -u github.com/golang/dep/cmd/dep

# Singularity:
go get -d github.com/sylabs/singularity
export VERSION=v3.0.3 # or another tag or branch if you like && \
    cd $GOPATH/src/github.com/sylabs/singularity && \
    git fetch && \
    git checkout $VERSION # omit this command to install the latest bleeding edge code from master
./mconfig && \
    make -C ./builddir && \
    sudo make -C ./builddir install

echo '. /usr/local/etc/bash_completion.d/singularity' >> ~/.bashrc  # For bash completion
```

Take a look at the `execution_environment.yml`. Now, let's build this *first* as a docker image:

```sh
ansible-builder build --tag climate_ansible_ee --container-runtime docker -f execution_environment.yml
```

I can't get this to work ffs... onto other things!


### Other things

#### ansible-core and ansible

`ansible-core` is the minimal version of Ansible that includes no plugins. Install `ansible` instead for a full version if desired.

#### Ansible config

Config file is searched for in this order:

- `ANSIBLE_CONFIG` (environment variable i set)
-`ansible.cfg` (in the current directory)
- `~/.ansible.cfg` (in the home directory)
- `/etc/ansible/ansibl.cfg`

Generate a full config file with all options commented out:

```sh
ansible-config init --disabled > ansible.cfg
```

Generate a more complete config file that includes existing plugins:

```sh
$ ansible-config init --disabled -t all > ansible.cfg
```

Set `nocows=True` if you hate your life.

Set `cow_selection=random` if you love your life. You can also set environment variables which take precedence over the config, like `export ANSIBLE_COW_SELECTION=duck` if you want to be a duck.


#### Ansible Facts

Facts are information about the target machine that Ansible gathers. They are stored in the `ansible_facts` dictionary.

```yaml

- name: Gather facts
  hosts: all
  tasks:
    - name: Print facts
      ansible.builtin.debug:
        var: ansible_facts
```


#### Ansible Roles


#### Ansible Galaxy


#### Ansible Tower


#### Ansible AWX


#### Ansible Vault

