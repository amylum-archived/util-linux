FROM dock0/pkgforge
RUN pacman -S --needed --noconfirm chrpath
