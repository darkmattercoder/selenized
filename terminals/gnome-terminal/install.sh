#!/usr/bin/env bash
dir=$(dirname "$0")

declare -a schemes
schemes=($(cd $dir/colors && echo * && cd - > /dev/null))

source $dir/src/tools.sh
source $dir/src/profiles.sh

show_help() {
  echo
  echo "Usage"
  echo
  echo "    install.sh [-h|--help] \\"
  echo "               (-s <scheme>|--scheme <scheme>|--scheme=<scheme>) \\"
  echo "               (-p <profile>|--profile <profile>|--profile=<profile>)"
  echo
  echo "Options"
  echo
  echo "    -h, --help"
  echo "        Show this information"
  echo "    -s, --scheme"
  echo "        Color scheme to be used"
  echo "    -p, --profile"
  echo "        Gnome Terminal profile to overwrite"
  echo
}

validate_scheme() {
  local profile=$1
  in_array $scheme "${schemes[@]}" || die "$scheme is not a valid scheme" 2
}

set_profile_colors() {
  local profile=$1
  local scheme=$2
  local scheme_file=$dir/colors/$scheme

  . $scheme_file

  if [ "$newGnome" = "1" ]
    then local profile_path=$dconfdir/$profile

    echo
    echo "Backing up existing profile $profile to ${profile}_backup"
    echo

    copy_profile $profile

    # set color palette
    dconf write $profile_path/palette "$(echo $PALETTE | to_dconf)"

    # set foreground, background and highlight color
    dconf write $profile_path/bold-color "'$BOLD'"
    dconf write $profile_path/background-color "'$BACKGROUND'"
    dconf write $profile_path/foreground-color "'$FOREGROUND'"

    # make sure the profile is set to not use theme colors
    dconf write $profile_path/use-theme-colors "false"

    # set highlighted color to be different from foreground color
    dconf write $profile_path/bold-color-same-as-fg "false"

  else
    local profile_path=$gconfdir/$profile

    # set color palette
    gconftool-2 -s -t string $profile_path/palette "$(echo $PALETTE | to_gconf)"

    # set foreground, background and highlight color
    gconftool-2 -s -t string $profile_path/bold_color $BOLD
    gconftool-2 -s -t string $profile_path/background_color $BACKGROUND
    gconftool-2 -s -t string $profile_path/foreground_color $FOREGROUND

    # make sure the profile is set to not use theme colors
    gconftool-2 -s -t bool $profile_path/use_theme_colors false

    # set highlighted color to be different from foreground color
    gconftool-2 -s -t bool $profile_path/bold_color_same_as_fg false
  fi
}

interactive_help() {
  echo
  echo -e "\e[1;39mWarning!\e[0m"
  echo -e "This will permanently overwrite colors in selected profile - there is no undo."
  echo -e "Consider creating a new profile before installing Selenized."
  echo
}

interactive_select_scheme() {
  echo "Please select Selenized variant:"
  select scheme
  do
    if [[ -z $scheme ]]
    then
      die "ERROR: Invalid selection -- ABORTING!" 2
    fi
    break
  done
  echo
}

interactive_confirm() {
  local confirmation

  echo    "You have selected:"
  echo
  echo    "  Scheme:  Selenized $scheme"
  echo    "  Profile: $(get_profile_name $profile) ($profile)"
  echo
  echo    "Are you sure you want to overwrite the selected profile? The original Profile $profile will be backed up as ${profile}_backup"
  echo -n "(YES to continue) "

  read confirmation
  if [[ $(echo $confirmation | tr '[:lower:]' '[:upper:]') != YES ]]
  then
    die "ERROR: Confirmation failed -- ABORTING!"
  fi

  echo    "Confirmation received -- applying settings"
}

while [ $# -gt 0 ]
do
  case $1 in
    -h | --help )
      show_help
      exit 0
    ;;
    --scheme=* )
      scheme=${1#*=}
    ;;
    -s | --scheme )
      scheme=$2
      shift
    ;;
    --profile=* )
      profile=${1#*=}
    ;;
    -p | --profile )
      profile=$2
      shift
    ;;
  esac
  shift
done

if [[ -z "$scheme" ]] || [[ -z "$profile" ]]
then
  interactive_help
fi

if [[ -n "$scheme" ]]
  then validate_scheme $scheme
else
  interactive_select_scheme "${schemes[@]}"
fi

if [[ -n "$profile" ]]
  then if [ "$newGnome" = "1" ]
    then profile="$(get_uuid "$profile")"
  fi
  validate_profile $profile
else
  if [ "$newGnome" = "1" ]
    then check_empty_profile Default
  fi
  interactive_select_profile "${profiles[@]}"
  interactive_confirm
fi

set_profile_colors $profile $scheme
