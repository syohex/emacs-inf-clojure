Inferior Clojure Mode
====================

clojure process in a buffer.
inf-clojure is inspired cmuscheme.el and based on it.

Install
=======
Download **inf-clojure.el** and put it directory which passed load-path.
And add following S-exp in your configuration file(eg .emacs etc)

    (require 'inf-clojure)

How to Use
==========

    M-x run-clojure


KeyBindings
============
Key bindings of inf-clojure is similar to other inferior modes.

| Key binding | Command                          |
|:-----------:|:---------------------------------|
|  C-x C-e    |  clojure-send-last-sexp          |
|  C-c d      |  clojure-document                |
|  C-c C-d    |  clojure-find-document           |
|  C-c C-e    |  clojure-send-definition         |
|  C-c C-c    |  clojure-send-definition         |
|  C-c M-e    |  clojure-send-definition-and-go  |
|  C-c C-r    |  clojure-send-region             |
|  C-c M-r    |  clojure-send-region-and-go      |
|  C-c C-x    |  clojure-expand-current-form     |
|  C-c C-z    |  switch-to-clojure               |
|  C-c C-l    |  clojure-load-file               |
