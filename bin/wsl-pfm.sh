#!/bin/bash

DIR_WSL_PFM="/mnt/c/etc/wsl-pfm"

mode=""
arg_name=""
con_port=""
lis_port=""

error_exit() {
  echo "Error: $1" 1>&2
  exit "$2"
}

invalid_argument() {
  error_exit "Invalid argument: $1" 255
}

arg_name="con"
for arg; do
  if [[ -z $mode && ($arg == "add" || $arg == "delete" || $arg == "show") ]]; then
    mode=$arg
  else
    if [[ $arg == "from" || $arg == "-lis" || $arg == "--listen" ]]; then
      arg_name="lis"
    elif [[ $arg == "to" || $arg == "-con" || $arg == "--connect" ]]; then
      arg_name="con"
    else
      if [[ $arg_name == "lis" ]]; then
        if [[ -n $lis_port ]]; then
          invalid_argument "Listen port is already set"
        fi
        if [[ $arg =~ [0-9]+ ]]; then
          lis_port=$arg
        else
          invalid_argument "Invalid Listen port: $arg"
        fi
      elif [[ $arg_name == "con" ]]; then
        if [[ -n $con_port ]]; then
          invalid_argument  "Connect port is already set"
        fi
        if [[ $arg =~ [0-9]+ ]]; then
          con_port=$arg
        else
          invalid_argument "Invalid Connect port: $arg"
        fi
      else
        invalid_argument "$arg"
      fi
      arg_name=""
    fi
  fi
done

if [[ -z $mode ]]; then
  mode="add"
fi
if [[ ! ($mode == "add" || $mode == "delete" || $mode == "show") ]]; then
  invalid_argument "Invalid Mode: $mode"
fi

DISTRO="$WSL_DISTRO_NAME"
DIR_HOST="$DIR_WSL_PFM/host"
DIR_HOST_PORTS="$DIR_HOST/ports"
DIR_DISTRO="$DIR_WSL_PFM/distro/$DISTRO"
DIR_DISTRO_PORTS="$DIR_DISTRO/ports"

mkdir -p "$DIR_WSL_PFM"
mkdir -p "$DIR_HOST"
mkdir -p "$DIR_HOST_PORTS"
mkdir -p "$DIR_DISTRO"
mkdir -p "$DIR_DISTRO_PORTS"


delete_port() {
  # At least one of _lis_port or _con_port is required.
  _lis_port=$1 # Listen port
  _con_port=$2 # Connect port
  if [[ -z $_con_port ]]; then
    delete_distro_port "$_lis_port" "$_con_port"
  else
    delete_host_port "$_lis_port" "$_con_port"
  fi
  return $?
}

delete_distro_port() {
  _lis_port=$1 # Listen port, optional
  _con_port=$2 # Connect port, required
  if [[ -e "$DIR_DISTRO_PORTS/$_con_port" ]]; then
    if [[ -z $lis_port ]]; then
      delete_host_port "$_lis_port" "$_con_port"
    else
      for _lis_port in $("$DIR_DISTRO_PORTS/$_con_port/*"); do
        delete_host_port "$_lis_port" "$_con_port"
      done
    fi
    rm "$DIR_DISTRO_PORTS/$_con_port/$_lis_port"
    return 0
  fi
  return 1
}

delete_host_port() {
  _lis_port=$1 # Listen port, required
  _con_port=$2 # Connect port, optional
  if [[ -e "$DIR_HOST_PORTS/$_lis_port" ]]; then
    _host_distro=$(cat "$DIR_HOST_PORTS/$_lis_port/distro")
    _host_con_port=$(cat "$DIR_HOST_PORTS/$_lis_port/con-port")
    if [[ $_host_distro == "$DISTRO" && ( -z $_con_port || $_host_con_port == "$_con_port") ]]; then
      rm "$DIR_HOST_PORTS/$_lis_port/distro"
      rm "$DIR_HOST_PORTS/$_lis_port/con-port"
      rm -d "$DIR_HOST_PORTS/$_lis_port"
      return 0
    fi
  fi
  return 1
}

show_ports() {
  _re_lis_port=$1 # optional
  _re_con_port=$2 # optional
  printf "lis\tcon\n"
  for _con_port_path in "$DIR_DISTRO_PORTS"/*; do
    for _lis_port_path in "$_con_port_path"/*; do
      _lis_port=${_lis_port_path##*/}
      if [[ $_lis_port == "*" ]]; then continue; fi
      _con_port=${_con_port_path##*/}
      if [[ (-z $_re_lis_port || $_con_port == "$_re_lis_port") && (-z $_re_con_port || $_lis_port == "$_re_con_port") ]]; then
        printf "%s\t%s\n" "$_lis_port" "$_con_port"
      fi
    done
  done
}

if [[ $mode == "add" ]]; then
  if [[ -z $con_port ]]; then
    if [[ -z $lis_port ]]; then
      # both lis-port and con-port are not specified
      invalid_argument "Both Listen port and Connect port are not specified."
    fi
    # only lis-port is specified
    con_port=$lis_port
  else
    if [[ -z $lis_port ]]; then
      # only con-port is specified
      lis_port=$con_port
    fi
  fi
  if [[ -e "$DIR_HOST_PORTS/$lis_port" ]]; then
    _host_distro=$(cat "$DIR_HOST_PORTS/$lis_port/distro")
    _host_con_port=$(cat "$DIR_HOST_PORTS/$lis_port/con-port")
    if [[ $_host_distro == "$DISTRO" && $_host_con_port == "$con_port" ]]; then
      # echo "Notice: Host port $lis_port is already set to connect port $_host_con_port." 1>&2
      exit 0
    fi
    error_exit "Host port $lis_port already taken to connect port $_host_con_port from disro $_host_distro" 11
  fi
  mkdir -p "$DIR_HOST_PORTS/$lis_port"
  echo -n "$WSL_DISTRO_NAME" > "$DIR_HOST_PORTS/$lis_port/distro"
  echo -n "$con_port" > "$DIR_HOST_PORTS/$lis_port/con-port"
  mkdir -p "$DIR_DISTRO_PORTS/$con_port"
  echo -n "" > "$DIR_DISTRO_PORTS/$con_port/$lis_port"

elif [[ $mode == "delete" ]]; then
  if ! delete_port "$lis_port" "$con_port";
  then
    if [[ -z $con_port ]]; then
      if [[ -z $lis_port ]]; then
        invalid_argument "Both Listen port and Connect port are not specified."
      else
        error_exit "Port $lis_port is not listened." 21
      fi
    else
      if [[ -z $lis_port ]]; then
        error_exit "Port $con_port is not connected." 22
      else
        error_exit "Port $con_port is not connected for the listen port $lis_port" 23
      fi
    fi
  fi

elif [[ $mode == "show" ]]; then
  show_ports "$lis_port" "$con_port"

fi
exit 0