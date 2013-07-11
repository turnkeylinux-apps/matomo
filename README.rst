Piwik - Real Time Web Analytics
===============================

`Piwik`_ is a free software alternative to Google Analytics that is
already used on more than 320,000 websites. It provides you with
detailed reports on your website visitors; the search engines and
keywords they used, the language they speak, your popular pages, and
much more.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- Piwik configurations:
   
   - Installed from upstream source code to /var/www/piwik

- SSL support out of the box.
- `PHPMyAdmin`_ administration frontend for MySQL (listening on port
  12322 - uses SSL).
- Postfix MTA (bound to localhost) to allow sending of email (e.g.,
  password recovery).
- Webmin modules for configuring Apache2, PHP, MySQL and Postfix.

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL, phpMyAdmin: username **root**
-  Piwik: username **admin**


.. _Piwik: http://piwik.org/
.. _TurnKey Core: http://www.turnkeylinux.org/core
.. _PHPMyAdmin: http://www.phpmyadmin.net
