Web App Mirror
==============

This repository builds a macOS app with an embedded web view that hosts a configurable web 
application. The macOS app contains a local caching proxy that can be used to mirror the web 
application to local files while using it.

Proxy configuration as well as JavaScript and CSS injection are configurable at compile time 
in the file [`Config.swift`](/Sources/WebAppMirror/Config.swift).

___
This work is licensed under the [WTFPL](http://www.wtfpl.net/), so you can do anything you 
want with it.
