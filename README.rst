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
   
   - Installed from official Matomo debian package archive (to 
     /usr/share/matomo)

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

To upgrade to the latest version of Matomo from the command line::

    apt-get update
    apt-get install matomo

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

