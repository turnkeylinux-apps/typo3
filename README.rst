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
   
   - TYPO3 is installed from the official TYPO3 Composer packages with a
     versioned dependency lock.

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

Check for a supported TYPO3 13.4 LTS update from the command line::

    typo3-update --check

Apply the update during a supervised maintenance window::

    typo3-update --apply

The updater backs up ``composer.json`` and ``composer.lock`` under
``/var/backups/typo3-updater`` before applying an update.

We recommend subscribing to the `TYPO3 security bulletin`_

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL: username **root**
-  Adminer: username **adminer**
-  TYPO3 CMS: username **admin**


.. _TYPO3 CMS: https://typo3.org/
.. _TYPO3 security bulletin: https://typo3.org/teams/security/
.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _Adminer: https://www.adminer.org/
