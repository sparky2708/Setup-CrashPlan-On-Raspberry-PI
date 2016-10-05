#!/bin/bash

#############
# n8henrie's Raspberry Pi CrashPlan installer script
# v0.1.0 :: 20160530
#############

set -e

CP_VERSION="4.7.0"

install_dependencies() {
  read -p "Install dependencies? (y/n): "
  case $REPLY in
    n|N) echo "Not installing dependencies." ;;
      *) sudo apt-get install build-essential make git oracle-java8-jdk libswt-gtk-3-java libswt-cairo-gtk-3-jni ;;
  esac
}

install_crashplan() {
  wget http://download.code42.com/installs/linux/install/CrashPlan/CrashPlan_${CP_VERSION}_Linux.tgz
  tar xzf CrashPlan_${CP_VERSION}_Linux.tgz

  pushd crashplan-install
  sudo ./install.sh
  popd
}

install_jtux() {
  # Built jtux from source
  git clone https://github.com/swenson/jtux.git
  pushd jtux

  # Update Makefile with path to current jdk path
  java_include="$(find /usr/lib/jvm -maxdepth 2 -type d -name include -print -quit)"
  sed -i.bak "s|JAVA_INCLUDE = .*$|JAVA_INCLUDE = ${java_include}|" Makefile
  make

  # Uncomment to verify the sha256 if desired
  # echo 'e2a8b0acae75c22aead0e89bbd2178126e295b0f01108ff7d95d162ba53884b7 libjtux.so' | sha256sum -c

  sudo mv /usr/local/crashplan/libjtux.so{,.bak}
  sudo cp {,/usr/local/crashplan/}libjtux.so
  popd
}

fix_ui_client() {
  #Fix SWT jar that the CrashPlan client needs
  sudo mv /usr/local/crashplan/lib/swt.jar{,.bak}
  sudo cp /usr/lib/java/swt-gtk-3.8.2.jar /usr/local/crashplan/lib/swt.jar
}

disable_upgrade() {
  #symlink the upgrade folder to dev null
  sudo mv /usr/local/crashplan/upgrade{,.bak}
  sudo ln -s /dev/null upgrade 
}

fix_java_path() {
  # Fix path to java -- symlinks to /etc/alternatives which links to jdk
  sudo sed -i.bak 's|JAVACOMMON=.*$|JAVACOMMON=/usr/bin/java|' /usr/local/crashplan/install.vars
}

stop_crashplan() {
  sudo systemctl stop crashplan.service || true
  sudo /usr/local/crashplan/bin/CrashPlanEngine stop || true
}

restart_crashplan() {
  # My example service file: https://gist.github.com/n8henrie/996bd2b9b309fe6011a3
  sudo systemctl restart crashplan || true
  sudo /usr/local/crashplan/bin/CrashPlanEngine status
}

remove_sysvinit() {
  stop_crashplan
  while read -p "Remove sysvinit script? (Recommended if you're going to try systemd service file) (y/n): " remove_sysvinit; do
    case "$remove_sysvinit" in
      y|Y) sudo update-rc.d -f crashplan remove; break ;;
      n|N) echo "Leaving sysvinit script"; break ;;
        *) echo "Invalid response" ;;
    esac
  done
}

install_systemd() {
  while read -p "Install n8henrie's systemd service file? " install_systemd; do
    case "$install_systemd" in
      y|Y)
          sudo wget https://gist.githubusercontent.com/n8henrie/996bd2b9b309fe6011a3/raw -O /etc/systemd/system/crashplan.service
          sudo systemctl enable crashplan.service
          break
          ;;
      n|N)
          echo "Not installing systemd service file"
          break
          ;;
        *)
          echo "Invalid response"
          ;;
    esac
  done
}

cleanup() {
  cleanme="CrashPlan_${CP_VERSION}_Linux.tgz crashplan-install/ jtux/"
  for each in $cleanme; do
    read -p "Remove $each? (y/n): " -r
    case $REPLY in
      y|Y) rm -rf $each ;;
      n|N) echo "Leaving $each" ;;
        *) echo "Invalid response, leaving $each"
    esac
    echo
  done
}

#######
# Begin main script
######

stop_crashplan
install_dependencies

crashplan_dest="/usr/local/crashplan"
if [ -d "$crashplan_dest" ]; then
  echo "It looks like $crashplan_dest already exists."
  echo "Would you like to:"
  echo "1: Try to update the existing installation"
  echo "2: Reinstall from scratch"
  read -p "Choice (1/2): " choice
  case "$choice" in
    1)
      echo "Updating existing install..."
      ;;
    2)
      echo "Installing from scratch..."
      install_crashplan
      ;;
    *)
      echo "Invalid response; exiting"
      exit 1
      ;;
  esac
else
  # $crashplan_dest didn't exist, assume full installation
  install_crashplan
fi

install_jtux
fix_java_path
install_systemd
remove_sysvinit
fix_ui_client
disable_upgrade
cleanup
restart_crashplan
