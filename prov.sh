#!/bin/sh
#
# PE Bootstrapper for Enterprise Linux Hosts (RHEL,  CENTOS,  OEL,  Scientific)
#
# This script is meant to be run on first boot of newly provisioned machines. It will install
# PE from a network location,  clean up after itself,  and do a first run. This boot-strapper
# assumes you have the PE install tarball and an answers file somewhere on your network. This 
# script will try to automatically download the version appropriate for your architecture and
# EL version. To keep from from having the update this script,  we rely o symbolic links to
# direct this bootstrapper to the the current appropriate PE version for your environment.
#
# --------------
#
# Set up this script to access remote data:
#
# $SRC_SERVER:
#   * This variable should be changed to point at the machine and port hosting the files.
#
# $PUPPET_PATH:
#   * Path on the remote server to access the answers file and the install tarballs.
# 
# --------------
#
# Set Up Remote Location:
#
# Install Tarball - The remote location should have the installer tarballs for the version
# of Puppet Enterprise you wish to have deployed to your agents. We will then abstract the
# version number using symbolic links so that this script does not need modification if baked 
# directly into your hosts. For example,  you wish to install PE 2.5.2 on an EL5 host that
# is x86_64,  and you wish to install PE 2.5.2 on an EL6 host that is i386,  you would create
# the following sym links in the directory:
#
#  Sym Link                    Original File  
#  puppet-el-5-x86_64.tar.gz -> puppet-enterprise-2.5.2-el-5-x86_64.tar.gz
#  puppet-el-6-i386.tar.gz   -> puppet-enterprise-2.5.2-el-6-i386.tar.gz
#
# If you were to upgrade to the EL5 host to PE 2.5.3,  you would change the sym link to 
# reflect the change:
#
#  Sym Link                    Original File  
#  puppet-el-5-x86_64.tar.gz -> puppet-enterprise-2.5.3-el-5-x86_64.tar.gz
#
# Answer File - The other remote resource this bootstrapper relies on is an answer file
# on the remote host. This answer file has all the necessary answers for a PE agent install
# as of PE 2.5.2,  but may require updating over time as new versions come out. This answers
# file uses two sub-shells,  once to determine the agent certificate name,  and one to determine 
# which puppet master to connect to (development vs production). This answer file is generic
# for all architectures and types of installers for a particular version of PE. To change
# the behavior of the answer file,  you can start be easily modifying the sub-shell commands 
# for the answers currently using it:
#   * q_puppetagent_certname
#   * q_puppetagent_server
#
# This script is expecting the answer file to be named on the remote host as:
#   * answers.Linux
#
# For more information on editing the answer file and using sub-shells,  please visit:
#   * http://docs.puppetlabs.com/pe/2.5/install_automated.html#editing-answer-files
# --------------
#
# Copyright (C) 2012 Puppetlabs - All Rights Reserved
# Permission to copy and modify is granted under the BSD license
# Last revised 8/17/2012
# Author: Tom Linkin <tom@puppetlabs.com>
 
SRC_SERVER="localhost"
PUPPET_PATH="/puppet"
 
# Check if puppet is already installed,  if so,  quit with success (you know,  cause we have puppet,  and that was the goal,  right?)
puppet -V >/dev/null 2>&1
  if [[ $? -lt 1 ]]; then
    exit 0
  fi
	 
  # Set our Architecture and EL version to download the correct package
  ARCH=`uname -m`
  if [[ "${ARCH}" != "x86_64" ]]; then
    ARCH='i386'
  fi
 
  EL=`cat /etc/issue | grep  -Po '(?<=release )\d'`
	if [[ $? -gt 0 ]]; then
    exit 1
  fi
		 
# Retrieve Packages
cd /tmp
  wget -q -O /tmp/puppet.tgz "http://${SRC_SERVER}${PUPPET_PATH}/puppet-el-${EL}-${ARCH}.tar.gz"
  wget -q -O /tmp/answers.Linux "http://${SRC_SERVER}${PUPPET_PATH}/answers.Linux"
 
# Extract 
tar -zxvf /tmp/puppet.tgz -C /tmp
 
# Enter PE directory and run install with answer file
cd /tmp/puppet-enterprise*
./puppet-enterprise-installer -a /tmp/answers.Linux
  
	# Remove puppet install directory and do first run if we are successful 
if [[ $? -lt 1 ]]; then
  cd ../
  rm -rf /tmp/puppet-enterprise*
  rm -rf /tmp/puppet.tgz
				  
	# Lets do a run with our new puppet install (might you be auto-signing?)
  puppet agent -t
fi
					 
# Sample Answers For agent install - at the time of writing this,  here is what the
# we currently are using for the answers.Linux file.
#
#q_fail_on_unsuccessful_master_lookup=n
#q_install=y
#q_puppet_cloud_install=n
#q_puppet_enterpriseconsole_install=n
#q_puppet_symlinks_install=y
#q_puppetagent_certname=$(hostname -f)
#q_puppetagent_install=y
#q_puppetagent_server=$(if [[ -n `hostname | grep my-uniq-host` ]]; then echo puppet-dev; else echo puppet; fi)
#q_puppetca_install=n
#q_puppetmaster_install=n
#q_vendor_packages_install=y
