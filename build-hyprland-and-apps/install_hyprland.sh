#!/bin/bash

# Function to add a value to a configuration file if not present
add_to_file() {
    local config_file="$1"
    local value="$2"
    
    if ! sudo grep -q "$value" "$config_file"; then
        echo "Adding $value to $config_file"
        sudo sh -c "echo '$value' >> '$config_file'"
    else
        echo "$value is already present in $config_file."
    fi
}

add_to_grub() {
    local value="$1"
    
    # Check if the value is already present in GRUB_CMDLINE_LINUX_DEFAULT
    if ! sudo grep -q "GRUB_CMDLINE_LINUX_DEFAULT=.*$value" /etc/default/grub; then
        echo "Adding $value to GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub"
        
        # Use sed to add the value to the GRUB_CMDLINE_LINUX_DEFAULT line
        sudo sed -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"/\1 $value\"/" /etc/default/grub
        sudo update-grub
    else
        echo "$value is already present in GRUB_CMDLINE_LINUX_DEFAULT."
    fi
}

git clone https://github.com/hyprwm/hyprwayland-scanner
cd hyprwayland-scanner
cmake -DCMAKE_INSTALL_PREFIX=/usr -B build
cmake --build build -j `nproc`
sudo cmake --install build
cd ..

git clone https://github.com/hyprwm/hyprutils.git
cd hyprutils/
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
cmake --build ./build --config Release --target all -j`nproc 2>/dev/null || getconf NPROCESSORS_CONF`
sudo cmake --install build
cd ..

git clone https://github.com/hyprwm/aquamarine
cd aquamarine
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
cmake --build ./build --config Release --target all -j`nproc 2>/dev/null || getconf _NPROCESSORS_CONF`
sudo cmake --install build
cd ..

git clone https://github.com/hyprwm/hyprlang
cd hyprlang
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
cmake --build ./build --config Release --target all -j`nproc 2>/dev/null || getconf _NPROCESSORS_CONF`
sudo cmake --install ./build
cd ..

git clone https://github.com/hyprwm/hyprcursor
cd hyprcursor
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
cmake --build ./build --config Release --target all -j`nproc 2>/dev/null || getconf _NPROCESSORS_CONF`
sudo cmake --install build
cd ..

git clone https://github.com/hyprwm/hyprgraphics
cd hyprgraphics/
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
cmake --build ./build --config Release --target all -j`nproc 2>/dev/null || getconf NPROCESSORS_CONF`
sudo cmake --install build
cd ..

git clone https://github.com/stephenberry/glaze
cd glaze
rm -rf build && mkdir -p build
cd build
cmake \
        -DCMAKE_INSTALL_PREFIX="/usr" \
        -DBUILD_TESTING=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -G "Ninja" ..
ninja
sudo ninja install
cd ../..

# Clone and build Hyprland
git clone --recursive https://github.com/hyprwm/Hyprland
cd Hyprland || exit

# Check if an NVIDIA GPU is present
if lspci -k | grep -A 2 -E "(VGA|3D)" | grep -iq nvidia; then
    sed 's/glFlush();/glFinish();/g' -i subprojects/wlroots/render/gles2/renderer.c

    # Add nvidia_drm.modeset=1 to GRUB_CMDLINE_LINUX_DEFAULT if not present
    add_value="nvidia_drm.modeset=1"
    add_to_grub "$add_value"

    # Define the configuration file and the line to add
    config_file="/etc/modprobe.d/nvidia.conf"
    line_to_add="options nvidia-drm modeset=1"

    # Check if the config file exists
    if [ ! -e "$config_file" ]; then
        echo "Creating $config_file"
        sudo touch "$config_file"
    fi

    add_to_file "$config_file" "$line_to_add"

    # Add NVIDIA modules to initramfs configuration
    modules_to_add="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
    modules_file="/etc/initramfs-tools/modules"
    
    if [ -e "$modules_file" ]; then
        add_to_file "$modules_file" "$modules_to_add"
        sudo update-initramfs -u
    else
        echo "Modules file ($modules_file) not found."
    fi
fi

# Build Hyprland using Meson and Ninja
meson build
ninja -C build
sudo ninja -C build install

# Return to the previous directory
cd ..
