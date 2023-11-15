---
title:  "Ruby Tips and Tricks"
layout: post
tags: ruby
---

# {{ page.title }}

## Rapidly Compute the CIDR Range

Use `IPAddr#to_range`:

```
irb(main):001> require "ipaddr"
=> true
irb(main):002> IPAddr.new("192.168.128.0/19").to_range
=> #<IPAddr: IPv4:192.168.128.0/255.255.255.255>..#<IPAddr: IPv4:192.168.159.255/255.255.255.255>
```

To check whether an IP address belongs to the range:

```
irb(main):003> IPAddr.new("10.101.64.0/18") === "127.0.0.2"
=> false
```
