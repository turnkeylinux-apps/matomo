#!/usr/bin/python
"""Set Piwik admin password, email and domain

Option:
    --pass=     unless provided, will ask interactively
    --email=    unless provided, will ask interactively
    --domain=   unless provided, will ask interactively
                DEFAULT=www.example.com

"""

import sys
import getopt
import inithooks_cache

import hashlib
import bcrypt

import matomo_config
from dialog_wrapper import Dialog
from mysqlconf import MySQL

def usage(s=None):
    if s:
        print >> sys.stderr, "Error:", s
    print >> sys.stderr, "Syntax: %s [options]" % sys.argv[0]
    print >> sys.stderr, __doc__
    sys.exit(1)

DEFAULT_DOMAIN="www.example.com"

def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'pass=', 'email=', 'domain='])
    except getopt.GetoptError, e:
        usage(e)

    password = ""
    email = ""
    domain = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--pass':
            password = val
        elif opt == '--email':
            email = val
        elif opt == '--domain':
            domain = val

    if not password:
        d = Dialog('TurnKey Linux - First boot configuration')
        password = d.get_password(
            "Piwik Password",
            "Enter new password for the Piwik 'admin' account.")

    if not email:
        if 'd' not in locals():
            d = Dialog('TurnKey Linux - First boot configuration')

        email = d.get_email(
            "Piwik Email",
            "Enter email address for Piwik 'admin' account.",
            "admin@example.com")

    inithooks_cache.write('APP_EMAIL', email)

    if not domain:
        if 'd' not in locals():
            d = Dialog('TurnKey Linux - First boot configuration')

        domain = d.get_input(
            "Piwik Domain",
            "Enter the domain to serve Piwik.",
            DEFAULT_DOMAIN)

    if domain == "DEFAULT":
        domain = DEFAULT_DOMAIN

    inithooks_cache.write('APP_DOMAIN', domain)

    domain = domain.strip("/")
    if not domain.startswith("http://"):
        domain = "http://%s/" % domain

    m = MySQL()
    m.execute('UPDATE matomo.matomo_option SET option_value=\"%s\" WHERE option_name=\"matomoUrl\";' % domain)
    matomo_config.update("[General]", "trusted_hosts[]", domain)

    hash = bcrypt.hashpw(hashlib.md5(password).hexdigest(), bcrypt.gensalt())

    m.execute('UPDATE matomo.matomo_user SET password=\"%s\" WHERE login = \"admin\" AND superuser_access = 1;' % hash)
    m.execute('UPDATE matomo.matomo_user SET email=\"%s\" WHERE login = \"admin\" AND superuser_access = 1;' % email)

if __name__ == "__main__":
    main()

