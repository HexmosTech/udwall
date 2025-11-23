# `udwall`: UFW + Docker Firewall Manager

`udwall` is a declarative tool to manage UFW and Docker firewall rules using a single Python configuration file. It fixes the Docker security flaw where containers bypass UFW, and it automates rule management so you never have to run manual `ufw allow` commands again.

## What is the problem?

UFW is a popular iptables front end on Ubuntu that makes it easy to manage firewall rules. But when Docker is installed, **Docker bypasses the UFW rules**, and published ports can be accessed from outside.

The issue is detailed as follows (Source: [ufw-docker/problem](https://github.com/chaifeng/ufw-docker/blob/main/README.md#problem)):

1.  UFW is enabled on a server that provides external services, and all incoming connections that are not allowed are blocked by default.
2.  Run a Docker container on the server and use the `-p` option to publish ports for that container on all IP addresses. For example: `docker run -d --name httpd -p 0.0.0.0:8080:80 httpd:alpine`. This command will run an httpd service and publish port 80 of the container to port 8080 of the server.
3.  **UFW will not block all external requests to visit port 8080.** Even the command `ufw deny 8080` will not prevent external access to this port.
4.  This problem is actually quite serious, which means that a port that was originally intended to provide services internally is exposed to the public network.
5.  Searching for "ufw docker" on the web reveals a lot of discussion on this critical security flaw:
    *   [moby/moby#4737](https://github.com/moby/moby/issues/4737)
    *   [forums.docker.com](https://forums.docker.com/t/running-multiple-docker-containers-with-ufw-and-iptables-false/8953)
    *   [techrepublic.com](https://www.techrepublic.com/article/how-to-fix-the-docker-and-ufw-security-flaw/)
    *   [blog.viktorpetersson.com](https://blog.viktorpetersson.com/2014/11/03/the-dangers-of-ufw-docker.html)
    *   [askubuntu.com](https://askubuntu.com/questions/652556/uncomplicated-firewall-ufw-is-not-blocking-anything-when-using-docker)
    *   [chjdev.com](https://chjdev.com/2016/06/08/docker-ufw/)
    *   [my.oschina.net](https://my.oschina.net/abcfy2/blog/539485)
    *   [v2ex.com](https://www.v2ex.com/amp/t/466666)
    *   [blog.36web.rocks](https://blog.36web.rocks/2016/07/08/docker-behind-ufw.html)

## The Previous Solution: ufw-docker

The tool `ufw-docker` solved these issues but had a few drawbacks:

1.  **Manual Steps:** It required a lot of manual steps to manage rules for each container.
2.  **Persistence Issues:** Whenever UFW was disabled, Docker ports were still blocked (or rules persisted unexpectedly).
3.  **Difficult Uninstall:** To uninstall `ufw-docker`, you historically needed to remove iptables rules manually and restart the server ([source](https://github.com/chaifeng/ufw-docker/issues/89#issuecomment-1438289285)).
    > Note: Recently `ufw-docker` added an uninstall command to remove the configuration ([source](https://github.com/chaifeng/ufw-docker/commit/c45eff693f87a8a7f7a002c8b337abbf22480ca9)).

### How ufw-docker solved the issues

1.  It fixed the Docker security flaw where containers bypass UFW.
2.  **Prerequisites:** It required downloading a script to `/usr/local/bin` and running it with sudo.
3.  **Mechanism:** It modified the `/etc/ufw/after.rules` file to add a custom `DOCKER-USER` chain that correctly filters traffic destined for Docker containers, ensuring UFW rules are respected. (See [ufw-docker README](https://github.com/chaifeng/ufw-docker/blob/master/README.md#how-to-do) for details).

## The Solution: udwall

**udwall** is a declarative tool to manage UFW and Docker firewall rules using a single configuration file.

1.  It fixes the Docker security flaw where containers bypass UFW.
2.  It automates rule management so you never have to run manual `ufw allow` commands again.
3.  **Configuration as Code:** Define your entire firewall state in one file (`udwall.conf`).
4.  **True Synchronization:** `udwall` performs atomic updates, removing old unused rules and applying new ones automatically.
5.  **Safety First:** Automatically backs up `/etc/ufw` and `iptables` before every change.

## Installation

You can install `udwall` with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/HexmosTech/udwall/main/install.sh | sudo bash
```

This script will:
- Check for dependencies (`python3`, `ufw`, `curl`).
- Download `udwall` to `/usr/local/bin/udwall`.
- Set up a default configuration at `/etc/udwall/udwall.conf`.

## Usage

**Note:** `udwall` requires `sudo` privileges.

### Fix the Docker Flaw & Enable UFW

This sets up the `iptables` rules required to make Docker respect UFW.

```bash
sudo udwall --enable
```

### Define your Rules

Edit the configuration file at `/etc/udwall/udwall.conf` (or `udwall.conf` in the current directory).

```python
# udwall.conf
rules = [
    # --- Host Rules ---
    # Always allow SSH (udwall protects this automatically, but good to be explicit)
    {'from': 'any', 'connectionType': 'tcp', 'to': '22', 'isDockerServed': False, 'isEnabled': True},
    # Nginx on Host
    {'from': 'any', 'connectionType': 'tcp', 'to': 80, 'isDockerServed': False, 'isEnabled': True},

    # --- Docker Rules ---
    # Container mapped to port 8080. 
    # 'isDockerServed': True handles the routing logic automatically.
    {'from': 'any', 'connectionType': 'tcp', 'to': 8080, 'isDockerServed': True, 'isEnabled': True},
    
    # Allow specific IP to access a database container
    {'from': '1.2.3.4', 'connectionType': 'tcp', 'to': 5432, 'isDockerServed': True, 'isEnabled': True},
]
```

### Apply the Configuration

This will backup your current state, remove undefined rules, and apply the new ones.

```bash
sudo udwall --apply
```

### Other Commands

| Command | Description |
| :--- | :--- |
| `sudo udwall --dry-run` | Shows what rules would be applied without making changes. |
| `sudo udwall --create` | Generates a `udwall.conf` at `/etc/udwall/udwall.conf` from your current live rules. |
| `sudo udwall --backup` | Creates a timestamped backup in `/home/ubuntu/backup/`. |
| `sudo udwall --status` | Shows the current UFW status. |
| `sudo udwall --disable` | Removes Docker rules, cleans files, and disables UFW. |

## 🛡️ Credits

The core `iptables` logic to fix the Docker/UFW security flaw is based on the work by [chaifeng/ufw-docker](https://github.com/chaifeng/ufw-docker). `udwall` extends this by adding declarative state management.

## 📄 License

[MIT](LICENSE)
