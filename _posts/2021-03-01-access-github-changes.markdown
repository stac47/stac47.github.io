---
layout: post
title:  "Accessing Github After Deprecation of Password Authentication"
date:   Mon 01 Mar 2021 09:13:13 AM UTC
categories: vim
---

On December 2020, Github [announced][github_announce]:
> Beginning August 13, 2021, we will no longer accept account passwords when
> authenticating Git operations on GitHub.com

As a consequence,
> For developers, if you are using a password to authenticate Git operations
> with GitHub.com today, you must begin using a personal access token over HTTPS
> (recommended) or SSH key by August 13, 2021, to avoid disruption.

In this post, I will sum up the different changes in configuration and
workflows that this change implied depending on the working environment

## Personal Environment

Simply register your personal SSH public key via __Settings/SSH and GPG keys__.

Then clone the repository with the SSH URL like 
```
> git clone git@github.com:stac47/stac47.github.io.git
```

For the repositories already cloned, you can change the remote URL:
```
> get remote set-url origin git@github.com:stac47/stac47.github.io.git
```

If you don't want to do this last operation on all your local repositories, you
can set git so that it will force the SSH usage.
```
> git config --global url."git@github.com:".insteadOf "https://github.com/"
```

## Working Environment

In a constrained environment like a company, you can face the following issues:
- the firewall rules does not allow outgoing traffic through port 22: in this
  case, you can SSH over HTTPS port (443)
- some machines can be isolated from the internet network: in that case, you
  can create SSH tunnel to github.com

### SSH over the HTTPS Port

This section assumes the machine your logged in has HTTPS access to
[https://github.com][github_site], but the firewall rules prevent your from
accessing port 22.

The trick is to configure the SSH client so that it will use port 443 instead
of the default one (22) for a given URL. So for _github.com_, you can edit
`~/.ssh/config` (create it if need be) and write in it:
```
Host github.com
  Hostname ssh.github.com
  Port 443
```
Official help: [Help][github_ssh_over_https_port]

### SSH Tunneling

Provided that the machine _isolated.mycompany.com_ is on a network which
cannot access internet, and a machine _connected.mycompany.com_ that can
connect Github site through HTTPS port, you can run a tunnel isolated to
[github.com][github_site] through the connected machine. (I used the
entry port 8022 because I am not root on that machine neither)

On the machine _isolated.mycompany.com_, first create the tunnel:
```
> ssh -fN -L 8022:ssh.github.com:443 me@connected.mycompany.com
```

As in the previous section, configure the SSH client to change the Github
endpoint to automatically use the tunnel:
```
Host github.com
  Hostname localhost
  Port 8022
```

Note that the tips to change the repository URL described in section
__Personal Environment__ also apply.

## Conclusion

The help pages of Github are very well done. In case, you need to trouble shoot
your connectivity, you can follow the [troubleshooting
guide][github_troubleshooting].

[github_site]: https://github.com
[github_announce]: https://github.blog/2020-12-15-token-authentication-requirements-for-git-operations/
[github_troubleshooting]: https://docs.github.com/en/github/authenticating-to-github/troubleshooting-ssh
[github_ssh_over_https_port]: https://docs.github.com/en/github/authenticating-to-github/troubleshooting-ssh
