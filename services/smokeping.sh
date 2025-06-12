#!/bin/bash

echo "Updating packages"
apt update &>/dev/null

PACKAGE="smokeping"
MIN_VERSION="2.8.2"

DEBIAN_VERSION=$(lsb_release -sr)

CANDIDATE_VERSION=$(apt show "$PACKAGE" 2>/dev/null | awk -F ': ' '/^Version/ {print $2}')

if [ -z "$CANDIDATE_VERSION" ]; then
    echo "Błąd: Pakiet '$PACKAGE' nie został znaleziony w repozytoriach."
    exit 1
fi

BASE_VERSION=$(echo "$CANDIDATE_VERSION" | cut -d '-' -f1 | cut -d '+' -f1 | cut -d ':' -f2)

if dpkg --compare-versions "$BASE_VERSION" gt "$MIN_VERSION"; then
    echo "Instalacja $PACKAGE w wersji $CANDIDATE_VERSION (nowszej niż $MIN_VERSION)"
    apt-get install smokeping
elif  dpkg --compare-versions "$BASE_VERSION" eq "$MIN_VERSION"; then
    echo "Dostępna wersja ($CANDIDATE_VERSION) jest równa wymaganej ($MIN_VERSION)"
    apt-get install smokeping
else
    echo "Dostępna wersja ($CANDIDATE_VERSION) jest starsza niż wymagana ($MIN_VERSION)"
    echo "Wykorzystywany jest Debian $DEBIAN_VERSION. Zalecana jest wersja 13 i wzwyż"
    read -p "Czy zaktualizować do debiana 13? (y/n): " CONFIRM
    case $CONFIRM in
        y | yes)
            apt update
            apt upgrade -y
            apt full-upgrade -y
        
            sed -i 's/bookworm/trixie/g' /etc/apt/sources.list
            sed -i 's/bullseye/trixie/g' /etc/apt/sources.list
            sed -i 's/buster/trixie/g' /etc/apt/sources.list

            apt update
            apt upgrade -y
            apt full-upgrade -y
            apt dist-upgrade -y
            apt --fix-broken install
            
            apt autoremove -y
            apt autoclean
            
            echo "Zalecana jest aktualizacja systemu. System zostanie uruchomiony ponownie po zainstalowaniu smokepinga"
            REBOOT_FLAG=true

            apt-get install smokeping
            ;;
        n | no)
            echo "Koncze dzialanie skryptu"
            break
            ;;
        *)
            echo "Invalid choice. Please select 'yes' or 'no'."
            ;;
    esac
fi
