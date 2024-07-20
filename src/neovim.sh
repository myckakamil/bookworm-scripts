[ "$EUID" -ne 0 ] && {
  echo "Please run as root"
  exit
}

apt install ninja-build gettext cmake unzip curl

git clone https://github.com/neovim/neovim 
cd neovim

make CMAKE_BUILD_TYPE=RelWithDebInfo
make install

cd ..
rm -rf neovim