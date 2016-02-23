TYPO3 CMS - Enterprise CMS
==========================

`TYPO3 CMS`_ is an enterprise-class, Open Source CMS (Content Management
System) with a vast international community of developers and
supporters. It's used to build and manage websites of all types, from
small sites for non-profits to multilingual enterprise solutions for
large corporations.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- TYPO3 CMS configurations:
   
   - TYPO3 is installed from the `package repository`_ managed directly
     by the TYPO3 project.

     **Security note**: Updates to TYPO3 may require supervision so
     they **ARE NOT** configured to install automatically. See below for
     updating TYPO3.

- SSL support out of the box.
- `Adminer`_ administration frontend for MySQL (listening on port
  12322 - uses SSL).
- Postfix MTA (bound to localhost) to allow sending of email (e.g.,
  password recovery).
- Webmin modules for configuring Apache2, PHP, MySQL and Postfix.

Supervised Manual TYPO3 Update
------------------------------

To upgrade to the latest version of TYPO3 from the command line::

    cd /var/www/typo3
    composer update typo3/cms

We recommend subscribing to the `TYPO3 security bulletin`_

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL, Adminer: username **root**
-  TYPO3 CMS: username **admin**


.. _TYPO3 CMS: http://typo3.org/
.. _package repository: http://composer.typo3.org/
.. _TYPO3 security bulletin: https://typo3.org/teams/security/
.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _Adminer: http://www.adminer.net
