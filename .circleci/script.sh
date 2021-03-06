#!/usr/bin/env bash
###########################################################################
#    homebrew-osgeo4mac circle ci - script.sh
#    ---------------------
#    Date                 : Dec 2019
#    Copyright            : (C) 2016 by Boundless Spatial, Inc.
#    Author               : Larry Shaffer - FJ Perini
#    Email                : lshaffer at boundlessgeo dot com
###########################################################################
#                                                                         #
#   This program is free software; you can redistribute it and/or modify  #
#   it under the terms of the GNU General Public License as published by  #
#   the Free Software Foundation; either version 2 of the License, or     #
#   (at your option) any later version.                                   #
#                                                                         #
###########################################################################

set -e

ulimit -n 1024

echo ${CHANGED_FORMULAE}

for f in ${CHANGED_FORMULAE};do
  deps=$(brew deps --include-build ${f})

  # fix error: Unable to import PyQt5.QtCore
  # build qscintilla2
  if [ "$(echo ${deps} | grep -c 'osgeo-pyqt')" != "0" ];then
    brew reinstall ${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/osgeo-pyqt
    brew unlink osgeo-pyqt && brew link osgeo-pyqt --force
    /usr/local/bin/pip2 install enum34
    /usr/local/bin/python2 -c "import PyQt5.QtCore"
    /usr/local/bin/python3 -c "import PyQt5.QtCore"
  fi

  # fix error: 'libintl.h' file not found
  # build qgis with grass
  if [ "$(echo ${deps} | grep -c 'osgeo-grass')" != "0" ] || [ "${f}" == "osgeo-grass" ];then
    brew reinstall gettext
    brew unlink gettext && brew link --force gettext
  fi

  if [ "${f}" == "osgeo-grass" ];then
    brew unlink osgeo-liblas && brew link osgeo-liblas --force
  fi

  # Error: The `brew link` step did not complete successfully
  # The formula built, but is not symlinked into /usr/local
  # Could not symlink lib/pkgconfig/libopenjp2.pc
  # Target /usr/local/lib/pkgconfig/libopenjp2.pc
  # is a symlink belonging to openjpeg
  if [ "$(echo ${deps} | grep -c 'osgeo-insighttoolkit')" != "0" ] || [ "${f}" == "osgeo-insighttoolkit" ];then
    brew unlink openjpeg
  fi

  # fix test
  # initdb: could not create directory "/usr/local/var/postgresql": Operation not permitted
  if [ "${f}" == "osgeo-libpqxx" ];then
    initdb /usr/local/var/postgresql -E utf8 --locale=en_US.UTF-8
    # pg_ctl -D /usr/local/var/postgresql -l logfile start
    brew services start osgeo/osgeo4mac/osgeo-postgresql
    # system "psql", "-h", "localhost", "-d", "postgres"
    # createdb template1
  fi

  # if [[ $(brew list --versions ${f}) ]]; then
  #   echo "Clearing previously installed/cached formula ${f}..."
  #   brew uninstall --force --ignore-dependencies ${f} || true
  # fi

  echo "Installing changed formula ${f}..."
  # Default installation flag set
  FLAGS="--build-bottle"

  brew install -v ${FLAGS} ${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/${f}&
  PID=$!
  # add progress to ensure Travis doesn't complain about no output
  while true; do
    sleep 30
    if jobs -rp | grep ${PID} >/dev/null; then
      echo "."
    else
      echo
      break
    fi
  done

  echo "Testing changed formula ${f}..."
  # does running postinstall mess up the bottle?
  # (mentioned that it is skipped if installing with --build-bottle)
  # brew postinstall ${f}
  brew test ${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/${f}
done
