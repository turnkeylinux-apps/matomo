Matomo - Self Hosted Real-Time Web Analytics
============================================

`Matomo`_ (formerly Piwik) is the leading free software alternative to
Google Analytics, used on more than 320,000 websites. Matomo lets you
easily collect and visualize data from websites, apps & the Internet of
Things. It can generate detailed reports of your website visitors, the
search engines and keywords they used, the language they speak, your
popular pages, and much more. Privacy is built-in.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- Matomo configurations:

   - Matomo 5.13.0 is installed from the official upstream release archive
     to ``/var/www/matomo``. The archive SHA-256 published in the upstream
     GitHub release metadata is verified during the build.

     **Security note**: Updates to Matomo may require supervision
     so they **ARE NOT** configured to install automatically. See
     below for updating Matomo.

- SSL support out of the box.
- `Adminer`_ administration frontend for MySQL (listening on port
  12322 - uses SSL).
- Postfix MTA (bound to localhost) to allow sending of email (e.g.,
  password recovery).
- Webmin modules for configuring Apache2, PHP, MySQL and Postfix.

Supervised Manual Matomo Update
-------------------------------

Back up Matomo and its database, then follow the upstream `manual update
guide`_.
Download the next official release archive and verify its published digest
before replacing the application files. Preserve ``config/config.ini.php``,
then apply any database changes from the Matomo directory::

    sudo -u www-data php console core:update --yes

We recommend subscribing to the `Matomo changelog`_ to be notified 
about new versions and security updates. 

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL: username **root**
-  Adminer: username **adminer**
-  Matomo: username **admin**

.. _Matomo: https://matomo.org/
.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _Adminer: https://www.adminer.org/
.. _Matomo changelog: https://matomo.org/changelog/
.. _manual update guide: https://matomo.org/docs/update/
