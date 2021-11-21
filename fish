# Fish installation
sudo apt install fish
fish
set fish_greeting

sudo apt install curl
sudo apt install fonts-powerline

# Install omf
curl https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | fish

# Change theme
omf install sashimi
omf install https://github.com/dracula/fish

# Outside of fish set fish as default shell
chsh -s /usr/bin/fish
