SYNOPSIS
========

vnc_mgr.lua stores vnc connection info and wraps vnc connections allowing vnc clients to connect through ssh, TLS/SSL and socks5 tunnels/proxies. It uses libUseful-lua and one of either zenity, qarma or yad for the dialogs.

SSH connections must be pre-configured in `~/.ssh/config` ask vnc_mgr.lua does not currently handle usernames, passwords or certificate files for SSH.

TLS/SSL connections involve wrapping the VNC connection in an external TLS tunnel, this is not 'VNCTls' which is a VNC-specific form of encryption that happens within the VNC protocol. This form of tunnel can be configured to use an X509 certificate for authentication.

SOCKS5 connections are made via a socks5 proxy server, with username/password support. Socks5 authentication is sent in cleartext, so care should be taken using this authentication system, however it is useful for tunnels that present a local socks5 interface, e.g. Tor.


