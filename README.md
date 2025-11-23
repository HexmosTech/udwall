# `udwall`: A Single-Command Tool to Make UFW Docker-Compatible

`udwall` is a declarative tool to manage UFW and Docker firewall rules using a single Python configuration file. It fixes the Docker security flaw where containers bypass UFW, and it automates rule management so you never have to run manual `ufw allow` commands again.

## What is the problem?

UFW is a popular iptables front end on Ubuntu that makes it easy to manage firewall rules. However, when Docker is installed, **Docker modifies iptables directly**, bypassing UFW rules. This means published ports (e.g., `-p 8080:80`) are accessible from the outside world, even if UFW is set to deny them.

The issue is detailed as follows (Source: [ufw-docker/problem](https://github.com/chaifeng/ufw-docker/?tab=readme-ov-file#problem)):

1.  UFW is enabled on a server that provides external services, and all incoming connections that are not allowed are blocked by default.
2.  Run a Docker container on the server and use the `-p` option to publish ports for that container on all IP addresses. For example: `docker run -d --name httpd -p 0.0.0.0:8080:80 httpd:alpine`. This command will run an httpd service and publish port 80 of the container to port 8080 of the server.
3.  **UFW will not block external requests to port 8080.** Even the command `ufw deny 8080` will not prevent external access to this port because Docker's iptables rules take precedence.
4.  This is a serious security flaw, as internal services can be inadvertently exposed to the public internet.
5.  Searching for "ufw docker" on the web reveals a lot of discussion on this critical security flaw ([source](https://github.com/chaifeng/ufw-docker/?tab=readme-ov-file#problem)):
    *   [moby/moby#4737](https://github.com/moby/moby/issues/4737)
    *   [forums.docker.com](https://forums.docker.com/t/running-multiple-docker-containers-with-ufw-and-iptables-false/8953)
    *   [techrepublic.com](https://www.techrepublic.com/article/how-to-fix-the-docker-and-ufw-security-flaw/)
    *   [blog.viktorpetersson.com](https://blog.viktorpetersson.com/2014/11/03/the-dangers-of-ufw-docker.html)
    *   [askubuntu.com](https://askubuntu.com/questions/652556/uncomplicated-firewall-ufw-is-not-blocking-anything-when-using-docker)
    *   [chjdev.com](https://chjdev.com/2016/06/08/docker-ufw/)
    *   [my.oschina.net](https://my.oschina.net/abcfy2/blog/539485)
    *   [v2ex.com](https://www.v2ex.com/amp/t/466666)
    *   [blog.36web.rocks](https://blog.36web.rocks/2016/07/08/docker-behind-ufw.html)
    *   ..

## The Previous Solution

The tool `ufw-docker` solved these issues but had a few drawbacks:

### How ufw-docker solved the issues

1.  It fixed the Docker security flaw where containers bypass UFW.
2.  **Prerequisites:** It required downloading a script to `/usr/local/bin` and running it with sudo.
3.  **Mechanism:** It modified the `/etc/ufw/after.rules` file to add a custom `DOCKER-USER` chain that correctly filters traffic destined for Docker containers, ensuring UFW rules are respected. (See [ufw-docker README](https://github.com/chaifeng/ufw-docker/?tab=readme-ov-file#how-to-do) for more details).

### Drawbacks

1.  **Manual Steps:** It required a lot of manual steps to manage rules for each container.
2.  **Persistence Issues:** Whenever UFW was disabled, Docker ports were still blocked (or rules persisted unexpectedly).
3.  **Difficult Uninstall:** To uninstall `ufw-docker`, you historically needed to remove iptables rules manually and restart the server ([source](https://github.com/chaifeng/ufw-docker/issues/89#issuecomment-1438289285)).
    > Note: Recently `ufw-docker` added an uninstall command to remove the configuration ([source](https://github.com/chaifeng/ufw-docker/commit/c45eff693f87a8a7f7a002c8b337abbf22480ca9)).

## What does udwall do?

**udwall** is a declarative tool to manage UFW and Docker firewall rules using a single configuration file.

1.  It fixes the Docker security flaw where containers bypass UFW.
2.  It automates rule management so you never have to run manual `ufw` commands again.
3.  **Configuration as Code:** Define your entire firewall state in one file (`udwall.conf`).
4.  **True Synchronization:** `udwall` performs atomic updates, removing old unused rules and applying new ones automatically.
5.  **Safety First:** Automatically backs up `/etc/ufw` and `iptables` before every change.

## Installation

You can install `udwall` with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/HexmosTech/udwall/main/install.sh | sudo bash
```

To install a specific version (e.g., `v0.0.2`), run:

```bash
curl -fsSL https://raw.githubusercontent.com/HexmosTech/udwall/main/install.sh | sudo bash -s -- --v0.0.2
```

This script will:
- Check for dependencies (`python3`, `ufw`, `curl`).
- Download `udwall` to `/usr/local/bin/udwall`.
- Set up a default configuration at `/etc/udwall/udwall.conf`.

## Usage

Currently `udwall` supports the following rule patterns:

1.  **Docker Forwarding (Any IP)**: Allow traffic to a Docker container from anywhere.
    *   `ufw route allow from any to any port <PORT> proto tcp`
2.  **Host Service (Any IP)**: Allow traffic to a service on the host (e.g., PostgreSQL) from anywhere.
    *   `ufw allow <PORT>`
3.  **Docker Forwarding (Specific IP)**: Allow traffic to a Docker container only from a specific IP.
    *   `ufw route allow from <IP> to any port <PORT> proto tcp`
4.  **Host Service (Specific IP)**: Allow traffic to a host service only from a specific IP.
    *   `ufw allow from <IP> to any port <PORT> proto tcp`
5.  **Rule Deletion**: Setting `isEnabled: false` will automatically generate the corresponding `delete` command for any of the above patterns.



### Steps to Enable `udwall`

Follow these simple steps to configure and activate `udwall` on your system. This process ensures your current firewall state is captured and safely managed going forward.

> **Note:** `udwall` requires `sudo` privileges.

#### Step 1: Create a Configuration

You can create a configuration file manually or use the `--create` command to generate one from your current live UFW rules.

```bash
sudo udwall --create
```
This creates a `udwall.conf` file in `/etc/udwall/udwall.conf`.

#### Step 2: Create Backup

You can create a backup of your current UFW rules with the `--backup` command.

```bash
sudo udwall --backup
```

This creates a timestamped backup in `/home/ubuntu/backup/firewall-backup/`, containing both iptables and UFW rules.

#### Step 3: Define Rules

Edit the configuration file at `/etc/udwall/udwall.conf`.

```python
# udwall.conf
rules = [
    # Allow SSH access from any source
    {'from': 'any', 'connectionType': 'tcp', 'to': 'OpenSSH', 'isDockerServed': False, 'isEnabled': True},

    # Allow HTTP and HTTPS traffic to the host
    {'from': 'any', 'connectionType': 'tcp', 'to': 80, 'isDockerServed': False, 'isEnabled': True},
    {'from': 'any', 'connectionType': 'tcp', 'to': 443, 'isDockerServed': False, 'isEnabled': True},

    # Allow traffic to a Docker container on port 8080 from a specific IP
    {'from': '192.168.1.100', 'connectionType': 'tcp', 'to': 8080, 'isDockerServed': True, 'isEnabled': True},

    # Allow a UDP port range for an application like Mosh
    {'from': 'any', 'connectionType': 'udp', 'to': '60000:61000', 'isDockerServed': False, 'isEnabled': True},
]
```


#### Step 4: Apply the Configuration

This will back up your current state, remove undefined rules, and apply the new ones based on the configuration file.

```bash
sudo udwall --apply
```
Backups are stored in `/home/ubuntu/backup/firewall-backup/`.

#### Step 5: Enable Firewall

This sets up the `iptables` rules required to make Docker respect UFW.

```bash
sudo udwall --enable
```
### Disable Firewall

This removes the `iptables` rules and custom chains, effectively disabling the Docker-UFW integration.

```bash
sudo udwall --disable
```


### Commands

| Command | Description |
| :--- | :--- |
| `sudo udwall --enable` | **Initialize**: Sets up the Docker-UFW integration and enables UFW. Run this first. |
| `sudo udwall --apply` | **Apply Rules**: Reads `udwall.conf`, backs up current state, and applies the new firewall rules. |
| `sudo udwall --dry-run` | **Preview**: Shows exactly which `ufw` commands would be run, without making any changes. |
| `sudo udwall --create` | **Import**: Generates a `udwall.conf` file at `/etc/udwall/udwall.conf` based on your *current* active UFW rules. |
| `sudo udwall --backup` | **Backup**: Manually creates a timestamped backup of `/etc/ufw` and `iptables` rules in `/home/ubuntu/backup/`. |
| `sudo udwall --status` | **Check Status**: Displays the current UFW status and active rules (numbered). |
| `sudo udwall --disable` | **Uninstall**: Removes the Docker-UFW integration, deletes custom chains, and disables UFW. |
| `sudo udwall --version` | **Version**: Displays the installed version of `udwall`. |
| `sudo udwall --help` | **Help**: Shows the help message and available options. |

## 🛡️ Credits

The core `iptables` logic to fix the Docker/UFW security flaw is based on the work by [chaifeng/ufw-docker](https://github.com/chaifeng/ufw-docker). `udwall` extends this by adding declarative state management.

## 📄 License

[MIT](LICENSE)
