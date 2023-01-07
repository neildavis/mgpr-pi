#!/bin/env bash

# MIT License

# Copyright (c) 2023 Neil Davis

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

swap_mb_required=1024 # Min 1GB swap is recommended to compile box86

box86_repo="https://github.com/ptitSeb/box86.git"
box86_ver="v0.2.8"
box86_build_dir="${HOME}/code/box86"

badown_repo="https://github.com/stck-lzm/badown.git"  # to help download from mediafire
badown_ver="master"
badown_dir="${HOME}/code/badown"

# Change this to your local Debian mirror for faster downloads
# https://www.debian.org/mirror/list
debian_package_mirror="ftp.us.debian.org/debian/"

mgpr_linux_tar_gz_url="https://www.mediafire.com/file/0c68v3eb4m4wgbd/mgpr_v1_4_6_linux_04_04_2016.tar.gz"
mgpr_dest_dir="${HOME}/mgpr_v1_4_6_linux" # Path for mgpr.
mgpr_launch_sh="${HOME}/bin/mgpr.sh"      # Path of mgpr launch script

# These lines affect the mgpr config file generated in mgpr's 'cfg' dir
mgpr_cfg_name="nn.cfg"            # The name of the configuration file.
mgpr_cfg_display_width=800    # if TATE mode is applied this will become height
mgpr_cfg_display_height=480   # if TATE mode is applied this will become width
mgpr_cfg_fullscreen=yes       # Change to 'no' to disable fullscreen use (e.g. when running in a desktop window)
mgpr_cfg_tate_mode=yes        # TATE mode rotates the game to play in portrait making better use of screen space.
mgpr_cfg_playfield_width=640  # if TATE mode is applied this will become height
mgpr_cfg_playfield_height=480 # if TATE mode is applied this will become width
mgpr_cfg_playfield_pos_x=60   # if TATE mode is applied this will become y pos
mgpr_cfg_playfield_pos_y=0    # if TATE mode is applied this will become x pos
# These lines affect the .xinitrc file generated to run mgpr under X11 from the CLI console. 
mgpr_display_output_id="HDMI-1" # Change to 'DSI-1' if using DSI display (e.g. official 7" touch screen)
mgpr_display_rotate="normal"    # Change to 'inverted' to rotate the screen 180 degrees in TATE mode.

script_dir="${PWD}"

# Install the build environment
echo "Installing build tools and dependenices ..."
sudo apt -y install git build-essential cmake xinit x11-xserver-utils libpulse0 gawk \
  libegl1-mesa-dev  libgles2-mesa-dev libgl1-mesa-dev libgbm-dev libdrm-dev

# Sort out swap file
source /etc/dphys-swapfile
if [ $CONF_SWAPSIZE -lt $swap_mb_required ]; then 
  echo "Swap size ${CONF_SWAPSIZE} MB is insufficient. Raising to 1024 MB"
  sudo dphys-swapfile swapoff
  sudo sed -i 's/CONF_SWAPSIZE='"${CONF_SWAPSIZE}"'/CONF_SWAPSIZE='"${swap_mb_required}"'/g' /etc/dphys-swapfile   
  sudo dphys-swapfile setup
  sudo dphys-swapfile swapon
else 
  echo "Swap size ${CONF_SWAPSIZE} MB is sufficient"
fi

# Let's build box86
if [[ ! -d "${box86_build_dir}" ]]; then
  echo "Fetching box86 version ${box86_ver} from ${box86_repo}"
  mkdir -p "${box86_build_dir}"
  git -c advice.detachedHead=false clone --depth=1 -b "${box86_ver}" "${box86_repo}" "${box86_build_dir}"
fi
if [[ ! -f "${box86_build_dir}/box86" ]]; then
  cd "${box86_build_dir}"
  box86_rpi_build_flag="-DRPI$(grep -Po 'Raspberry Pi \K[[:digit:]+](?= Model)' /proc/cpuinfo)=1"
  echo "Building box86 with ${box86_rpi_build_flag} ..."
  cmake . "${box86_rpi_build_flag}" -DCMAKE_BUILD_TYPE=RelWithDebInfo
  make -j$(nproc)
  sudo make install
  sudo systemctl restart systemd-binfmt
  cd "${script_dir}"
else
  echo "Skipping box86 build. Already built"
fi

# Let's grab badown to help us download MGPR from mediafire
if [[ ! -d "${badown_dir}" ]]; then
  echo "Fetching badwown version ${badown_ver} from ${badown_repo}"
  mkdir -p "${badown_dir}"
  git -c advice.detachedHead=false clone --depth=1 -b "${badown_ver}" "${badown_repo}" "${badown_dir}"
else
  echo "badown has laready been downloaded"
fi

# Let's grab Monaco GP Remake
mgpr_tar_gz_dest="mgpr_v1_4_6_linux_04_04_2016.tar.gz"
if [[ ! -f "${mgpr_tar_gz_dest}" ]]; then
  echo "Downloading mgpr from ${mgpr_linux_tar_gz_url} ..."
  "${badown_dir}"/badown "${mgpr_linux_tar_gz_url}"
else
  echo "MGPR Linux has already been downloaded"
fi
if [[ ! -d "${mgpr_dest_dir}" ]]; then
  echo "Extracting ${mgpr_tar_gz_dest} ..."
  mkdir -p "${mgpr_dest_dir}"
  tar -xf "${mgpr_tar_gz_dest}" --strip-components=1 --directory "${mgpr_dest_dir}"
  #rm "${mgpr_tar_gz_dest}"
fi
if [[ ! -f "${mgpr_dest_dir}/mgpr" ]]; then
  cp "${mgpr_dest_dir}/linux_builds/static_32bit/mgpr" "${mgpr_dest_dir}/"
fi
if [[ $(ls -l "${mgpr_dest_dir}"/*.so* | wc -l) -eq 0 ]]; then
  echo "Fetching i386 pkg dependencies for mgpr"
  mkdir -p "${mgpr_dest_dir}"/debs
  declare -a pkgs_i386=(\
    "http://${debian_package_mirror}pool/main/libd/libdumb/libdumb1_0.9.3-6+b3_i386.deb"\
    "http://${debian_package_mirror}pool/main/f/flac/libflac8_1.3.3-2+deb11u1_i386.deb"\
    "http://${debian_package_mirror}pool/main/libv/libvorbis/libvorbisfile3_1.3.7-1_i386.deb"\
    "http://${debian_package_mirror}pool/main/o/openal-soft/libopenal1_1.19.1-2_i386.deb"\
    "http://${debian_package_mirror}pool/main/s/sndio/libsndio7.0_1.5.0-3_i386.deb"\
    "http://${debian_package_mirror}pool/main/libb/libbsd/libbsd0_0.11.3-1_i386.deb"\
    "http://${debian_package_mirror}pool/main/libm/libmd/libmd0_1.0.3-3_i386.deb"
   )
  for pkg in "${pkgs_i386[@]}"; do
    wget -P "${mgpr_dest_dir}"/debs "${pkg}"
  done
  for deb in "${mgpr_dest_dir}"/debs/*; do
    dpkg -x "${deb}" "${mgpr_dest_dir}"/debs
  done
  find "${mgpr_dest_dir}/debs" -name *.so* -print0 | xargs -0 mv -t "${mgpr_dest_dir}"
  rm -rf "${mgpr_dest_dir}"/debs
else 
  echo "i386 pkg dependencies for mgpr have already been fetched"
fi

# Create .xinitrc for launching mgpr from CLI
mgpr_xinit_rc="${mgpr_dest_dir}/.xinitrc"
# if [[ ! -f "${mgpr_xinit_rc}" ]]; then
echo "Creating MGPR .xinitrc script"
cat <<EOF > "${mgpr_xinit_rc}"
cd "${mgpr_dest_dir}"
DISPLAY=:0 xrandr --output ${mgpr_display_output_id} --rotate ${mgpr_display_rotate}
./mgpr -cfg "\${MGPR_CFG}"
EOF
# else
#   echo "MGPR .xinitrc ${mgpr_dest_dir}/.xinitrc already exists"
# fi

# Create user scripts to launch
mkdir -p $(dirname "${mgpr_launch_sh}")
# if [[ ! -f "${mgpr_launch_sh}" ]]; then
echo "Creating MGPR launch script"
cat <<EOF > "${mgpr_launch_sh}"
#!/bin/env bash
if [ -n "\$DISPLAY" ]; then
  cd "${mgpr_dest_dir}"
  ./mgpr -cfg "${mgpr_cfg_name}"
else
  MGPR_CFG="\$1"
  if [[ -z "\${MGPR_CFG}" ]]; then
    MGPR_CFG="${mgpr_cfg_name}"
  fi
  export MGPR_CFG
  XINITRC=${mgpr_dest_dir}/.xinitrc xinit -- :0 -quiet vt\$XDG_VTNR 
fi
EOF
  chmod a+x "${mgpr_launch_sh}"
# else
#   echo "MGPR launch script ${HOME}/bin/mgpr.sh already exists"
# fi

# Create MGPR config
echo "Creating MGPR cfg (${mgpr_dest_dir}/cfg/$mgpr_cfg_name)"
mkdir -p "${mgpr_dest_dir}"/cfg
cat << EOF > "${mgpr_dest_dir}"/cfg/"$mgpr_cfg_name"
DISPLAY resolution "${mgpr_cfg_display_width}x${mgpr_cfg_display_height}"
DISPLAY fullscreen ${mgpr_cfg_fullscreen}
DISPLAY window_frame no
DISPLAY set_window_pos no
DISPLAY window_pos_x 0
DISPLAY window_pos_y 0
DISPLAY scoreboard_mode "private"
DISPLAY playfield_w ${mgpr_cfg_playfield_width}
DISPLAY playfield_h ${mgpr_cfg_playfield_height}
DISPLAY playfield_x ${mgpr_cfg_playfield_pos_x}
DISPLAY playfield_y ${mgpr_cfg_playfield_pos_y}
DISPLAY rotate ${mgpr_cfg_tate_mode}
DISPLAY flip no
DISPLAY mirror no
DISPLAY filter yes
DISPLAY open_gl no
DISPLAY menu_contrast 20
DISPLAY playfield_stage yes
DISPLAY playfield_time yes
DISPLAY playfield_score yes
DISPLAY playfield_bonus yes
DISPLAY playfield_gear yes
DISPLAY playfield_infinite_lives no
DISPLAY playfield_get_ready yes
SOUND volume_master 100
SOUND radio_chat_enable yes
SOUND radio_chat_vol 100
SOUND attract_mode_sounds yes
SOUND loop_goal yes
SOUND loop_1st yes
SOUND loop_2nd no
SOUND loop_3rd no
SOUND loop_4th no
SOUND loop_5th no
SOUND volume_goal 100
SOUND volume_1st 80
SOUND volume_2nd 80
SOUND volume_3rd 80
SOUND volume_4th 80
SOUND volume_5th 80
SOUND cheers_goal 100
SOUND cheers_1st 50
SOUND cheers_2nd 40
SOUND cheers_3rd 30
SOUND cheers_4th 20
SOUND cheers_5th 10
SOUND volume_welcome 80
SOUND low_gear_base 0.8
SOUND low_gear_multiplier 20
SOUND hi_gear_base 0.4
SOUND hi_gear_multiplier 100
SOUND filename_welcome "trumpet.wav"
SOUND filename_goal "music.wav"
SOUND filename_1st "music.wav"
SOUND filename_2nd "trumpet.wav"
SOUND filename_3rd "trumpet.wav"
SOUND filename_4th "trumpet.wav"
SOUND filename_5th "trumpet.wav"
SOUND wav_bonus_overtake "beep_clean.wav"
SOUND vol_bonus_overtake 100
SOUND wav_bonus_award "beep_distorted.wav"
SOUND vol_bonus_award 100
SOUND wav_bonus_bridge "beep_distorted.wav"
SOUND vol_bonus_bridge 100
ARTWORK enable_bezel_artwork no
ARTWORK bezel_filename "scoreboard_w1024.bmp"
ARTWORK bezel_w 0
ARTWORK bezel_h 0
ARTWORK bezel_x 0
ARTWORK bezel_y 0
ARTWORK enable_led_artwork no
ARTWORK led_filename "speccy_multi3.bmp"
ARTWORK time_w 20
ARTWORK time_h 20
ARTWORK time_x 0
ARTWORK time_y 0
ARTWORK time_id 0
ARTWORK todays_best_w 20
ARTWORK todays_best_h 20
ARTWORK todays_best_1_x 0
ARTWORK todays_best_1_y 20
ARTWORK todays_best_1_id 1
ARTWORK todays_best_2_x 0
ARTWORK todays_best_2_y 40
ARTWORK todays_best_2_id 2
ARTWORK todays_best_3_x 0
ARTWORK todays_best_3_y 60
ARTWORK todays_best_3_id 3
ARTWORK todays_best_4_x 0
ARTWORK todays_best_4_y 80
ARTWORK todays_best_4_id 4
ARTWORK todays_best_5_x 0
ARTWORK todays_best_5_y 100
ARTWORK todays_best_5_id 5
ARTWORK your_score_w 20
ARTWORK your_score_h 20
ARTWORK your_score_x 0
ARTWORK your_score_y 120
ARTWORK your_score_id 6
ARTWORK players_to_date_w 20
ARTWORK players_to_date_h 20
ARTWORK players_to_date_x 0
ARTWORK players_to_date_y 140
ARTWORK players_to_date_id 7
ARTWORK ranking_w 20
ARTWORK ranking_h 20
ARTWORK ranking_x 0
ARTWORK ranking_y 160
ARTWORK ranking_id 8
ARTWORK super_racer_w 20
ARTWORK super_racer_h 20
ARTWORK super_racer_x 0
ARTWORK super_racer_y 180
ARTWORK overtake_filename "overtake_leds.bmp"
ARTWORK overtake_row_upper_w 20
ARTWORK overtake_row_upper_h 20
ARTWORK overtake_row_upper_x 0
ARTWORK overtake_row_upper_y 200
ARTWORK overtake_row_lower_w 20
ARTWORK overtake_row_lower_h 20
ARTWORK overtake_row_lower_x 0
ARTWORK overtake_row_lower_y 220
CONTROL steering_device "keys"
CONTROL steering_invert no
CONTROL steering_sensitivity 50
CONTROL steering_weight 50
CONTROL accelerator_device "keys"
CONTROL accelerator_invert no
CONTROL accelerator_range "0 to +1"
CONTROL gear_change_device "keys"
CONTROL gear_method "toggle"
CONTROL coin_a_device "keys"
CONTROL coin_b_device "keys"
CONTROL start_device "keys"
CONTROL key_accel "n"
CONTROL key_gear "m"
CONTROL key_coin_a "5"
CONTROL key_coin_b "6"
CONTROL key_start "1"
CONTROL key_left "z"
CONTROL key_right "x"
CONTROL key_exit "escape"
GAMEPLAY game_track "game_arcade.trk"
GAMEPLAY attract_track "attract_arcade.trk"
GAMEPLAY time_bridge_grace 5
GAMEPLAY time_puddle 350
GAMEPLAY puddle_steering 90
GAMEPLAY verge_trigger 40
GAMEPLAY verge_slow_down 70
GAMEPLAY marsh_trigger 50
GAMEPLAY marsh_slow_down 60
GAMEPLAY marsh_steering 90
GAMEPLAY surface_wobble_rate 5
GAMEPLAY time_grace_scenery 7
GAMEPLAY time_grace_verge 7
GAMEPLAY brake_low_gear 2
GAMEPLAY brake_high_gear 2
GAMEPLAY brake_wrong_gear 1.7
GAMEPLAY arcade_acceleration yes
GAMEPLAY brake_immediate 50
GAMEPLAY vertical_climb 50
GAMEPLAY vertical_fall 50
GAMEPLAY blink_frames_on 6
GAMEPLAY blink_frames_off 6
GAMEPLAY pro_monaco_gp_mode no
GAMEPLAY debug_track no
GAMEPLAY tarmac_normal_play_r 62
GAMEPLAY tarmac_normal_play_g 62
GAMEPLAY tarmac_normal_play_b 62
GAMEPLAY tarmac_extended_play_r 0
GAMEPLAY tarmac_extended_play_g 0
GAMEPLAY tarmac_extended_play_b 72
GAMEPLAY night_lights_fix yes
GAMEPLAY attract_mode_hiscore yes
GAMEPLAY end_game_you_placed no
GAMEPLAY end_game_stats no
EOF
cd "${script_dir}"
