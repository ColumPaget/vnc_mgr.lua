SYNOPSIS
========

vnc_mgr.lua is a menu-driven application that stores vnc connection info and wraps vnc connections allowing vnc clients to connect through ssh, TLS/SSL and socks5 tunnels/proxies. It uses libUseful-lua and one of either zenity, qarma or yad for the dialogs.


REQUIREMENTS
============

vnc_mgr.lua requires libUseful more recent than v4.77 and libUseful-lua more recent than v2.27. It also requires one of zenity, qarma or yad to handle interactive dialogs.


FEATURES
========

SSH connections must be pre-configured in `~/.ssh/config` as vnc_mgr.lua does not currently handle usernames, passwords or certificate files for SSH.

TLS/SSL connections involve wrapping the VNC connection in an external TLS tunnel, this is not 'VNCTls' which is a VNC-specific form of encryption that happens within the VNC protocol. This form of tunnel can be configured to use an X509 certificate for authentication.

SOCKS5 connections are made via a socks5 proxy server, with username/password support. Socks5 authentication is sent in cleartext, so care should be taken using this authentication system, however it is useful for tunnels that present a local socks5 interface, e.g. Tor.

SOCKS5+TLS is a connection type that first talks to a socks proxy in clear text, and then expects the resulting forwarded connection through the socks proxy to be encrypted with TLS.


VIEWERS SUPPORT
===============

vnc_mgr.lua searches in the users PATH for vnc-viewer programs it can use. For some of these it can offer options like automatic login with stored password, view only, single-viewer (not shared) mode and fullscreen. It can identify viewers that run under wine or java, and launch them using those frameworks if wine/java can be found in the user's PATH.

In order to identify a viewer and enable features like autologin and view only mode, the executable file must be named in a manner that indicates which viewer program it is. Most viewers are simply named 'vncviewer' which vnc_mgr.lua treats as the lowest level of of viewer with no features. Accepted viewer program names are:

```
vncviewer                basic viewer with no features
vncviewer.exe            basic viewer with no features
vncviewer.jar            basic viewer with no features
turbovncviewer.exe       basic viewer with no features
ultravnc.exe             autologin (stored password) supported
ultravnc                 autologin (stored password) supported
ultravncviewer.exe       autologin (stored password) supported
tightvnc                 noshare, fullscreen, viewonly and autologin (stored password) supported
tightvncviewer           noshare, fullscreen, viewonly and autologin (stored password) supported
xtightvncviewer          noshare, fullscreen, viewonly and autologin (stored password) supported
tightvnc.exe             noshare, fullscreen, viewonly and autologin (stored password) supported
tightvncviewer.exe       noshare, fullscreen, viewonly and autologin (stored password) supported
tightvnc-jviewer.jar     autologin (stored password) supported
tigervnc                 noshare, fullscreen, viewonly and autologin (stored password) supported
tigervncviewer           noshare, fullscreen, viewonly and autologin (stored password) supported
xtigervncviewer          noshare, fullscreen, viewonly and autologin (stored password) supported
VNC-Viewer*              (real vnc) noshare and fullscreen supported.
```


