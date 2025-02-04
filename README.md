# Ansible Playground

We will use Docker to serve up two container nodes that we can play around with Ansible.

## Install docker and docker compose

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

## Install Ansible

```bash
sudo apt update
sudo apt install software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible ansible-lint
```

## Dockerfile and docker-compose.yml

The Dockerfile defines the image we want to build. Minimal images often lack python which is required for this.

Build the image and then run the containers with

```
docker compose build  # Pulls name ansible-test-image from docker-compose.yml
docker compose up -d
```

## Ansible inventory.ini & playbook.yml

The inventory defines node1 and node2 as worker nodes.

The playbook defines the tasks which will install curl, wget and ping.

## Run Ansible

```
ansible-playbook -i inventory.ini playbook.yml
```

## Create a http local server

From some directory with some files, run

```
python3 -m http.server 8000 --bind 0.0.0.0
```

The --bind 0.0.0.0 ensures the server listens on all network interfaces, making it accessible to Docker containers.

You can see the server at localhost:8000 now.

Find the IP address accessible from docker containers:

```
ip addr show docker0
```

Look for an IP like:

```sh
inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
```

Here, 172.17.0.1 is the host IP exposed to Docker containers on the default bridge network.

## Attach a shell to one of the containers

Enter the container:

```
docker exec -it node1 bash
```

Try running:

```
ping -c2 172.17.0.1
wget 172.17.0.1:8000/somefile
```

This should confirm the ansible playbook ran correctly!


## Notes:

If using custom Docker networks, the docker0 IP might differ or not apply. In such cases, inspect the network:

```
docker network inspect bridge
```

