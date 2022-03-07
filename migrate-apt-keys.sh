#!/bin/bash

# DESCRIPTION
#   Migrate from "apt-key" managed keys to "[signed-by=/usr/share/keyrings/...]":
#   - loop through all lists in /etc/apt/sources.list.d
#     - read all lines with "deb..." that do not contain "[signed-by=]"
#     - download the GPG signature from the URL
#       - read the key ID from the signature
#       - download and saves the key using gpg
#     - add "[signed-by=/usr/share/keyrings/...]" to the "deb..." line
#   - make a backup of the old .list file as .list.apt-key
#
# REQUIREMENTS
#   bash, perl, curl, gpg
#
# CAVEATS
#   This does not work e.g. for Anydesk as the Ubuntu keyserver stores an old key.
#   You can manually download the ASCII armored key like this:
#     curl https://keys.anydesk.com/repos/DEB-GPG-KEY | gpg --dearmor > /usr/share/keyrings/anydesk-stable-archive-keyring.gpg
#   See: https://lists.ubuntu.com/archives/ubuntu-users/2022-January/306500.html

set -e

for repo in /etc/apt/sources.list.d/*.list; do
  sig_base=$(basename $repo | sed 's/\.list//')
  sig_file="/usr/share/keyrings/${sig_base}-archive-keyring.gpg"
  skip_repo=0
  new_repo=$(mktemp)

  migrated=0
  while read line; do
    # skip if no repo definition
    if grep -E -q -v '^deb(-src)?' <<<"$line"; then echo "$line" >> $new_repo; continue; fi
    # skip if already "signed-by"
    if grep -E -q 'signed-by' <<<"$line"; then echo "$line" >> $new_repo; continue; fi

    echo "$sig_base: >> $line"

    if [ -f $sig_file ]; then
      echo "$sig_base: key already exists - skipping download"
    else
      # assemble URL
      url=$(echo "$line" | perl -pe 's{^ (?:(?:deb|deb-src) \s+) (?: \[[^\]]+] \s+)? (\S+?)/? \s+ (\S+) \s+ .* }{ $suite=$2; "$1/".($suite=~m|/$|?$suite:"dists/$2/") }xe')
      echo "$sig_base: downloading $url"

      # download signature
      set +e
      sigfile=$(curl -s -f -L "${url}InRelease")
      if [ $? -ne 0 ]; then
        sigfile=$(curl -s -f -L "${url}Release.gpg")
        if [ $? -ne 0 ]; then echo "$sig_base: URL ${url}[InRelease|Release.gpg] not found"; exit 1; fi
      fi
      set -e

      # read key ID from signature
      keyid=$(echo "$sigfile" | gpg --verify -vv 2>&1 | tr '\n' ' ' | sed -E 's/.*signature.*keyid ([0-9A-Z]+).*/\1/i')
      if [ -z "$keyid" ]; then echo "$sig_base: Could not find key id in signature"; exit 1; fi
      echo "$sig_base: key id = $keyid"

      # download key
      temp_sig=$(mktemp)
      gpg --quiet --no-default-keyring --keyring $temp_sig --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys $keyid
      expiry=$(gpg --no-default-keyring --keyring=$temp_sig --list-keys --with-colons --fixed-list-mode | grep pub | cut -d: -f7)
      if [[ ! -z "$expiry" && $expiry < $(date +"%s") ]]; then
        expiry_date=$(date -d "1970-01-01 UTC $expiry seconds" +"%Y-%m-%d %T %z")
        echo "$sig_base: SKIPPING migration - key expired on $expiry_date"
        skip_repo=1; break
      fi
      mv $temp_sig $sig_file
      chmod 0644 $sig_file
    fi

    echo "$line" \
     | SIG=$sig_file perl -pe 's{^ ((?:deb|deb-src) \s+) (?: \[ ([^\]]+) ] \s+ )? (.*) }{$1\[$2 signed-by=$ENV{SIG}\] $3}x' \
     >> $new_repo

    migrated=1
  done < <(cat "$repo")

  if [[ $skip_repo == 0 && $migrated == 1 ]]; then
    cp $repo $repo.apt-key
    # preserve permissions
    cat $new_repo > $repo
    echo "$sig_base: migration done"
  fi

  rm $new_repo
done
