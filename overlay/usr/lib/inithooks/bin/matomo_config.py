#!/usr/bin/python3
"""Update Matomo configuration settings

Arguments:
    section    section header (e.g., [database])
    name       parameter name (e.g., password)
    value      parameter value (e.g., s3cr3tp4ss)

"""

import os
import sys
import getopt
import subprocess

class Error(Exception):
    pass

def usage(e=None):
    if e:
        print("Error:", e, file=sys.stderr)
    print(f"Syntax: {sys.argv[0]} [options] section name value", file=sys.stderr)
    print(__doc__, file=sys.stderr)
    sys.exit(1)

def update(section, name, value):
    config_path = "/var/www/matomo/config/config.ini.php"
    if not os.path.exists(config_path):
        raise Error(f"config file does not exist: {config_path}")

    config_new = []
    in_section = False
    seen = False
    with open(config_path, 'r') as fob:
        for line in fob:
            line = line.rstrip()
            if line.startswith("["):
                if line == section:
                    in_section = True
                else:
                    in_section = False

            if in_section and line.startswith(f"{name} =") and seen == False:
                # first 'trusted_hosts' entry is localhost and should remain
                if name != "trusted_hosts[]" and '127.0.0.1' in line:
                    line = f'{name} = "{value}"'
                    seen = True

            config_new.append(line)

    # write out updated config
    with open(config_path, 'w') as fob:
        fob.write("\n".join(config_new) + "\n")

    # set ownership and permissions
    subprocess.run(["chown", "www-data:www-data", config_path])
    subprocess.run(["chmod", "640", config_path])

def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h", ['help'])
    except getopt.GetoptError as e:
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
