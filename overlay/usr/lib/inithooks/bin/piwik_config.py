#!/usr/bin/python
"""Update Piwik configuration settings

Arguments:
    section    section header (e.g., [database])
    name       parameter name (e.g., password)
    value      parameter value (e.g., s3cr3tp4ss)

"""

import os
import sys
import getopt

from executil import system

class Error(Exception):
    pass

def usage(e=None):
    if e:
        print >> sys.stderr, "Error:", e
    print >> sys.stderr, "Syntax: %s [options] section name value" % sys.argv[0]
    print >> sys.stderr, __doc__
    sys.exit(1)

def update(section, name, value):
    config_path = "/var/www/piwik/config/config.ini.php"
    if not os.path.exists(config_path):
        raise Error("config file does not exist: %s" % config_path)

    config_new = []
    in_section = False
    for line in file(config_path).readlines():
        line = line.rstrip()
        if line.startswith("["):
            if line == section:
                in_section = True
            else:
                in_section = False

        if in_section and line.startswith("%s =" % name):
            line = "%s = \"%s\"" % (name, value)

        config_new.append(line)

    # write out updated config
    file(config_path, "w").write("\n".join(config_new) + "\n")

    # set ownership and permissions
    system("chown www-data:www-data %s" % config_path)
    system("chmod 640 %s" % config_path)

def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h", ['help'])
    except getopt.GetoptError, e:
        usage(e)

    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()

    if not len(args) == 3:
        usage("incorrect amount of arguments")

    section, name, value = args
    update(section, name, value)


if __name__ == "__main__":
    main()

