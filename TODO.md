pacman -Sy gnupg archlinuxarm-keyring --needed
pacman-key --init
pacman-key --populate archlinuxarm




pacman -S vim
pacman -S cloud-guest-utils

pacman -S mesa mesa-demos mesa-utils





pacman -S weston seatd wayland-utils glmark2
usermod -aG video,render,seat $USER
systemctl enable --now seatd.service
weston --backend=drm-backend.so --tty=1 --log=/tmp/weston.log

warning: warning given when extracting /usr/lib/gstreamer-1.0/gst-ptp-helper (Cannot restore extended attributes on this file system.)
Failed to set capabilities on file 'usr/lib/gstreamer-1.0/gst-ptp-helper': Operation not supported








// Test 
sudo pacman -S base-devel meson ninja git
git clone https://gitlab.freedesktop.org/mesa/kmscube.git
cd kmscube
meson setup build
ninja -C build
sudo ./build/kmscube
