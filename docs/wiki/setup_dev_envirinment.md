installation: 
- VM --> https://www.virtualbox.org/wiki/Downloads --> latest version
- Linux image (xubuntu).iso --> xubuntu 22.04: https://cdimage.ubuntu.com/xubuntu/releases/jammy/release/
- serial debugging
    sudo apt install minicom
    sudo minicom -s
        /dev/ttyUSB0
        115200 8N1
        Hardware Flow Control: off
        Software Flow Control: off
- visual studio code
    sudo apt update
    sudo apt install wget gpg
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
    sudo apt update
    sudo apt install code
-install packages
    sudo apt install git make gcc g++ libcurses-dev docker.io qemu-user-static binfmt-support
        