FROM dock0/pkgforge
RUN pacman -S --needed --noconfirm chrpath
RUN groupadd -g 5 tty
