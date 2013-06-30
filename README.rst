Typo3 - Enterprise CMS
======================

`Typo3`_ is an enterprise-class, Open Source CMS (Content Management
System) with a vast international community of developers and
supporters. It's used to build and manage websites of all types, from
small sites for non-profits to multilingual enterprise solutions for
large corporations.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- Typo3 configurations:
   
   - Installed from upstream source code to /var/www/typo3

- SSL support out of the box.
- `PHPMyAdmin`_ administration frontend for MySQL (listening on port
  12322 - uses SSL).
- Postfix MTA (bound to localhost) to allow sending of email (e.g.,
  password recovery).
- Webmin modules for configuring Apache2, PHP, MySQL and Postfix.

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL, phpMyAdmin: username **root**
-  Typo3: username **admin**


.. _Typo3: http://typo3.org/
.. _TurnKey Core: http://www.turnkeylinux.org/core
.. _PHPMyAdmin: http://www.phpmyadmin.net
