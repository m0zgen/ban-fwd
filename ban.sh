#!/bin/bash
# Author: Yevgeniy Goncharov aka xck, http://sys-adm.in
# Script for ban IPs with ipset & Firewalld

# Sys env / paths / etc
# -------------------------------------------------------------------------------------------\
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

FLAG=$1
BLOCK=$2
exclude="kz de nl fr us"
block_countries="in ar bg br by cn il in ir kp ly mn mu pa sd tw ua ro ru ve vn"

cd .

function usage
{
  cat << EOF

Usage: $0 options
OPTIONS:
   --block-all --countries       Block countries - ${block_countries}
   --block-all --excludes        Block all countries, exclude - ${exclude}
   --block-manual                Block subnet
   --delete-ipset            Delete blasklist
   --help                        Show this help
Example:
$0 --block-all
$0 --block-manual 192.168.1.0/24
$0 --delete-ipset
$0 --help

EOF
}

function delete_ipset
{
  echo "Reset ipset"
  firewall-cmd --permanent --delete-ipset=blacklist
  firewall-cmd --permanent --zone=drop --remove-source=ipset:blacklist
  firewall-cmd --reload
}

function create_ipset
{
  # Create ipset
  echo "Create ipset"
  firewall-cmd --permanent --new-ipset=blacklist --type=hash:net --option=family=inet --option=hashsize=4096 --option=maxelem=200000
}

function drop_and_reload_fwd
{
  # Add to drop zone
  echo "Add to drop zone"
  firewall-cmd --permanent --zone=drop --add-source=ipset:blacklist
  firewall-cmd --reload
}

function fwd
{

  echo "Add zone $1 to blacklist"
  firewall-cmd --permanent --ipset=blacklist --add-entries-from-file=$1
}

function block_all
{
  # Create zones folder
  echo "Create zones folder"
  if [[ ! -d "zones" ]]; then
    mkdir zones
  else
    rm -f zones/*
  fi

  # Download CIDRs
  echo "Download CIDRs..."
  wget --quiet -P zones http://www.ipdeny.com/ipblocks/data/countries/all-zones.tar.gz
  tar -zxf zones/all-zones.tar.gz -C zones > /dev/null 2>&1

  delete_ipset
  create_ipset

  echo "Block is $BLOCK"

  if [ "$BLOCK" == "--excludes" ]; then
    # Delete excludes
    echo "Delete excludes"
    for i in $exclude; do
      echo "Delete excludes - zones/$i.zone"
      rm -f zones/$i.zone
    done

    all_zones=$(ls zones/*.zone)
    for i in $all_zones; do
      fwd ./$i
    done

  elif [ "$BLOCK" == "--countries" ]; then
    for i in $block_countries; do
      if [[ -f zones/$i.zone ]]; then
        fwd ./zones/$i.zone
      fi
    done
    elif [ "$BLOCK" == "" ]; then
    echo "Please set excludes or blocking countries!"
    echo "Please use --help argument"
    exit 1
  fi

  drop_and_reload_fwd
  # firewall-cmd --ipset=blacklist --get-entries

}

function add_manually
{
  # Add entry manually, as example 192.168.1.0/24
  if [[ ! -z $1 ]]; then
    echo "Please set IP subnet!"
    exit 1
  fi
  firewall-cmd --permanent --ipset=blacklist --add-entry=$1
  firewall-cmd --ipset=blacklist --add-entry=$1

}


if [ "$FLAG" == "--block-all" ]; then
    block_all
elif [ "$FLAG" == "--block-manual" ]; then
  add_manually $1
elif [ "$FLAG" == "--delete-ipset" ]; then
  delete_ipset
elif [ "$FLAG" == "--help" ]; then
  usage
else
  usage
fi
